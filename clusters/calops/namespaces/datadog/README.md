# Datadog Agent

`helm --namespace datadog upgrade --install datadog -f datadog-values.yaml --set datadog.site='datadoghq.com' --set datadog.apiKey=74323f03c2ddfcfd5aa33868c519b926 --set datadog.appKey=746a4b6c2051ced6d13c91e8f4486c45e997c31d datadog/datadog`
