#!/bin/bash

# ==============================================================================
# DEPLOY NGINX INGRESS CONTROLLERS TO AKS CLUSTER
# ==============================================================================

# Remove set -e to allow controlled error handling
set -o pipefail

CLUSTER_NAME=${1:-"aks-dev"}
RESOURCE_GROUP=${2:-"rg-network"}

# Find the repository root (where manifests directory is located)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REPO_ROOT="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=========================================="
echo "Deploying NGINX Ingress Controllers"
echo "=========================================="
echo "Cluster: $CLUSTER_NAME"
echo "Resource Group: $RESOURCE_GROUP"
echo "Repository root: $REPO_ROOT"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Exit codes
EXIT_SUCCESS=0
EXIT_TIMEOUT=100  # Non-critical timeout
EXIT_CRITICAL=1   # Critical failure

# Helper function for critical errors
fail_critical() {
    echo -e "${RED}❌ CRITICAL ERROR: $1${NC}"
    exit $EXIT_CRITICAL
}

# Helper function for timeout warnings
warn_timeout() {
    echo -e "${YELLOW}⚠️  TIMEOUT WARNING: $1${NC}"
    echo -e "${YELLOW}NGINX deployment was initiated but did not complete in time.${NC}"
    echo -e "${YELLOW}The deployment will continue in the background.${NC}"
    exit $EXIT_TIMEOUT
}

# Get kubeconfig
echo "1. Getting cluster credentials..."
if ! az aks get-credentials --name "$CLUSTER_NAME" --resource-group "$RESOURCE_GROUP" --overwrite-existing; then
    fail_critical "Failed to get credentials. Cluster may not exist or you don't have access."
fi

# Verify kubectl works
if ! kubectl cluster-info &>/dev/null; then
    fail_critical "Cannot connect to cluster. Check cluster status and credentials."
fi

# Wait for cluster to be ready
echo "2. Waiting for cluster to be ready..."
if ! kubectl wait --for=condition=Ready nodes --all --timeout=300s; then
    fail_critical "Cluster nodes are not ready. Check cluster and node pool status."
fi

# Verify network connectivity to external registries
echo "2.5. Verifying network connectivity to external registries..."
MAX_RETRIES=12
RETRY_DELAY=10
CONNECTIVITY_OK=false

for i in $(seq 1 $MAX_RETRIES); do
    echo "    Attempt $i/$MAX_RETRIES: Testing connectivity to registry.k8s.io..."

    # Create a temporary pod to test connectivity
    cat <<EOF | kubectl apply -f - >/dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: connectivity-test
  namespace: default
spec:
  restartPolicy: Never
  containers:
  - name: test
    image: busybox:1.36
    command: ['sh', '-c', 'nslookup registry.k8s.io | grep -A 1 "Name:" | grep -q "Address:"']
EOF

    # Wait for pod to complete
    sleep 5

    # Check if connectivity test succeeded by waiting for the pod to enter the 'Succeeded' phase
    if kubectl wait pod/connectivity-test --for=jsonpath='{.status.phase}'=Succeeded -n default --timeout=30s >/dev/null 2>&1; then
        echo -e "${GREEN}    ✓ DNS resolution working for registry.k8s.io${NC}"
        CONNECTIVITY_OK=true
        kubectl delete pod connectivity-test -n default --ignore-not-found=true >/dev/null 2>&1
        break
    fi

    # Clean up failed pod
    kubectl delete pod connectivity-test -n default --ignore-not-found=true >/dev/null 2>&1

    if [ $i -lt $MAX_RETRIES ]; then
        echo "    Network not ready yet, waiting ${RETRY_DELAY}s before retry..."
        sleep $RETRY_DELAY
    fi
done

if [ "$CONNECTIVITY_OK" = false ]; then
    echo -e "${YELLOW}⚠️  WARNING: Could not verify connectivity to registry.k8s.io${NC}"
    echo -e "${YELLOW}    Proceeding anyway, but image pulls may fail.${NC}"
    echo -e "${YELLOW}    If deployment fails, wait a few minutes for networking to stabilize and retry.${NC}"
fi

# Create namespaces
echo "3. Creating namespaces..."
if ! kubectl create namespace ingress-nginx-external --dry-run=client -o yaml | kubectl apply -f -; then
    fail_critical "Failed to create ingress-nginx-external namespace."
