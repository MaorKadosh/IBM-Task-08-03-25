#!/bin/bash

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl could not be found. Please install kubectl first."
    exit 1
fi

# Set current directory to the script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
K8S_DIR="${SCRIPT_DIR}/../k8s-manifests"

echo "Cleaning up Elastic Stack from Kubernetes cluster..."

# Delete everything in reverse order
echo "Deleting Hello World application..."
kubectl delete -f ${K8S_DIR}/app.yaml --ignore-not-found

echo "Deleting Filebeat..."
kubectl delete -f ${K8S_DIR}/filebeat.yaml --ignore-not-found

echo "Deleting Kibana..."
kubectl delete -f ${K8S_DIR}/kibana.yaml --ignore-not-found

echo "Deleting Elasticsearch..."
kubectl delete -f ${K8S_DIR}/elasticsearch.yaml --ignore-not-found

echo "Deleting namespace (this will delete all remaining resources in the namespace)..."
kubectl delete -f ${K8S_DIR}/namespace.yaml --ignore-not-found

echo "Elastic Stack cleanup complete!"