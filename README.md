# nautobot on kubernetes
Custom Nautobot image to deploy into Kubernetes cluster


Create the docker image
```bash
make build
```

Push it to your Github Repo
```bash
make push
```
Setup Flux
```bash
flux bootstrap git \
  --url=https://github.com/byrn-baker/nautobot-kubernetes \
  --username=$GITHUB_USERNAME \
  --password=$GITHUB_FLUX_TOKEN \
  --token-auth=true \
  --branch=main \
  --path=clusters/home
```

