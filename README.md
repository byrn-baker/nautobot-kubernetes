# nautobot on kubernetes
I am joining the #100DayOfHomeLab challene and as part of this effort I am going to use that time to teach myself something new. 

I love the [Nautobot](https://networktocode.com/nautobot/) and use it all the time at home and at work. I have always deployed this on a standard ubuntu VM, but recently I started to gain interest in deploying it with docker while learning how to create a Nautobot Application. This lead me to looking at Kubernetes and watching a lot of youtube videos on setting up kubernetes. Now I wondered how can I deploy nautobot inside my k3s cluster? Fortunatly there are examples out there and so I stand on the shoulders of those who have figured this all for me. 

For great walk throughs on k3s, traefik, metallb and deploying your cluster with ansible have a look [here](https://github.com/techno-tim/k3s-ansible), and for flux check [this](https://www.youtube.com/watch?v=PFLimPh5-wo) out.

For the original content to the majority of my walk through check out this blog series from networktocode - [part 1](https://blog.networktocode.com/post/deploying-nautobot-to-kubernetes-01/), [part 2](https://blog.networktocode.com/post/deploying-nautobot-to-kubernetes-02/), and [part 3](https://blog.networktocode.com/post/deploying-nautobot-to-kubernetes-03/)


## Part 1 - 2024.03.17
Now on to learning how to setup Flux with a k3s cluster and install the Nautobot App. 

### Boot strap FLux 
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

### Setting your folder structure to deploy nautobot
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

You cluster should be tracking these changes and show the new CRD just created. We have not created the path yet set in the CRD so there is no folder yet to track.
```
$ kubectl get kustomization -n flux-system
NAME                     AGE   READY   STATUS
flux-system              25h   True    Applied revision: main@sha1:9820cde831fc7ab46fef794940cd601a8b73e025
nautobot-kustomization   7s    False   kustomization path not found: stat /tmp/kustomization-602987848/kubernetes: no such file or directory
```

Create a folder that matches the path set forth above. ```./kubernetes```. We will create two files ```./kubernetes/namespace.yaml```, and ```./kubernetes/kustomization.yaml```. kustomization will be used to specify resources, namespace, and configurations for Nautobot and namespace will be used to generate the new namespace for this project.

Checking the clusters Kustomization again you can see the cluster has benn updated. Our Kustomization file is empty, but that will change very soon.

```
$ kubectl get kustomization -n flux-system
NAME                     AGE     READY   STATUS
flux-system              25h     True    Applied revision: main@sha1:83b4c37a23694d646c1593c535834ef6fcb2231d
nautobot-kustomization   8m54s   False   kustomize build failed: kustomization.yaml is empty
```

We will use the [Nautobot HelmChart](https://docs.nautobot.com/projects/helm-charts/en/stable/) to install the Nautobot application, this will be similar to installing this manually via helm and requires similar values as well.

Create a new file ```./kubernetes/nautobot-helmrepo.yaml```. This will define where the HelmChart will be pulled from. Place the following in this file:
```
---
apiVersion: "source.toolkit.fluxcd.io/v1beta2"
kind: "HelmRepository"
metadata:
  name: "nautobot"
  namespace: "nautobot"
spec:
  url: "https://nautobot.github.io/helm-charts/"
  interval: "10m"
```

Create ```./kubernetes/values.yaml``` and place the below in:
```
---
postgresql:
  postgresqlPassword: "SuperSecret123"
redis:
  auth:
    password: "SuperSecret456"
```

We will use the values file to generate a ConfigMap in our cluster, the same method is used if you would deploy this manually with Helm. Update the ```./kubernetes/kustomization.yaml``` to include these new files. This defines how Nautobot will be installed inside the cluster.

It should now look like this
```
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization

namespace: nautobot

resources:
  - namespace.yaml
  - nautobot-helmrepo.yaml

generatorOptions:
  disableNameSuffixHash: true

configMapGenerator:
  - name: "nautobot-values"
    files:
      - "values=values.yaml"
```

Now create a file ```./kubernetes/helmrelease.yaml```. This file defines what HelmChart version to use in the application deployment. The HelmChart defined all of the other dependancy this application requires to run, so we don't have to. Defined below is the charter version, and where it should look for the specific nautobot values we want to define.

```
---
apiVersion: "helm.toolkit.fluxcd.io/v2beta1"
kind: "HelmRelease"
metadata:
  name: "nautobot"
spec:
  interval: "30s"
  chart:
    spec:
      chart: "nautobot"
      version: "1.3.12"
      sourceRef:
        kind: "HelmRepository"
        name: "nautobot"
        namespace: "nautobot"
      interval: "20s"
  valuesFrom:
    - kind: "ConfigMap"
      name: "nautobot-values"
      valuesKey: "values"
```

Be sure to update your ```./kubernetes/kustomization.yaml``` to track these new files. Commit this to your repo, and we should start to see the cluster deploy the application.

We should see that our kustomization in the cluster has been updated

```
$ kubectl get kustomization -n flux-system
NAME                     AGE   READY   STATUS
flux-system              26h   True    Applied revision: main@sha1:ec6b061c699fde8e78ecfb8d92b1e4d183ff53dc
nautobot-kustomization   25m   True    Applied revision: main@sha1:ec6b061c699fde8e78ecfb8d92b1e4d183ff53dc
```

Also we should see helm installing the app
```
$ kubectl get helmreleases -n nautobot
NAME       AGE   READY     STATUS
nautobot   78s   Unknown   Running 'install' action with timeout of 5m0s
```

We should also see that pods have been created in our new nautobot namespace. This takes several minutes as Nautobot has to initialze. We can watch the logs of a given pod with kubectl - ```$ kubectl logs -n nautobot nautobot-58d7fc66f6-5h24f```. You find the pod name with the below command.
```
$ kubectl get pods -n nautobot
NAME                                     READY   STATUS    RESTARTS        AGE
nautobot-58d7fc66f6-5h24f                1/1     Running   3 (2m56s ago)   7m47s
nautobot-58d7fc66f6-tr9l6                1/1     Running   2 (4m26s ago)   7m47s
nautobot-celery-beat-84cf4b547f-v4qq9    1/1     Running   5 (5m21s ago)   7m47s
nautobot-celery-worker-5b9c7648f-6wgdc   1/1     Running   2 (7m5s ago)    7m47s
nautobot-celery-worker-5b9c7648f-c9qzp   1/1     Running   3 (6m49s ago)   7m47s
nautobot-postgresql-0                    1/1     Running   0               7m47s
nautobot-redis-master-0                  1/1     Running   0               7m47s
```

Excelent we have the deployment up and running. We can get further details with ```kubectl describe deployment -n nautobot nautobot```. This will provide details on the docker container version used, along with the exposed ports inside the cluster. Now we need to define how the application can be accessed from outside the cluster.

### How to configure traefik to route requests to Nautobot
In my particular cluster I'm using Traefik as a reverse proxy to my cluster applications. This requires some additional files to define how outside users will be routed to these internal resources. We will need to create two additional files ```./kubernetes/ingress.yaml``` & ```./kubernetes/default-headers.yaml```. 

In the ingress file we will need to tell traefik where it should route requests. This will be done based on the fqdn being requested. On your local DNS server you will want to create an fdqn for natuobot that points at the clusters loadbalancer. 

The ingress.yaml defines what API and kind of configuration to be used in the cluster. We need to provide a name and a namespace as well as the ingress class to be used. The specs outline the entrypoint (typically http/web, or https/websecure) based on your prefrence. Routes define the hostname matching (what does into your browser url) and the services traefik should be routing this request to. Middlewares for our purposes set the type of headers to maintain or adjust depending on your application requirements. 

ingress.yaml:
```
---
apiVersion: traefik.containo.us/v1alpha1
kind: IngressRoute
metadata:
  name: nautobot
  namespace: nautobot
  annotations:
    kubernetes.io/ingress.class: traefik-external
spec:
  entryPoints:
    - websecure
  routes:
    - match: Host(`nautobot.local.byrnbaker.me`)
      kind: Rule
      services:
        - name: nautobot
          port: 80
      middlewares:
        - name: default-headers
```

As stated above we will use this to control the headers maintained through traefik. 
default-headers.yaml:
```
apiVersion: traefik.containo.us/v1alpha1
kind: Middleware
metadata:
  name: default-headers
  namespace: nautobot
spec:
  headers:
    browserXssFilter: true
    contentTypeNosniff: true
    customFrameOptionsValue: SAMEORIGIN
    customRequestHeaders:
      X-Forwarded-Proto: https
    forceSTSHeader: true
    stsIncludeSubdomains: true
    stsPreload: true
    stsSeconds: 15552000
```
We need to make sure these are being tracked with flux, so update the resources list in ```./kubernetes/kustomization.yaml``` with these two new files. Commit your changes and in a few minutes we should be able to see the updates pushed down to the cluster.

We can see flux reconciling the new commit
```
$ kubectl get kustomization -n flux-system
NAME                     AGE   READY     STATUS
flux-system              26h   Unknown   Reconciliation in progress
nautobot-kustomization   68m   True      Applied revision: main@sha1:7c4a8a579e1025a02a6c927d5ffeabce562b2f64
ubuntu@ubuntu-2204-server:~/nautobot-kubernetes$ kubectl get kustomization -n flux-system
NAME                     AGE   READY   STATUS
flux-system              26h   True    Applied revision: main@sha1:7c4a8a579e1025a02a6c927d5ffeabce562b2f64
nautobot-kustomization   69m   True    Applied revision: main@sha1:7c4a8a579e1025a02a6c927d5ffeabce562b2f64
```

We can see the new ingressroute in our namespace
```
$ kubectl get ingressroute -n nautobot
NAME       AGE
nautobot   18m
```

Here we can see some more details if we describe it. This should match what we placed inside of our ingress.yaml file.
```
$ kubectl describe ingressroute nautobot -n nautobot
Name:         nautobot
Namespace:    nautobot
Labels:       kustomize.toolkit.fluxcd.io/name=nautobot-kustomization
              kustomize.toolkit.fluxcd.io/namespace=flux-system
Annotations:  kubernetes.io/ingress.class: traefik-external
API Version:  traefik.containo.us/v1alpha1
Kind:         IngressRoute
Metadata:
  Creation Timestamp:  2024-03-17T19:41:15Z
  Generation:          2
  Resource Version:    2132422
  UID:                 06d1b726-689a-47a2-bd71-8e63e0060071
Spec:
  Entry Points:
    websecure
  Routes:
    Kind:   Rule
    Match:  Host(`nautobot.local.byrnbaker.me`)
    Middlewares:
      Name:  default-headers
    Services:
      Name:  nautobot
      Port:  80
Events:      <none>
```
browsing to our defined fqdn should allow you to access your nautobot app.

When defining our values we did not specify any login credentials for this application. Those have been defined for us and here is how you can retrieve them.

### How to get the generated admin password and API token
```
echo Username: admin
  echo Password: $(kubectl get secret --namespace nautobot nautobot-env -o jsonpath="{.data.NAUTOBOT_SUPERUSER_PASSWORD}" | base64 --decode)
  echo api-token: $(kubectl get secret --namespace nautobot nautobot-env -o jsonpath="{.data.NAUTOBOT_SUPERUSER_API_TOKEN}" | base64 --decode)
```

## Part 2 - Creating your own custom container
There are a lot of great Nautobot apps that compliment and extend the usefullness of Nautobot, and I want to include some of those into my deployment. First lets create a new container of our own based on the nautobot base image.

```
$ docker build -t ghcr.io/byrn-baker/nautobot-kubernetes:dev .
[+] Building 53.0s (6/6) FINISHED                                                                                                                                                                                                                                                                                                                      docker:default
 => [internal] load build definition from Dockerfile                                                                                                                                                                                                                                                                                                             0.0s
 => => transferring dockerfile: 157B                                                                                                                                                                                                                                                                                                                             0.0s
 => [internal] load metadata for ghcr.io/nautobot/nautobot:1.4.2-py3.9                                                                                                                                                                                                                                                                                           6.7s
 => [auth] nautobot/nautobot:pull token for ghcr.io                                                                                                                                                                                                                                                                                                              0.0s
 => [internal] load .dockerignore                                                                                                                                                                                                                                                                                                                                0.1s
 => => transferring context: 2B                                                                                                                                                                                                                                                                                                                                  0.0s
 => [1/1] FROM ghcr.io/nautobot/nautobot:1.4.2-py3.9@sha256:59f4d8338a1e6025ebe0051ee5244d4c0e94b0223079f806eb61eb63b6a04e62                                                                                                                                                                                                                                    46.0s
 => => resolve ghcr.io/nautobot/nautobot:1.4.2-py3.9@sha256:59f4d8338a1e6025ebe0051ee5244d4c0e94b0223079f806eb61eb63b6a04e62                                                                                                                                                                                                                                     0.0s
 => => sha256:b94fc7ac342a843369c0eaa335613ab9b3761ff5ddfe0217a65bfd3678614e22 11.59MB / 11.59MB                                                                                                                                                                                                                                                                 0.9s
 => => sha256:e262aa54edc9b180deacc4ca2f74512239dd29c964d720431f590674913040b7 4.09kB / 4.09kB                                                                                                                                                                                                                                                                   0.0s
 => => sha256:7a6db449b51b92eac5c81cdbd82917785343f1664b2be57b22337b0a40c5b29d 31.38MB / 31.38MB                                                                                                                                                                                                                                                                 1.7s
 => => sha256:e238bceb29579b6804c25c4e8c81612003af698ef4ca42c46fa87d4ef371653c 1.08MB / 1.08MB                                                                                                                                                                                                                                                                   0.7s
 => => sha256:59f4d8338a1e6025ebe0051ee5244d4c0e94b0223079f806eb61eb63b6a04e62 743B / 743B                                                                                                                                                                                                                                                                       0.0s
 => => sha256:a53d88893414ba30c40c2405436b8c0e2235c7af779506fcb0538cf6534c1ae4 12.49kB / 12.49kB                                                                                                                                                                                                                                                                 0.0s
 => => sha256:aa1ba22295b5c00526e5e18298d5003125b2681e3482b2b7816972597d657ab9 233B / 233B                                                                                                                                                                                                                                                                       0.9s
 => => sha256:76b791f9be0ae4e2896a833164996db3d30fc5f11ee3ccc6fead21577df3d1c5 3.18MB / 3.18MB                                                                                                                                                                                                                                                                   1.5s
 => => sha256:af87da8d87840f333266d174a8ba3a95c32c10e2d728788e8bc38583a7cbaab3 44.99MB / 44.99MB                                                                                                                                                                                                                                                                 3.2s
 => => sha256:25d669acda2475d375d839afc5a3e7ef05670b8ea717f46a4a6b3179365a1687 143B / 143B                                                                                                                                                                                                                                                                       1.7s
 => => extracting sha256:7a6db449b51b92eac5c81cdbd82917785343f1664b2be57b22337b0a40c5b29d                                                                                                                                                                                                                                                                        4.6s
 => => sha256:662197511b86dd33a615825def54fb205daf861d45e7f4a8457c942f79dac86b 1.44kB / 1.44kB                                                                                                                                                                                                                                                                   1.9s
 => => sha256:26c97d3816cf7c585a1fab918a6c7d74fb9094d755d37f6674f318569a86b479 60.32MB / 60.32MB                                                                                                                                                                                                                                                                 4.8s
 => => sha256:dda97b4f6f26d4fc347fbb6ad9c7b33f8ef3ab1e919b6b0e7731de3cc3f04f5e 2.35kB / 2.35kB                                                                                                                                                                                                                                                                   2.1s
 => => sha256:83f2a5cdac6141b5dd64c7e145450c47be3d397c9fe8028109b1dde8698867c8 48.67MB / 48.67MB                                                                                                                                                                                                                                                                 4.5s
 => => sha256:f466dd551ea2aafdf62754b1fa9586776878e1f482af406aaed4f3143011a1e3 49.85MB / 49.85MB                                                                                                                                                                                                                                                                 6.2s
 => => sha256:865e1c397b557f98dfa2a45e7912d3b6552d275a375e616580404b8fabc3706d 1.31kB / 1.31kB                                                                                                                                                                                                                                                                   5.0s
 => => sha256:87c787bcec6ffa56d67767c16a20f360822258fb768af4590eeb8c32a4c471ba 3.67kB / 3.67kB                                                                                                                                                                                                                                                                   5.0s
 => => sha256:27faeb65e5025ce8adf3e7ccb7436f0805ec8535d7709706a7caa170bca9251d 7.48kB / 7.48kB                                                                                                                                                                                                                                                                   5.2s
 => => sha256:7c8ffb49c0dfcc5c41591631a49ecfc73def1ef11e99409a5dac22675725687d 499B / 499B                                                                                                                                                                                                                                                                       5.2s
 => => sha256:8a4f3d60582c68bbdf8beb6b9d5fe1b0d159f2722cf07938ca9bf290dbfaeb6e 5.00kB / 5.00kB                                                                                                                                                                                                                                                                   5.4s
 => => sha256:4f4fb700ef54461cfa02571ae0db9a0dc1e0cdb5577484a6d75e68dc38e8acc1 32B / 32B                                                                                                                                                                                                                                                                         5.3s
 => => extracting sha256:e238bceb29579b6804c25c4e8c81612003af698ef4ca42c46fa87d4ef371653c                                                                                                                                                                                                                                                                        0.4s
 => => extracting sha256:b94fc7ac342a843369c0eaa335613ab9b3761ff5ddfe0217a65bfd3678614e22                                                                                                                                                                                                                                                                        1.4s
 => => extracting sha256:aa1ba22295b5c00526e5e18298d5003125b2681e3482b2b7816972597d657ab9                                                                                                                                                                                                                                                                        0.0s
 => => extracting sha256:76b791f9be0ae4e2896a833164996db3d30fc5f11ee3ccc6fead21577df3d1c5                                                                                                                                                                                                                                                                        0.9s
 => => extracting sha256:af87da8d87840f333266d174a8ba3a95c32c10e2d728788e8bc38583a7cbaab3                                                                                                                                                                                                                                                                        5.9s
 => => extracting sha256:25d669acda2475d375d839afc5a3e7ef05670b8ea717f46a4a6b3179365a1687                                                                                                                                                                                                                                                                        0.0s
 => => extracting sha256:662197511b86dd33a615825def54fb205daf861d45e7f4a8457c942f79dac86b                                                                                                                                                                                                                                                                        0.0s
 => => extracting sha256:26c97d3816cf7c585a1fab918a6c7d74fb9094d755d37f6674f318569a86b479                                                                                                                                                                                                                                                                       23.6s
 => => extracting sha256:dda97b4f6f26d4fc347fbb6ad9c7b33f8ef3ab1e919b6b0e7731de3cc3f04f5e                                                                                                                                                                                                                                                                        0.0s
 => => extracting sha256:83f2a5cdac6141b5dd64c7e145450c47be3d397c9fe8028109b1dde8698867c8                                                                                                                                                                                                                                                                        0.9s
 => => extracting sha256:f466dd551ea2aafdf62754b1fa9586776878e1f482af406aaed4f3143011a1e3                                                                                                                                                                                                                                                                        3.2s
 => => extracting sha256:87c787bcec6ffa56d67767c16a20f360822258fb768af4590eeb8c32a4c471ba                                                                                                                                                                                                                                                                        0.0s
 => => extracting sha256:865e1c397b557f98dfa2a45e7912d3b6552d275a375e616580404b8fabc3706d                                                                                                                                                                                                                                                                        0.0s
 => => extracting sha256:7c8ffb49c0dfcc5c41591631a49ecfc73def1ef11e99409a5dac22675725687d                                                                                                                                                                                                                                                                        0.0s
 => => extracting sha256:27faeb65e5025ce8adf3e7ccb7436f0805ec8535d7709706a7caa170bca9251d                                                                                                                                                                                                                                                                        0.0s
 => => extracting sha256:4f4fb700ef54461cfa02571ae0db9a0dc1e0cdb5577484a6d75e68dc38e8acc1                                                                                                                                                                                                                                                                        0.0s
 => => extracting sha256:8a4f3d60582c68bbdf8beb6b9d5fe1b0d159f2722cf07938ca9bf290dbfaeb6e                                                                                                                                                                                                                                                                        0.0s
 => exporting to image                                                                                                                                                                                                                                                                                                                                           0.0s
 => => exporting layers                                                                                                                                                                                                                                                                                                                                          0.0s
 => => writing image sha256:d9a37159279f8bd77a47ab44b51408267312c70c84552556eb71456843d89bea                                                                                                                                                                                                                                                                     0.0s
 => => naming to ghcr.io/byrn-baker/nautobot-kubernetes:dev
```

We have our new image created:
```
$ docker image ls
REPOSITORY                               TAG       IMAGE ID       CREATED         SIZE
ghcr.io/byrn-baker/nautobot-kubernetes   dev       d9a37159279f   18 months ago   580MB
```

A Makefile can be used to simplify the building, pushing, and pulling of new version of this container as we progress.

```
# Get current branch by default
tag := $(shell git rev-parse --abbrev-ref HEAD)

build:
	docker build -t ghcr.io/byrn-baker/nautobot-kubernetes:$(tag) .

push:
	docker push ghcr.io/byrn-baker/nautobot-kubernetes:$(tag)

pull:
	docker pull ghcr.io/byrn-baker/nautobot-kubernetes:$(tag)
```

Test the Building and Pushing with your Makefile:

```
$ make build
docker build -t ghcr.io/byrn-baker/nautobot-kubernetes:main .
[+] Building 1.1s (6/6) FINISHED                                                                                                                                                                                                                                                                                                                       docker:default
 => [internal] load build definition from Dockerfile                                                                                                                                                                                                                                                                                                             0.0s
 => => transferring dockerfile: 157B                                                                                                                                                                                                                                                                                                                             0.0s
 => [internal] load metadata for ghcr.io/nautobot/nautobot:1.4.2-py3.9                                                                                                                                                                                                                                                                                           0.9s
 => [auth] nautobot/nautobot:pull token for ghcr.io                                                                                                                                                                                                                                                                                                              0.0s
 => [internal] load .dockerignore                                                                                                                                                                                                                                                                                                                                0.0s
 => => transferring context: 2B                                                                                                                                                                                                                                                                                                                                  0.0s
 => CACHED [1/1] FROM ghcr.io/nautobot/nautobot:1.4.2-py3.9@sha256:59f4d8338a1e6025ebe0051ee5244d4c0e94b0223079f806eb61eb63b6a04e62                                                                                                                                                                                                                              0.0s
 => exporting to image                                                                                                                                                                                                                                                                                                                                           0.0s
 => => exporting layers                                                                                                                                                                                                                                                                                                                                          0.0s
 => => writing image sha256:d9a37159279f8bd77a47ab44b51408267312c70c84552556eb71456843d89bea                                                                                                                                                                                                                                                                     0.0s
 => => naming to ghcr.io/byrn-baker/nautobot-kubernetes:main
 ```

 ```
$ make push
docker push ghcr.io/byrn-baker/nautobot-kubernetes:main
The push refers to repository [ghcr.io/byrn-baker/nautobot-kubernetes]
3cec5ea1ba13: Mounted from nautobot/nautobot 
5f70bf18a086: Mounted from byrn-baker/nautobot-k3s 
4078cbb0dac2: Mounted from nautobot/nautobot 
28330db6782d: Mounted from nautobot/nautobot 
46b0ede2b6bc: Mounted from nautobot/nautobot 
f970a3b06182: Mounted from nautobot/nautobot 
50f757c5b291: Mounted from nautobot/nautobot 
34ada2d2351f: Mounted from nautobot/nautobot 
2fe7c3cac96a: Mounted from nautobot/nautobot 
ba48a538e919: Mounted from nautobot/nautobot 
639278003173: Mounted from nautobot/nautobot 
294d3956baee: Mounted from nautobot/nautobot 
5652b0fe3051: Mounted from nautobot/nautobot 
782cc2d2412a: Mounted from nautobot/nautobot 
1d7e8ad8920f: Mounted from nautobot/nautobot 
81514ea14697: Mounted from nautobot/nautobot 
630337cfb78d: Mounted from nautobot/nautobot 
6485bed63627: Mounted from nautobot/nautobot 
main: digest: sha256:122f9ddd54ba67893c5292986f1c5433b3c1ce2ba651c76e7732631ee5776178 size: 4087
 ```

Now lets see if we can deploy this custom image to our cluster. We need to update the values.yaml with our custom image registery and repo information. You will need to create a secret for your repo so that it can be pulled as part of the CI/CD workflow. You can find this under the repo settings and secrets, your personal access token can be placed there.
```
nautobot:
  image:
    registry: "ghcr.io"
    repository: "byrn-baker/nautobot-kubernetes"
    tag: "main"
    pullSecrets:
      - "ghcr.io"
```
We can also add this secret to our cluster as well. 
```
$ kubectl create secret docker-registry --docker-server=ghcr.io --docker-username=byrn-baker --docker-password=$GITHUB_FLUX_TOKEN -n nautobot ghcr.io
secret/ghcr.io created
```
Commit and push the changes to your repo.
