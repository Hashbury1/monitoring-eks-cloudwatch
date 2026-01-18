#!/usr/bin/env bash
set -e

NAMESPACE=${NAMESPACE:-default}
SERVICE=demo-app-service

echo "Fetching LoadBalancer endpoint..."
LB=$(kubectl get svc ${SERVICE} -n ${NAMESPACE} -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
echo "LB: $LB"

echo "Generating CPU and latency load..."
ab -n 10000 -c 100 http://${LB}/heavy > /dev/null 2>&1 &
ab -n 3000 -c 50 http://${LB}/error > /dev/null 2>&1 &

echo "Load running for a few minutes... check CloudWatch & Grafana."
sleep 120
echo "Done."