fi

if ! kubectl create namespace ingress-nginx-internal --dry-run=client -o yaml | kubectl apply -f -; then
    fail_critical "Failed to create ingress-nginx-internal namespace."
fi

# Cleanup existing jobs to avoid AlreadyExists errors
echo "3.5. Cleaning up existing admission jobs..."
kubectl delete job ingress-nginx-admission-create ingress-nginx-admission-patch -n ingress-nginx-external --ignore-not-found=true 2>/dev/null || true
kubectl delete job ingress-nginx-internal-admission-create ingress-nginx-internal-admission-patch -n ingress-nginx-internal --ignore-not-found=true 2>/dev/null || true

# Cleanup old IngressClasses to avoid immutable field errors
echo "3.6. Cleaning up old IngressClasses..."
kubectl delete ingressclass nginx --ignore-not-found 2>/dev/null || true
kubectl delete ingressclass nginx-internal --ignore-not-found 2>/dev/null || true
kubectl delete ingressclass nginx-external --ignore-not-found 2>/dev/null || true
echo -e "${GREEN}✓ Old IngressClasses cleaned up${NC}"

# Deploy external ingress
echo "4. Deploying external NGINX Ingress Controller..."
if [ ! -f "$REPO_ROOT/manifests/aks-ingress-nginx-1.13.3-external.yaml" ]; then
    fail_critical "Manifest file not found: $REPO_ROOT/manifests/aks-ingress-nginx-1.13.3-external.yaml"
fi

if ! kubectl apply -f "$REPO_ROOT/manifests/aks-ingress-nginx-1.13.3-external.yaml"; then
    fail_critical "Failed to apply external NGINX manifest."
fi

# Disable webhook validation to avoid certificate issues
echo "4.1. Disabling webhook validation for external ingress..."
kubectl delete validatingwebhookconfiguration ingress-nginx-external-admission --ignore-not-found 2>/dev/null || true
echo -e "${GREEN}✓ Webhook validation disabled for external ingress${NC}"

# Deploy internal ingress
echo "5. Deploying internal NGINX Ingress Controller..."
if [ ! -f "$REPO_ROOT/manifests/aks-ingress-nginx-1.13.3-internal.yaml" ]; then
    fail_critical "Manifest file not found: $REPO_ROOT/manifests/aks-ingress-nginx-1.13.3-internal.yaml"
fi

if ! kubectl apply -f "$REPO_ROOT/manifests/aks-ingress-nginx-1.13.3-internal.yaml"; then
    fail_critical "Failed to apply internal NGINX manifest."
fi

# Disable webhook validation to avoid certificate issues
echo "5.1. Disabling webhook validation for internal ingress..."
kubectl delete validatingwebhookconfiguration ingress-nginx-internal-admission --ignore-not-found 2>/dev/null || true
echo -e "${GREEN}✓ Webhook validation disabled for internal ingress${NC}"

# CRITICAL: Wait for admission webhook jobs to complete BEFORE waiting for deployments
echo "5.2. Waiting for admission webhook jobs to complete..."

