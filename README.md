# Module Stresser

This repository contains a set of single-purpose stress modules and the Kubernetes/Argo manifests used to run them in-cluster.

It assumes you already have a Kubernetes cluster. This README focuses on how this repository is organized, how the workloads are meant to be used, and how the CPU test was built from the ground up so the rest of the modules are easier to understand.

## Repository layout

- `cpu/`, `memory/`, `io/`, `network/`: one stress module per directory. Each module has a shell entrypoint, a `Dockerfile`, and a simple Kubernetes Job manifest for in-cluster smoke testing.
- `argo-workflows/templates/`: reusable Argo `WorkflowTemplate` objects, one per module.
- `argo-workflows/workflows/`: runnable Argo `Workflow` objects that invoke the templates with concrete parameters and cooldown steps.
- `argo-workflows/rbac-argo.yaml`: the `stress-sa` service account and RBAC used by the workflows in the `stress` namespace.
- `argo-workflows/argo-install-master-only/`: Kustomize overlay that places `argo-server` and `workflow-controller` on the control-plane node.
- `quickpizza/`, `k6/`: example application and load-generation assets used in some scenarios.
- `run-indexer/`: watcher that records completed workflow pod runs.
- `extract-measurements/`: post-processing utilities for measurement extraction.

## Common pattern used in this repo

All stress modules follow the same build path:

1. Start with a shell script that runs the actual stress tool and exposes the knobs we want through environment variables.
2. Package that script into a small container image.
3. Add a simple Kubernetes Job manifest to smoke-test the container inside the cluster before involving Argo.
4. Create a `WorkflowTemplate` that exposes the important runtime knobs to Argo.
5. Create one or more `Workflow` objects that call the template with concrete values and sequencing logic.

The CPU module is documented in detail below. Memory, IO, and Network follow the same structure, just with different scripts and parameters.

## Cluster preparation for this repo

### Namespaces and worker labeling

All stress workloads run in the `stress` namespace. The Argo control plane is installed in the `argo` namespace.

Create the namespaces if they do not exist:

```bash
kubectl create namespace stress
kubectl create namespace argo
```

Label every worker that is allowed to run stress containers with `role=stress`:

```bash
kubectl label node <worker-node> role=stress
kubectl get nodes -L role
```

This will be the node on which the stress test will run. Naturally, the control plane node should not have this label, as we do not want any stress to be happening in it.

The standalone Jobs in `cpu/`, `memory/`, `io/`, and `network/` select `role=stress`. The Argo workflows also require `target-node` to match the node hostname.

### Worker host prep for the shared IO path

The IO tests mount a host path and expect it to be group-owned by the same numeric GID used inside the images.

```bash
sudo groupadd -g 20001 stresscontainers
sudo mkdir -p /var/lib/module-stresser/
sudo chgrp -R 20001 /var/lib/module-stresser/
sudo chmod 2775 /var/lib/module-stresser/
```

Create the shared random-data file used by the IO workloads:

```bash
openssl enc -aes-256-ctr -pass pass:seed -nosalt \
 </dev/zero | dd of=/var/lib/module-stresser/fio_rand.dat bs=4M oflag=direct status=progress

sudo chgrp 20001 /var/lib/module-stresser/fio_rand.dat
sudo chmod 664 /var/lib/module-stresser/fio_rand.dat

ls -l /var/lib/module-stresser/fio_rand.dat
xxd -l 64 /var/lib/module-stresser/fio_rand.dat
```

### Argo service account and control-plane placement

The workflows in `argo-workflows/workflows/` use `serviceAccountName: stress-sa`, so apply the repo RBAC first:

```bash
kubectl apply -f argo-workflows/rbac-argo.yaml
kubectl get serviceaccount,role,rolebinding -n stress
```

This repo keeps the Argo control pods on the control-plane node by using the overlay in `argo-workflows/argo-install-master-only/`:

```bash
kubectl apply -k argo-workflows/argo-install-master-only
kubectl get pods -n argo -o wide
```

That overlay patches `argo-server` and `workflow-controller` with:

- `nodeSelector: node-role.kubernetes.io/control-plane: ""`
- a matching `NoSchedule` toleration

After applying the overlay, taint the control-plane node so regular stress pods do not land there:

```bash
kubectl taint nodes <control-plane-node> node-role.kubernetes.io/control-plane=:NoSchedule --overwrite
kubectl describe node <control-plane-node>
```

The point of this setup is:

- Argo control pods can still run on the control-plane node because the overlay adds the toleration.
- Stress workloads do not tolerate that taint, so they stay on worker nodes.

