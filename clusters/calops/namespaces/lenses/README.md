# Lenses.io with Helm Chart
## [Lenses.io](https://docs.lenses.io/4.0/installation/kubernetes/)

```console
# Add lenses helm chart repo
$ helm repo add lensesio https://helm.repo.lenses.io
$ helm repo update

# Install lenses to cluster
$ kubectl create namespace lenses
$ helm upgrade --install lenses --namespace lenses --version 4.1.0 lensesio/lenses -f lenses-values.yaml
```

