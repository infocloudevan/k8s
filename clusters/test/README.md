## Install Nginx Ingress

https://kubernetes.github.io/ingress-nginx/deploy/

```
# Create the namespace for Nginx Ingress
kubectl --context azure-test create namespace kube-ingress

# Install the nginx-ingress Helm chart
helm --kube-context azure-test --namespace kube-ingress install nginx-ingress stable/nginx-ingress
```

## Install Cert Manager

http://docs.cert-manager.io/en/latest/getting-started/install/kubernetes.html#installing-with-helm

```
# Install the CustomResourceDefinition resources separately
kubectl --context azure-test apply -f https://raw.githubusercontent.com/jetstack/cert-manager/release-0.10/deploy/manifests/00-crds.yaml

# Create the namespace for cert-manager
kubectl --context azure-test create namespace cert-manager

# Label the cert-manager namespace to disable resource validation
kubectl --context azure-test label namespace cert-manager certmanager.k8s.io/disable-validation=true

# Add the Jetstack Helm repository
helm repo add jetstack https://charts.jetstack.io

# Update your local Helm chart repository cache
helm repo update

# Install the cert-manager Helm chart
helm --kube-context azure-test --namespace cert-manager install cert-manager jetstack/cert-manager --version v0.10.1
```

## Install Prometheus Operator

https://github.com/coreos/prometheus-operator

```
# Create the namespace for monitoring
kubectl --context azure-test create namespace monitoring

# Apply Prometheus Operator resources
curl -s https://raw.githubusercontent.com/coreos/prometheus-operator/master/bundle.yaml | sed --expression 's/namespace: default/namespace: monitoring/g' | kubectl --context azure-test apply -f -
```

## Install Grafana

https://github.com/helm/charts/tree/master/stable/grafana

```
# Install the grafana Helm chart
helm --kube-context azure-test --namespace monitoring install grafana stable/grafana \
  --set sidecar.dashboards.enabled=true \
  --set sidecar.dashboards.searchNamespace=ALL \
  --set sidecar.datasources.enabled=true \
  --set sidecar.datasources.searchNamespace=ALL
```

## Install Elastic Operator

https://www.elastic.co/guide/en/cloud-on-k8s/current/k8s-quickstart.html#k8s-deploy-eck

```
kubectl --context azure-test apply -f https://download.elastic.co/downloads/eck/0.9.0/all-in-one.yaml
```

## Install Strimzi Kafka Operator

https://strimzi.io/docs/latest/#deploying-cluster-operator-helm-chart-str


```
# Create the namespace for Strimzi
kubectl --context azure-test create namespace strimzi

# Add the Strimzi Helm repository
helm repo add strimzi https://strimzi.io/charts/

# Update your local Helm chart repository cache
helm repo update

# Install the Strimzi Kafka Operator Helm chart
helm --kube-context azure-test --namespace strimzi install strimzi strimzi/strimzi-kafka-operator \
  --set watchAnyNamespace=true
```

## Install Redis

https://github.com/helm/charts/tree/master/stable/redis

```
# Create the namespace for SaaS
kubectl --context azure-test create namespace saas

# Install the Redis Helm chart
helm --kube-context azure-test --namespace saas install redis stable/redis \
  --set cluster.enabled=false \
  --set usePassword=false \
  --set master.disableCommands=null
```
