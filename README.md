# nautobot-kubernetes
Custom built Nautobot container for my homelab


## Boot strap FLux
validate the current context of your Kubectl

```
$ kubectl config current-context
default 
```

create a new github repo for this project

```
flux bootstrap git \
  --url=https://github.com/byrn-baker/nautobot-kubernetes \
  --username=$GITHUB_USERNAME \
  --password=$GITHUB_FLUX_TOKEN \
  --token-auth=true \
  --branch=main \
  --path=clusters/home

► cloning branch "main" from Git repository "https://github.com/byrn-baker/nautobot-kubernetes"
✔ cloned repository
► generating component manifests
✔ generated component manifests
✔ committed component manifests to "main" ("30e10745cea64d0574122d823af1c10670399aa7")
► pushing component manifests to "https://github.com/byrn-baker/nautobot-kubernetes"
✔ reconciled components
► determining if source secret "flux-system/flux-system" exists
► generating source secret
► applying source secret "flux-system/flux-system"
✔ reconciled source secret
► generating sync manifests
✔ generated sync manifests
✔ committed sync manifests to "main" ("feba582d3a766195ea5f12313d4fa3698f2c9e18")
► pushing sync manifests to "https://github.com/byrn-baker/nautobot-kubernetes"
► applying sync manifests
✔ reconciled sync configuration
◎ waiting for GitRepository "flux-system/flux-system" to be reconciled
✔ GitRepository reconciled successfully
◎ waiting for Kustomization "flux-system/flux-system" to be reconciled
✔ Kustomization reconciled successfully
► confirming components are healthy
✔ helm-controller: deployment ready
✔ kustomize-controller: deployment ready
✔ notification-controller: deployment ready
✔ source-controller: deployment ready
✔ all components are healthy
```

You should now see the repo in your cluster
```
$ kubectl get GitRepository -A
NAMESPACE     NAME          URL                                                 AGE   READY   STATUS
flux-system   flux-system   https://github.com/byrn-baker/nautobot-kubernetes   25h   True    stored artifact for revision 'main@sha1:feba582d3a766195ea5f12313d4fa3698f2c9e18'
```

You your ```./clusters/home/flux-system``` folder you should see three files. The kustomization.yaml file will define the files that flux will track as part of the CI/CD definitions and what is being pushed to the cluster.

it should look something like this
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- gotk-components.yaml
- gotk-sync.yaml
```

You can see the kustomization for flux in the cluster. the ```spec.sourceRef``` defines what repo objects being tracked.
```
$ kubectl get kustomization -n flux-system flux-system -o yaml
apiVersion: kustomize.toolkit.fluxcd.io/v1
kind: Kustomization
metadata:
  creationTimestamp: "2024-03-16T17:01:41Z"
  finalizers:
  - finalizers.fluxcd.io
  generation: 1
  labels:
    kustomize.toolkit.fluxcd.io/name: flux-system
    kustomize.toolkit.fluxcd.io/namespace: flux-system
  name: flux-system
  namespace: flux-system
  resourceVersion: "2070912"
  uid: d1cc7b6e-5140-4398-a1d4-058b2ee98081
spec:
  force: false
  interval: 10m0s
  path: ./clusters/home
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
status:
  conditions:
  - lastTransitionTime: "2024-03-17T18:36:35Z"
    message: 'Applied revision: main@sha1:feba582d3a766195ea5f12313d4fa3698f2c9e18'
    observedGeneration: 1
    reason: ReconciliationSucceeded
    status: "True"
    type: Ready
```
Nautobot will require its own kustomization so that we can define what should be tracked as part of our project. In the flux-system folder create a new file and call it ```nautobot-kustomization.yaml```

add the following to the file

```
---
apiVersion: kustomize.toolkit.fluxcd.io/v1beta2
kind: Kustomization
metadata:
  name: nautobot-kustomization
  namespace: flux-system
spec:
  force: false
  interval: 1m0s
  path: ./kubernetes
  prune: true
  sourceRef:
    kind: GitRepository
    name: flux-system
```

We will need to add this to our kustomization.yaml that flux is using so that our nautobot CRDs are tracked as well.

which should look like this

```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
resources:
- gotk-components.yaml
- gotk-sync.yaml
- nautobot-kustomization.yaml
```

