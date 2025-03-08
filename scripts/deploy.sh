#!/bin/bash

# Check if kubectl is installed
if ! command -v kubectl &> /dev/null; then
    echo "kubectl could not be found. Please install kubectl first."
    exit 1
fi

# Set current directory to the script location
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
K8S_DIR="${SCRIPT_DIR}/../k8s-manifests"

echo "Deploying Elastic Stack to Kubernetes cluster..."

# Create the namespace first
echo "Creating namespace..."
kubectl apply -f ${K8S_DIR}/namespace.yaml

# Apply Elasticsearch manifests
echo "Deploying Elasticsearch..."
kubectl apply -f ${K8S_DIR}/elasticsearch.yaml

# Wait for Elasticsearch to be ready
echo "Waiting for Elasticsearch to be ready..."
kubectl wait --namespace=elastic-stack --for=condition=ready pod -l app=elasticsearch --timeout=300s

# Apply Kibana manifests
echo "Deploying Kibana..."
kubectl apply -f ${K8S_DIR}/kibana.yaml

# Apply Filebeat manifests
echo "Deploying Filebeat..."
kubectl apply -f ${K8S_DIR}/filebeat.yaml

# Apply hello-world application
echo "Deploying Hello World application..."
kubectl apply -f ${K8S_DIR}/app.yaml

echo "Checking deployment status..."
kubectl get pods -n elastic-stack

# Get Kibana access information
echo ""
echo "Elastic Stack deployment complete!"

# Check if we're using minikube
if command -v minikube &> /dev/null && minikube status | grep -q "Running"; then
    echo "Detected minikube environment."
    echo "To access Kibana, run: minikube service kibana -n elastic-stack"
else
    # Get service information based on type
    SERVICE_TYPE=$(kubectl get service kibana -n elastic-stack -o jsonpath='{.spec.type}')

    if [ "$SERVICE_TYPE" == "LoadBalancer" ]; then
        echo "Waiting for LoadBalancer IP/hostname..."
        # Wait for the external IP to be assigned (timeout after 60 seconds)
        for i in {1..12}; do
            EXTERNAL_IP=$(kubectl get service kibana -n elastic-stack -o jsonpath='{.status.loadBalancer.ingress[0].ip}')
            if [ -z "$EXTERNAL_IP" ]; then
                EXTERNAL_IP=$(kubectl get service kibana -n elastic-stack -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
            fi

            if [ -n "$EXTERNAL_IP" ]; then
                break
            fi
            echo "Waiting for external IP/hostname... (attempt $i/12)"
            sleep 5
        done

        if [ -n "$EXTERNAL_IP" ]; then
            echo "To access Kibana, use: http://${EXTERNAL_IP}:5601"
        else
            echo "LoadBalancer external IP/hostname wasn't assigned yet."
            echo "Check status with: kubectl get service kibana -n elastic-stack"
        fi
    elif [ "$SERVICE_TYPE" == "NodePort" ]; then
        NODE_PORT=$(kubectl get service kibana -n elastic-stack -o jsonpath='{.spec.ports[0].nodePort}')
        echo "To access Kibana, use: http://<NODE_IP>:${NODE_PORT}"
        echo "If on local machine with direct node access, try: http://localhost:${NODE_PORT}"
    fi

    echo ""
    echo "Alternatively, you can set up port-forwarding with:"
    echo "kubectl port-forward -n elastic-stack \$(kubectl get pods -n elastic-stack -l app=kibana -o jsonpath='{.items[0].metadata.name}') 5601:5601"
    echo "Then access Kibana at: http://localhost:5601"
fi
echo ""
echo "Note: It might take a few minutes for all components to fully initialize."