# Helper function to wait for a Kubernetes job to complete and fail if it doesn't.
# Arguments:
#   $1: Job name
#   $2: Namespace
#   $3: Timeout (e.g., "300s")
#   $4: Ingress type for error message (e.g., "external")
wait_for_job() {
    local job_name="$1"
    local namespace="$2"
    local timeout="$3"
    local ingress_type="$4"

    echo "--> Waiting for job '$job_name' in namespace '$namespace' (timeout: $timeout)..."

    # Convert timeout string (e.g., "600s") to seconds
    local timeout_seconds="${timeout%s}"
    local start_time=$(date +%s)
    local job_found=false
    local job_completed=false

    # First, wait for the job to exist (handle race condition after kubectl apply)
    local max_retries=30
    local retry=0
    while [ $retry -lt $max_retries ]; do
        if kubectl get "job/$job_name" -n "$namespace" &>/dev/null; then
            echo "    Job '$job_name' found, waiting for completion..."
            job_found=true
            break
        fi
        retry=$((retry + 1))
        if [ $retry -eq $max_retries ]; then
            echo -e "${YELLOW}Warning: Job '$job_name' not found after ${max_retries} seconds.${NC}"
            echo "    This could mean the job completed and was cleaned up (ttlSecondsAfterFinished=0)."
            echo "    Checking for pods with job label..."
            break
        fi
        sleep 1
    done

    # Check if job completed by looking at pods (handles ttlSecondsAfterFinished=0 case)
    local pod_name=$(kubectl get pods -n "$namespace" -l "job-name=$job_name" --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}' 2>/dev/null || echo "")

    if [ -n "$pod_name" ]; then
        echo "    Found pod '$pod_name' for job '$job_name', checking status..."

        # Wait for pod to reach a terminal state (Succeeded or Failed)
        while true; do
            local current_time=$(date +%s)
            local elapsed=$((current_time - start_time))

            if [ $elapsed -gt $timeout_seconds ]; then
                echo -e "${RED}Error: Job '$job_name' did not complete within $timeout.${NC}"
                echo ""
                echo "=== Pod Status ==="
                kubectl get pod "$pod_name" -n "$namespace" -o wide || true
                echo ""
                echo "=== Pod Events ==="
                kubectl describe pod "$pod_name" -n "$namespace" | grep -A 20 "Events:" || true
                echo ""
                echo "=== Pod Logs ==="
                kubectl logs "$pod_name" -n "$namespace" --tail=50 || echo "No logs available"
                fail_critical "Admission webhook job '$job_name' timed out for $ingress_type ingress."
            fi

            local pod_phase=$(kubectl get pod "$pod_name" -n "$namespace" -o jsonpath='{.status.phase}' 2>/dev/null || echo "")

            if [ "$pod_phase" = "Succeeded" ]; then
                echo -e "${GREEN}    ✓ Job '$job_name' completed successfully${NC}"
                job_completed=true
                break
            elif [ "$pod_phase" = "Failed" ]; then
                echo -e "${RED}Error: Job '$job_name' failed.${NC}"
                echo ""
                echo "=== Pod Status ==="
                kubectl get pod "$pod_name" -n "$namespace" -o wide || true
                echo ""
                echo "=== Pod Events ==="
                kubectl describe pod "$pod_name" -n "$namespace" | grep -A 20 "Events:" || true
                echo ""
                echo "=== Pod Logs ==="
                kubectl logs "$pod_name" -n "$namespace" --tail=50 || echo "No logs available"
                fail_critical "Admission webhook job '$job_name' failed for $ingress_type ingress."
            elif [ "$pod_phase" = "Pending" ] || [ "$pod_phase" = "Running" ]; then
                # Still in progress
                sleep 2
            else
                echo -e "${YELLOW}Warning: Unexpected pod phase '$pod_phase' for pod '$pod_name'${NC}"
                sleep 2
            fi
        done
    elif [ "$job_found" = true ]; then
        # Job exists, use kubectl wait
        if ! kubectl wait --for=condition=complete --timeout="$timeout" \
          "job/$job_name" -n "$namespace" 2>/dev/null; then
            echo -e "${RED}Error: Job '$job_name' did not complete within $timeout.${NC}"
            echo ""
            echo "=== Job Details ==="
            kubectl describe "job/$job_name" -n "$namespace" || true
            echo ""
            echo "=== Pod Status ==="
            pod_name=$(kubectl get pods -n "$namespace" -l "job-name=$job_name" --sort-by=.metadata.creationTimestamp -o jsonpath='{.items[-1:].metadata.name}' 2>/dev/null || echo "")
            if [ -n "$pod_name" ]; then
                echo "Pod: $pod_name"
                kubectl get pod "$pod_name" -n "$namespace" -o wide || true
                echo ""
                echo "=== Pod Events ==="
                kubectl describe pod "$pod_name" -n "$namespace" | grep -A 20 "Events:" || true
                echo ""
                echo "=== Pod Logs ==="
                kubectl logs "$pod_name" -n "$namespace" --tail=50 || echo "No logs available"
            else
                echo "No pod found for job '$job_name'"
            fi
            fail_critical "Admission webhook job '$job_name' failed for $ingress_type ingress."
        fi
        job_completed=true
    else
        # Neither job nor pod found
        echo -e "${RED}Error: Neither job nor pod found for '$job_name'.${NC}"
        echo "Checking all jobs in namespace '$namespace':"
        kubectl get jobs -n "$namespace" || true
        echo ""
        echo "Checking all pods in namespace '$namespace':"
        kubectl get pods -n "$namespace" || true
        fail_critical "Admission webhook job '$job_name' was not created for $ingress_type ingress."
    fi
}

