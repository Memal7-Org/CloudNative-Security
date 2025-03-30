#!/bin/bash

echo "=== Simulating security attacks to test controls ==="

# 1. Try to access storage blob with anonymous access
echo "1. Testing anonymous access to storage blob..."
STORAGE_ACCOUNT=$(terraform -chdir=./01_terraform output -raw storage_account_name)
CONTAINER_NAME=$(terraform -chdir=./01_terraform output -raw storage_container_name)
curl -s "https://${STORAGE_ACCOUNT}.blob.core.windows.net/${CONTAINER_NAME}" > /dev/null
echo "Anonymous blob listing attempted - should be detected by Azure Security Center"

# 2. Try to use container with elevated privileges
echo "2. Testing container with elevated privileges..."
kubectl run privesc-test --image=ubuntu --restart=Never -- sh -c "curl -s -k https://kubernetes.default.svc/api/v1/namespaces/kube-system/secrets"
echo "Privileged container test launched - should be detected by Azure Defender for Kubernetes"

# 3. Try to SSH to MongoDB VM from external IP
echo "3. Testing SSH connection to exposed MongoDB VM..."
MONGODB_IP=$(terraform -chdir=./01_terraform output -raw mongodb_public_ip)
ssh -o StrictHostKeyChecking=no -o ConnectTimeout=5 dbadmin@${MONGODB_IP} "echo Test" || echo "SSH connection attempt made - should be detected in audit logs"

echo "=== Attack simulation complete ==="
echo "Check Azure Security Center and Azure Monitor logs for alerts"