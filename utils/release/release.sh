#!/bin/zsh

echo ""
echo "This script assumes you can use a cannon for a version release "
echo "Open another terminal tab so you can watch the pods "
echo ""

read "ns?Namespace : "
read "no?Nodename  : "
read "work?Workers   : "

kubectl config use-context appliances

read "bat?Is this a cloud collector? (yes/NO): "
bat=${bat:-"n"}

if [[ $bat =~ ^([yY][eE][sS]|[yY])$ ]]; then
  echo "Scaling down the batboy sensor deployment in appliances cluster "
  kubectl -n $ns scale deploy $no-sensor-batboy --replicas=0
  read -s -k '?Press any key when you are ready to edit the deployment  '
  kubectl -n $ns edit deploy $no-sensor-batboy
  read -s -k '?Press any key when you are ready to scale up the deployment : '
  kubectl -n $ns scale deploy $no-sensor-batboy --replicas=1
  echo "Goodbye "
fi

read "cal?Do you need to edit calops deployments (yes/NO): "
cal=${cal:-"n"}

if [[ $cal =~ ^([yY][eE][sS]|[yY])$ ]]; then
  kubectl config use-context calops
  echo "Scaling down the appliance deployments in the calops cluster "
  kubectl -n $ns scale deploy {$no-main,$no-sensor,$no-ui,$no-uidb,$no-workers} --replicas=0
  echo "Grabbing the workers deployment "
  kubectl -n $ns get deploy $no-workers -o yaml > $no-workers.yml
  read -s -k '?Press any key when you are ready to edit the other deployments  '
  kubectl -n $ns edit deploy {$no-main,$no-sensor,$no-ui,$no-uidb}
  read -s -k '?Press any key when you are ready to edit the worker deployment  '
  bbedit --new-window $no-workers.yml
  read -s -k '?Press any key when you are ready to proceed  '
  echo "Removing the workers deployment "
  kubectl -n $ns delete deploy $no-workers
  conduit inject $no-workers.yml | kubectl apply -f -
  mv $no-workers.yml ~/Documents/D3/archive/v24.0.release/
  read -s -k '?Press any key when you are ready to scale up the uidb deployment    : '
  kubectl -n $ns scale deploy $no-uidb --replicas=1
  read -s -k '?Press any key when you are ready to scale up the main deployment    : '
  kubectl -n $ns scale deploy $no-main --replicas=1
  read -s -k '?Press any key when you are ready to scale up the ui deployment      : '
  kubectl -n $ns scale deploy $no-ui --replicas=1
  read -s -k '?Press any key when you are ready to scale up the workers deployment : '
  kubectl -n $ns scale deploy $no-workers --replicas=$work
  read -s -k '?Press any key when you are ready to scale up the sensor deployment  : '
  kubectl -n $ns scale deploy $no-sensor --replicas=1
  echo "Goodbye "
else
  echo "Scaling down the deployments in appliances cluster "
  kubectl -n $ns scale deploy {$no,$no-sensor,$no-workers} --replicas=0
  read -s -k '?Press any key when you are ready to edit the deployments  '
  kubectl -n $ns edit deploy {$no,$no-workers,$no-sensor}
  read -s -k '?Press any key when you are ready to scale up the main deployment    : '
  kubectl -n $ns scale deploy $no --replicas=1
  read -s -k '?Press any key when you are ready to scale up the workers deployment : '
  kubectl -n $ns scale deploy $no-workers --replicas=$work
  read -s -k '?Press any key when you are ready to scale up the sensor deployment  : '
  kubectl -n $ns scale deploy $no-sensor --replicas=1
  echo "Goodbye "
fi
