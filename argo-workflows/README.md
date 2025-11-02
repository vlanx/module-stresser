# Argo Workflows

This contains the installation procedures I did and some considerations.

Since I wanted to have the `server` and `workflow-controller` of Argo Workflows be exclusively on master, I had to patch the installation `yaml`.
The patch files (applied with Kustomize) are inside the dir `argo-install-master-only`

Additionally, we specify in the workflows the `nodeSelector`, but we taint the master either way. Just to be safer.

```bash
kubectl taint nodes dev-env node-role.kubernetes.io/master=:NoSchedule
```

Make the server GUI accessible:
```bash
kubectl -n argo port-forward svc/argo-server 2746:2746
```
