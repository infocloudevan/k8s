# Using minikube For Local Development and Testing

## Minikube setup

```
minikube addons enable metrics-server
minikube addons enable dashboard
minikube addons enable ingress
```

## Helm Charts

### Kafka / Zookeeper

```
helm repo add bitnami https://charts.bitnami.com/bitnami

helm install kafka bitnami/kafka
```

### Redis

```
helm install redis stable/redis --set cluster.enabled=false,usePassword=false
```

### ElasticSearch / Kibana

```
helm repo add elastic https://helm.elastic.co

helm install es elastic/elasticsearch --set "replicas=1,clusterHealthCheckParams=wait_for_status=yellow&timeout=1s"
helm install kibana elastic/kibana --set service.type=LoadBalancer
```

## Build Dark Cubed Images

Run the following commands from the main `hyperdark` repository.

```
eval $(minikube docker-env)

docker build -t hyperdark .
make -C hack/saasdb build
```

## Initialize ElasticSearch Mappings and Scripts

Run the following commands from the main `hyperdark` repository.

NOTE: wait until ElasticSearch is showing `1/1 Running` in k8s before
continuing with the below commands.

```
kubectl --context minikube --namespace default port-forward svc/elasticsearch-master 9200

curl -H "Content-Type: application/json" -X PUT http://localhost:9200/_template/threats -d @libdark/darksearch/es/templates/threats.json
curl -H "Content-Type: application/json" -X PUT http://localhost:9200/_template/traffic -d @libdark/darksearch/es/templates/traffic.json

curl -H "Content-Type: application/json" -X POST http://localhost:9200/_scripts/warm-threat -d @libdark/darksearch/es/scripts/warm-threat.json
curl -H "Content-Type: application/json" -X POST http://localhost:9200/_scripts/threat-seen -d @libdark/darksearch/es/scripts/threat-seen.json

curl -H "Content-Type: application/json" -X PUT http://localhost:9200/threat-score-tracker-for-updating -d @libdark/darksearch/es/mappings/threat-score-tracker-for-updating.json
```

## Pipeline Deployment

```
kubectl --context minikube --namespace default apply -f saasdb.yml
kubectl --context minikube --namespace default apply -f endpoints.yml
kubectl --context minikube --namespace default apply -f coach-whitelister.yml
kubectl --context minikube --namespace default apply -f leadoff-threat.yml
kubectl --context minikube --namespace default apply -f leadoff-threat-cache.yml
kubectl --context minikube --namespace default apply -f leadoff-threat-db.yml
kubectl --context minikube --namespace default apply -f leadoff-threat-doc.yml
kubectl --context minikube --namespace default apply -f leadoff-traffic.yml
kubectl --context minikube --namespace default apply -f leadoff-traffic-filter.yml
kubectl --context minikube --namespace default apply -f leadoff-traffic-cache.yml
kubectl --context minikube --namespace default apply -f leadoff-traffic-db.yml
kubectl --context minikube --namespace default apply -f leadoff-traffic-doc.yml
kubectl --context minikube --namespace default apply -f cleanup-report.yml
kubectl --context minikube --namespace default apply -f cleanup-score.yml
kubectl --context minikube --namespace default apply -f scoreboard.yml
kubectl --context minikube --namespace default apply -f cust-support.yml
kubectl --context minikube --namespace default apply -f mascot.yml

# or... to simplify things, just apply all the configs in this directory
kubectl --context minikube --namespace default apply -f .


```

If we want to deploy the scripts which are generating the reports you will need to:

1. Create a configmap which will hold both scripts `database/etl/saas/reports/scheduler.sh` and `database/etl/saas/reports/processor.sh.`
   Before doing that you will need open the scripts and update the CONN and the PG_URL variables to have proper values.
   Then run the following command to create the configmap

```bash
   kubectl create configmap reports-cronjob-configmap --from-file=path_to_the/processor.sh --from-file=path_to_the/scheduler.sh
```

2. Deploy the cronjobs:

```bash
kubectl --context minikube --namespace default apply -f reports-cronjob.yml
kubectl --context minikube --namespace default apply -f reports-scheduler-cronjob.yml
```

```
helm install kafka bitnami/kafka
helm install redis stable/redis --set cluster.enabled=false,usePassword=false
helm install es elastic/elasticsearch --set "replicas=1,clusterHealthCheckParams=wait_for_status=yellow&timeout=1s"
helm install kibana elastic/kibana --set service.type=LoadBalancer
```

```
kubectl --context minikube --namespace default delete -f default
helm delete kafka redis es kibana

kubectl --context minikube --namespace default delete pvc $(kubectl --context minikube --namespace default get pvc | grep -v NAME | awk '{print $1}')
kubectl --context minikube --namespace default delete pv $(kubectl --context minikube --namespace default get pv | grep -v NAME | awk '{print $1}')
```
