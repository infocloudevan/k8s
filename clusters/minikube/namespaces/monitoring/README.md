# Prometheus Operator
## [Prometheus](https://github.com/helm/charts/tree/master/stable/prometheus-operator)

```console
$ kubectl create namespace monitoring
$ helm upgrade --install prometheus --namespace monitoring --version 9.3.1 stable/prometheus-operator -f prometheus-operator-values.yaml
```

# Metrics Server
## [Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
Need to be configured kops managed cluster first [Github Issue](https://github.com/kubernetes-sigs/metrics-server/issues/247#issuecomment-583687056)
```console
$ kops edit cluster --name {cluster_name}
```

Edit following part
```console
    kubelet:
    anonymousAuth: false
    authenticationTokenWebhook: true
    authorizationMode: Webhook
```

```console
$ kops update cluster --yes
$ kops rolling-update cluster--yes
```console

```console

$ kubectl create namespace monitoring
$ helm upgrade --install metrics-server --namespace monitoring --version 2.11.2  stable/metrics-server -f metrics-server-values.yaml
```

# Kafka-minion and burrow Deployment

## [kafka-minion](https://github.com/cloudworkz/kafka-minion-helm-chart)
```console
helm repo add kafka-minion https://raw.githubusercontent.com/cloudworkz/kafka-minion-helm-chart/master
helm repo update
```

```console
$ kubectl create namespace monitoring
$ helm install kafka-minion --namespace monitoring --version 1.2.2 kafka-minion/kafka-minion  -f https://raw.githubusercontent.com/darkcubed/k8s/upgrade/clusters/test/namespaces/monitoring/kafka-minion-values.yaml?token=ALMLBGQPVBAMJ354PEHVKCS7HKPNQ
```

# [burrow](https://github.com/Lowess/helm-charts/)

Note: lowess repo [cloned](https://github.com/kadirtaskiran/helm-charts/) and modified for small bugs. Dark3 has own helm chart based ond lowess now.

```console
helm repo add lowess-helm https://lowess.github.io/helm-charts
helm repo update
```

```console
$ helm install burrow --namespace monitoring --version 0.1.3 lowess-helm/burrow  -f https://raw.githubusercontent.com/darkcubed/k8s/upgrade/clusters/test/namespaces/monitoring/burrow-values.yaml?token=ALMLBGR36IRA6VY55MTZWWK7HKPKS

#To use Dark3 chart repo
$ helm install burrow --namespace monitoring --version 0.1.5 dark3/burrow  -f https://raw.githubusercontent.com/darkcubed/k8s/upgrade/clusters/test/namespaces/monitoring/burrow-values.yaml?token=ALMLBGR36IRA6VY55MTZWWK7HKPKS

```

# README from [Official Chart Repo](https://github.com/cloudworkz/kafka-minion-helm-chart)

## Kafka Minion Helm Chart

Helm chart for deployment of Kafka Minion

### Installing helm chart

```
helm repo add kafka-minion https://raw.githubusercontent.com/cloudworkz/kafka-minion-helm-chart/master
helm repo update
helm install --name=kafka-minion kafka-minion/kafka-minion
```

### Chart configuration

**NOTE:** You may want to adapt the readiness probe values depending on your kafka cluster size. To ensure high availability during rolling updates Kafka Minion marks itself ready only after it has completely processed the `__consumer_offsets` topic. By default it has up to 10 minutes and 10 seconds to do so, then it's getting killed by Kubernetes.

| Parameter | Description | Default |
| --- | --- | --- |
| `telemetry.host` | Host for prometheus server to to listen on | `0.0.0.0` |
| `telemetry.port` | Port for prometheus server to listen on | `8080` |
| `logLevel` | Logger's log granularity (debug, info, warn, error, fatal, panic) | `info` |
| `livenessProbe.initialDelaySeconds` | Number of seconds after the container has started before liveness or readiness probes are initiated | `10` |
| `livenessProbe.periodSeconds` | How often (in seconds) to perform the probe. Default to 10 seconds. Minimum value is 1. | `10` |
| `livenessProbe.timeoutSeconds` | Number of seconds after which the probe times out. Defaults to 1 second. Minimum value is 1 | `5` |
| `livenessProbe.failureThreshold` | When a Pod starts and the probe fails, Kubernetes will try failureThreshold times before giving up. Minimum value is 1. | `60` |
| `readinessProbe.initialDelaySeconds` | Number of seconds after the container has started before liveness or readiness probes are initiated | `10` |
| `readinessProbe.periodSeconds` | How often (in seconds) to perform the probe. Default to 10 seconds. Minimum value is 1. | `10` |
| `readinessProbe.timeoutSeconds` | Number of seconds after which the probe times out. Defaults to 1 second. Minimum value is 1 | `5` |
| `readinessProbe.failureThreshold` | When a Pod starts and the probe fails, Kubernetes will try failureThreshold times before giving up. Minimum value is 1. | `60` |
| `podSecurityContext.runAsUser` | UserID to use for the pod | `99` |
| `podSecurityContext.fsGroup` | User group to use for the pod | `99` |
| `containerSecurityContext` | Security Context for the kafka minion container | `{}` |
| `kafka.brokers` | Comma delimited list of brokers to connect to | (none) |
| `kafka.sasl.enabled` | Bool to enable/disable SASL authentication (only SASL_PLAINTEXT is supported) | `false` |
| `kafka.sasl.useHandshake` | Whether or not to send the Kafka SASL handshake first | `true` |
| `kafka.sasl.credentials.existingSecret` | Secretname of an existing secret which contains SASL credentials | (none) |
| `kafka.sasl.credentials.username` | SASL username | (none) |
| `kafka.sasl.credentials.password` | SASL password | (none) |
| `kafka.tls.enabled` | Whether or not to use TLS when connecting to the broker | `false` |
| `kafka.tls.insecureSkipTlsVerify` | If true, TLS accepts any certificate presented by the server and any host name in that certificate. | `true` |
| `kafka.tls.certificates.existingSecret` | Secretname of an existing secret which contains TLS certificates | (none) |
| `kafka.tls.certificates.ca` | TLS CA | (none) |
| `kafka.tls.certificates.cert` | TLS Cert | (none) |
| `kafka.tls.certificates.key` | TLS Key | (none) |
| `kafka.tls.certificates.passphrase` | Key to decrypt TLS key | (none) |
| `serviceMonitor.create` | Whether or not to create a service monitor for prometheus operator | `false` |
| `serviceMonitor.interval` | Scrape interval for prometheus operator | `10s` |
| `serviceMonitor.scrapeTimeout` | Scrape timeout for prometheus operator | `10s` |
| `serviceMonitor.releaseLabel` | Release label being used for prometheus operator selector | `prometheus-operator` |
| `serviceMonitor.additionalLabels` | Additional labels to add to the ServiceMonitor | (none) |
| `podAnnotations` | Pod annotations | `{}` |
| `priorityClassName` | Priority Class to be used by the pod | `""` |
| `podSecurityPolicy.enabled` | Enable/disable PodSecurityPolicy and associated Role/Rolebinding creation | `false` |
| `serviceAccount.create` | Create a ServiceAccount for the pod | `false` |
| `serviceAccount.name` | Name of a ServiceAccount to use that is not handled by this chart | `default` |

### SASL/SSL Setup

When configuring SASL or TLS you can either provide the secretname of an existing secret **or** pass the contents as values. When you choose to create the secrets on your own, please make sure you comply with the key names used in this chart:

##### SASL

Key names are `username` and `password`.

```yml
type: Opaque
data:
  username:
  password:
```

##### TLS

Key names are `tls.ca`, `tls.key`, `tls.crt` and `passphrase`.

```yml
type: Opaque
data:
  tls.ca:
  tls.key:
  tls.crt:
  passphrase:
```

#
