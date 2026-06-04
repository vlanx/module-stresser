# Argo Workflows

This contains the installation procedures I did and some considerations.

Since I wanted to have the `server` and `workflow-controller` of Argo Workflows be exclusively on master, I had to patch the installation `yaml`.
The patch files (applied with Kustomize) are inside the dir `argo-install-master-only`

Additionally, we specify in the workflows the `nodeSelector`, but we taint the master either way. Just to be safer.

###### Note: I use the namespace `stress` for all the stress containers

```bash
kubectl taint nodes dev-env node-role.kubernetes.io/master=:NoSchedule
```

Make the server GUI accessible:
```bash
kubectl -n argo port-forward svc/argo-server 2746:2746
```

### Usage

Install `argo` CLI client

##### Update/create a Workflow Template

```bash
argo template <create/update> </path/to/template.yaml>
```

##### Run a Workflow

```bash
argo submit </path/to/template.yaml>
```

##### List templates

```bash
argo template list -n <namespace>
```