# Helper function to verify a Kubernetes secret exists.
# Arguments:
#   $1: Secret name
#   $2: Namespace
#   $3: Ingress type for error message (e.g., "external")
verify_secret_exists() {
    local secret_name="$1"
    local namespace="$2"
    local ingress_type="$3"
    if ! kubectl get secret "$secret_name" -n "$namespace" &>/dev/null; then
        echo -e "${RED}ERROR: Secret '$secret_name' was not created!${NC}"
        kubectl get secrets -n "$namespace"
        fail_critical "Admission webhook secret not created for $ingress_type ingress"
    fi
}

echo "5.2.1. Waiting for external admission jobs (extended timeout for image pull)..."
wait_for_job "ingress-nginx-admission-create" "ingress-nginx-external" "600s" "external"
wait_for_job "ingress-nginx-admission-patch" "ingress-nginx-external" "60s" "external"

echo "5.2.2. Waiting for internal admission jobs (extended timeout for image pull)..."
wait_for_job "ingress-nginx-internal-admission-create" "ingress-nginx-internal" "600s" "internal"
wait_for_job "ingress-nginx-internal-admission-patch" "ingress-nginx-internal" "60s" "internal"

echo "5.2.3. Verifying admission secrets were created..."
verify_secret_exists "ingress-nginx-external-admission" "ingress-nginx-external" "external"
verify_secret_exists "ingress-nginx-internal-admission" "ingress-nginx-internal" "internal"

echo -e "${GREEN}✓ Admission secrets created successfully${NC}"

# Wait for deployments
echo "6. Waiting for deployments to be ready (timeout: 10 minutes)..."

# Check pods status first
echo "6.1. Checking external ingress pods..."
kubectl get pods -n ingress-nginx-external

echo "6.2. Checking internal ingress pods..."
kubectl get pods -n ingress-nginx-internal

# Wait for deployments with increased timeout
echo "6.3. Waiting for external ingress deployment..."
if ! kubectl wait --for=condition=available --timeout=600s \
  deployment/ingress-nginx-controller -n ingress-nginx-external; then
    echo -e "${YELLOW}⚠️  External ingress deployment timed out after 10 minutes.${NC}"
    echo "Checking deployment status..."
    kubectl get pods -n ingress-nginx-external
    kubectl describe deployment ingress-nginx-controller -n ingress-nginx-external | tail -30
    warn_timeout "External NGINX Ingress deployment timeout (non-critical)"
fi

echo "6.4. Waiting for internal ingress deployment..."
if ! kubectl wait --for=condition=available --timeout=600s \
  deployment/ingress-nginx-internal-controller -n ingress-nginx-internal; then
    echo -e "${YELLOW}⚠️  Internal ingress deployment timed out after 10 minutes.${NC}"
    echo "Checking deployment status..."
    kubectl get pods -n ingress-nginx-internal
    kubectl describe deployment ingress-nginx-internal-controller -n ingress-nginx-internal | tail -30
    warn_timeout "Internal NGINX Ingress deployment timeout (non-critical)"
fi

# Get LoadBalancer IPs
echo ""
echo "=========================================="
echo -e "${GREEN}✓ NGINX Ingress Controllers deployed!${NC}"
echo "=========================================="
echo ""
echo "External LoadBalancer:"
kubectl get svc ingress-nginx-controller -n ingress-nginx-external

echo ""
echo "Internal LoadBalancer:"
kubectl get svc ingress-nginx-internal-controller -n ingress-nginx-internal

echo ""
echo "To get LoadBalancer IPs:"
echo "  External: kubectl get svc ingress-nginx-controller -n ingress-nginx-external -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
echo "  Internal: kubectl get svc ingress-nginx-internal-controller -n ingress-nginx-internal -o jsonpath='{.status.loadBalancer.ingress[0].ip}'"
echo ""
echo "Next steps:"
echo "  1. Wait for Azure Load Balancers to provision (2-5 minutes)"
echo "  2. Configure DNS A records to point to the external IP"
echo "  3. Test: curl -H 'Host: your-domain.com' http://<EXTERNAL_IP>"
echo ""