If you want the UI:

```bash
kubectl -n argo port-forward svc/argo-server 2746:2746
```

## Running the existing workflows

Apply whichever templates you need:

```bash
argo template create argo-workflows/templates/cpu-stress-template.yaml
```

Then submit a workflow, overriding `target-node` to a real worker hostname:

```bash
argo submit -n stress argo-workflows/workflows/cpu-stress.yaml
```

The committed workflows under `argo-workflows/workflows/` are examples of concrete stress campaigns. They mostly differ in the parameters they pass into the shared templates.

## CPU test: built bottom up

The CPU module is the clearest example of how the repository was assembled.

### 1. Start from the stress script

The base implementation lives in `cpu/cpu_stress.sh`. It wraps `stress-ng` and exposes knobs such as:

- `WORKERS`
- `LOAD`
- `TIMEOUT`
- `METHOD`
- `CPUSET`
- `METRICS_BRIEF`
- `PERF`
- `EXTRA_ARGS`

Run the script directly to validate the raw stress logic before containerizing it:

```bash
WORKERS=2 \
LOAD=75 \
TIMEOUT=30s \
METHOD=float64 \
CPUSET=0-1 \
./cpu/cpu_stress.sh
```

This step is useful when you want to debug the test itself without involving Docker or Kubernetes. It requires `stress-ng` to be available on the machine where you run it.

### 2. Containerize the script

The image is defined in `cpu/Dockerfile`. It installs `stress-ng`, copies the script, and runs it as a non-root user.

Build the image:

```bash
docker build -t cpu-stress:dev ./cpu
```

Run the container locally with the same kind of knobs as the script:

```bash
docker run --rm \
  -e WORKERS=2 \
  -e LOAD=75 \
  -e TIMEOUT=30s \
  -e METHOD=float64 \
  -e CPUSET=0-1 \
  cpu-stress:dev
```

This confirms the container entrypoint matches the raw script behavior. If you want to use your own image inside the cluster, push it to a registry reachable by the cluster and update the image reference in the Job and Argo manifests.

### 3. Smoke-test it inside the cluster

`cpu/deployment.yaml` is the simple in-cluster validation step for the CPU container. Despite the filename, it defines a Kubernetes `Job`.

Apply it:

```bash
kubectl apply -f cpu/deployment.yaml
kubectl logs -n stress job/cpu-stress-2w-75pct-1m -f
```

That Job keeps the setup small on purpose:

- it targets nodes labeled `role=stress`
- it passes the container knobs as environment variables
- it sets CPU requests and limits so the run is reproducible

This is the point where you confirm the image works correctly in the cluster before turning it into an Argo workflow.

### 4. Lift the container into a WorkflowTemplate

The reusable Argo template lives in `argo-workflows/templates/cpu-stress-template.yaml`.

Apply it:

```bash
argo template create argo-workflows/templates/cpu-stress-template.yaml
```

At this layer, the repo exposes the knobs used in recurring workflow runs:

- `image`
- `workers`
- `load`
- `timeout`
- `cpuset`
- resource requests and limits
- `display`

The template also adds the Kubernetes scheduling details that do not belong in the container itself, such as:

- `nodeSelector: role=stress`
- `kubernetes.io/hostname: {{workflow.parameters.target-node}}`
- the resource patch for the main container

### 5. Create and run the Workflow

The final runnable workflow lives in `argo-workflows/workflows/cpu-stress.yaml`.

Submit it:

```bash
argo submit -n stress argo-workflows/workflows/cpu-stress.yaml
```

Inspect the run:

```bash
argo list -n stress
kubectl get workflows -n stress
```

This workflow reuses the `cpu-stress` template multiple times, varying the load and inserting cooldown periods between runs. That is the last layer in the stack: the script defines the test, the image packages it, the Job validates it in-cluster, the template makes it reusable, and the workflow turns it into a repeatable experiment.

## The other stress modules

The other modules use the same method:

- `memory/` -> `argo-workflows/templates/memory-stress-template.yaml` -> `argo-workflows/workflows/memory-stress.yaml`
- `io/` -> `argo-workflows/templates/io-stress-template.yaml` -> `argo-workflows/workflows/io-stress.yaml`
- `network/` -> `argo-workflows/templates/network-stress-template.yaml` -> `argo-workflows/workflows/network-stress.yaml`

The only real difference is the stress tool and the parameters each script exposes:

- memory uses `stress-ng --memrate`
- IO uses `fio` templates and the shared host path
- network uses `iperf3`

Once you understand the CPU path, the rest of the repository follows the same pattern.
