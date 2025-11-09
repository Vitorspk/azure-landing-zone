# NGINX Ingress Controllers - Deployment Guide

Complete guide for deploying and managing NGINX Ingress Controllers on Azure Kubernetes Service (AKS).

---

## Overview

This Azure Landing Zone follows the **same pattern as AWS and GCP** landing zones:

✅ **Separate deployment**: Ingress NGINX is deployed **independently** from infrastructure  
✅ **Dedicated workflows**: GitHub Actions workflows for Ingress management  
✅ **Selective deployment**: Choose which clusters and ingress types to deploy  
✅ **Version controlled**: Manifests versioned and tested (v1.13.3)  

---

## Why Separate Ingress Deployment?

### **Benefits vs. Embedded Deployment:**

| Aspect | Embedded (Old Way) | Separate (Current Way) |
|--------|-------------------|----------------------|
| **Update speed** | ~60 min (full infra) | ~5 min (ingress only) |
| **Risk** | Can break infra | Isolated changes |
| **Flexibility** | All or nothing | Choose clusters/types |
| **Rollback** | Complex | Simple (just ingress) |
| **Testing** | Requires full deploy | Independent testing |

### **Real-World Example:**

```bash
# Scenario: Update Ingress version from 1.13.0 to 1.13.3

# ❌ Old way (embedded):
terraform apply                    # Redeploys ALL infrastructure
# Time: ~60 minutes
# Risk: High (touches everything)

# ✅ New way (separate):
GitHub Actions → deploy-ingress-nginx
  action: apply
# Time: ~5 minutes
# Risk: Low (only Ingress)
```

---

## Deployment Methods

### **Method 1: GitHub Actions (Recommended)**

Best for production and team environments.

#### Deploy to All Clusters

```
Workflow: deploy-ingress-nginx
Inputs:
  clusters: all
  ingress_type: both
  action: apply
  validate: true
```

#### Deploy to Specific Clusters

```
Workflow: deploy-ingress-nginx
Inputs:
  clusters: dev,stg
  ingress_type: external
  action: apply
  validate: true
```

#### Check Status

```
Workflow: deploy-ingress-nginx
Inputs:
  clusters: all
  ingress_type: both
  action: status
  validate: false
```

---

### **Method 2: Helper Script**

Best for local development and testing.

```bash
# Make script executable
chmod +x scripts/deploy-ingress-controllers.sh

# Deploy to specific cluster
./scripts/deploy-ingress-controllers.sh aks-dev rg-network

# The script will:
# ✅ Connect to the cluster
# ✅ Create namespaces
# ✅ Deploy both external and internal ingress
# ✅ Wait for readiness
# ✅ Show LoadBalancer IPs
```

---

### **Method 3: Manual kubectl**

Best for understanding the deployment process.

```bash
# 1. Connect to cluster
az aks get-credentials --resource-group rg-network --name aks-dev

# 2. Deploy external ingress
kubectl apply -f manifests/aks-ingress-nginx-1.13.3-external.yaml

# 3. Deploy internal ingress
kubectl apply -f manifests/aks-ingress-nginx-1.13.3-internal.yaml

# 4. Wait for pods
kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=ingress-nginx-external \
  -n ingress-nginx-external \
  --timeout=300s

kubectl wait --for=condition=ready pod \
  -l app.kubernetes.io/name=ingress-nginx-internal \
  -n ingress-nginx-internal \
  --timeout=300s

# 5. Get LoadBalancer IPs
kubectl get svc -n ingress-nginx-external ingress-nginx-controller
kubectl get svc -n ingress-nginx-internal ingress-nginx-internal-controller
```

---

## Ingress Types

### **External Ingress (Public)**

- **Namespace**: `ingress-nginx-external`
- **IngressClass**: `nginx`
- **LoadBalancer**: Public (internet-facing)
- **Replicas**: 2-5 (auto-scaling with HPA)
- **Use for**: Public websites, APIs, applications

**Features:**
- ✅ Auto-scaling (HPA)
- ✅ Pod Disruption Budget
- ✅ Pod Anti-Affinity
- ✅ Public IP address

**Get External IP:**
```bash
kubectl get svc -n ingress-nginx-external ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

---

### **Internal Ingress (Private)**

- **Namespace**: `ingress-nginx-internal`
- **IngressClass**: `nginx-internal`
- **LoadBalancer**: Internal (VNet only)
- **Replicas**: 1
- **Use for**: Internal tools, admin panels, private APIs

**Features:**
- ✅ VNet-only access
- ✅ No public IP
- ✅ Azure annotation: `azure-load-balancer-internal: "true"`
- ✅ Lower resource usage

**Get Internal IP:**
```bash
kubectl get svc -n ingress-nginx-internal ingress-nginx-internal-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

---

## Workflow Parameters

### **deploy-ingress-nginx.yml**

| Parameter | Options | Description |
|-----------|---------|-------------|
| **clusters** | `all`, `dev`, `stg`, `prd`, `sdx`, combinations | Which clusters to deploy |
| **ingress_type** | `both`, `external`, `internal` | Which ingress controllers |
| **action** | `apply`, `delete`, `status` | What to do |
| **validate** | `true`, `false` | Validate after deployment |

### **destroy-ingress-nginx.yml**

| Parameter | Options | Description |
|-----------|---------|-------------|
| **clusters** | `all`, `dev`, `stg`, `sdx`, combinations | Which clusters to clean |
| **ingress_type** | `both`, `external`, `internal` | Which ingress controllers |
| **confirm** | `yes` | Required confirmation |

---

## Common Scenarios

### **Scenario 1: Initial Setup**

Deploy Ingress to all clusters after infrastructure is ready:

```
1. Deploy infrastructure first:
   Workflow: deploy-infrastructure
   Inputs: module=all, action=apply, clusters=all
   
2. Deploy Ingress:
   Workflow: deploy-ingress-nginx
   Inputs: clusters=all, ingress_type=both, action=apply, validate=true
```

---

### **Scenario 2: Development Testing**

Deploy only to DEV cluster:

```bash
# Option A: GitHub Actions
Workflow: deploy-ingress-nginx
Inputs: clusters=dev, ingress_type=external, action=apply

# Option B: Script
./scripts/deploy-ingress-controllers.sh aks-dev rg-network

# Option C: Manual
az aks get-credentials --resource-group rg-network --name aks-dev
kubectl apply -f manifests/aks-ingress-nginx-1.13.3-external.yaml
```

---

### **Scenario 3: Production Update**

Update only production Ingress:

```
Workflow: deploy-ingress-nginx
Inputs:
  clusters: prd
  ingress_type: both
  action: apply
  validate: true
```

---

### **Scenario 4: Remove from Staging**

```
Workflow: destroy-ingress-nginx
Inputs:
  clusters: stg
  ingress_type: both
  confirm: yes
```

---

## Verification

### **After Deployment:**

```bash
# 1. Check pods
kubectl get pods -n ingress-nginx-external
kubectl get pods -n ingress-nginx-internal

# 2. Check services
kubectl get svc -n ingress-nginx-external
kubectl get svc -n ingress-nginx-internal

# 3. Check IngressClasses
kubectl get ingressclass

# 4. Get IPs
echo "External IP:"
kubectl get svc -n ingress-nginx-external ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'

echo ""
echo "Internal IP:"
kubectl get svc -n ingress-nginx-internal ingress-nginx-internal-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

---

### **Expected Output:**

```bash
# Pods (external)
NAME                                       READY   STATUS    RESTARTS   AGE
ingress-nginx-controller-xxxxxxxxx-xxxxx   1/1     Running   0          2m

# Service (external)
NAME                       TYPE           CLUSTER-IP     EXTERNAL-IP      PORT(S)
ingress-nginx-controller   LoadBalancer   10.0.xxx.xxx   20.201.xxx.xxx   80:30080/TCP,443:30443/TCP

# IngressClasses
NAME             CONTROLLER                     AGE
nginx            k8s.io/ingress-nginx           5m
nginx-internal   k8s.io/ingress-nginx-internal  5m
```

---

## Resources Deployed

### **Per Ingress Controller:**

- 1 Namespace
- 2 ServiceAccounts (controller + admission webhook)
- 2 Roles + 2 ClusterRoles
- 2 RoleBindings + 2 ClusterRoleBindings
- 1 ConfigMap (NGINX configuration)
- 2 Services (LoadBalancer + ClusterIP for webhook)
- 1 Deployment
- 1 PodDisruptionBudget (external only)
- 1 HorizontalPodAutoscaler (external only)
- 2 Jobs (cert-create + cert-patch)
- 1 IngressClass
- 1 ValidatingWebhookConfiguration

**Total:** ~20 Kubernetes resources per controller

---

## Troubleshooting

### **Issue: Pods not starting**

```bash
# Check pod status
kubectl describe pod -n ingress-nginx-external \
  -l app.kubernetes.io/name=ingress-nginx-external

# Check events
kubectl get events -n ingress-nginx-external --sort-by='.lastTimestamp'

# Check logs
kubectl logs -n ingress-nginx-external \
  -l app.kubernetes.io/name=ingress-nginx-external
```

**Common causes:**
- Image pull errors (check network connectivity)
- Resource constraints (check node resources)
- Admission webhook issues (jobs failed)

---

### **Issue: LoadBalancer stuck in "Pending"**

```bash
# Check service
kubectl describe svc -n ingress-nginx-external ingress-nginx-controller

# Check Azure Load Balancer
az network lb list \
  --resource-group MC_rg-network_aks-dev_brazilsouth \
  --output table

# Check service annotations
kubectl get svc -n ingress-nginx-external ingress-nginx-controller -o yaml | grep -A 5 annotations
```

**Common causes:**
- Missing health probe annotation
- Quota limits in Azure subscription
- Network configuration issues

**Fix:**
Ensure health probe annotation is present:
```yaml
annotations:
  service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
```

---

### **Issue: Internal LoadBalancer not working**

Verify the internal annotation:

```bash
kubectl get svc -n ingress-nginx-internal ingress-nginx-internal-controller \
  -o jsonpath='{.metadata.annotations.service\.beta\.kubernetes\.io/azure-load-balancer-internal}'
```

Should return: `true`

If not present:
```bash
kubectl annotate svc ingress-nginx-internal-controller \
  -n ingress-nginx-internal \
  service.beta.kubernetes.io/azure-load-balancer-internal=true \
  --overwrite
```

---

### **Issue: Admission webhook errors**

```bash
# Check webhook jobs
kubectl get jobs -n ingress-nginx-external
kubectl get jobs -n ingress-nginx-internal

# Check secrets created by jobs
kubectl get secret ingress-nginx-external-admission -n ingress-nginx-external
kubectl get secret ingress-nginx-internal-admission -n ingress-nginx-internal

# If jobs failed, check logs
kubectl logs job/ingress-nginx-admission-create -n ingress-nginx-external
kubectl logs job/ingress-nginx-admission-patch -n ingress-nginx-external
```

**Quick fix** (disable webhook validation):
```bash
kubectl delete validatingwebhookconfiguration ingress-nginx-external-admission
kubectl delete validatingwebhookconfiguration ingress-nginx-internal-admission
```

---

## Comparison: AWS vs GCP vs Azure

| Feature | AWS (EKS) | GCP (GKE) | Azure (AKS) |
|---------|-----------|-----------|-------------|
| **Workflow** | Separate ✅ | Embedded | Separate ✅ |
| **LB Type** | NLB | External LB | Azure LB |
| **Internal annotation** | `aws-load-balancer-internal` | `cloud.google.com/load-balancer-type` | `azure-load-balancer-internal` |
| **Health probe** | Automatic | Automatic | **Requires annotation** ⚠️ |
| **IP output** | `.hostname` | `.ip` | `.ip` |
| **Version** | 1.13.3 | 1.13.0 | 1.13.3 |

---

## Best Practices

### **1. Always Validate After Deployment**

```
validate: true  # In GitHub Actions
```

Or manually:
```bash
kubectl get pods -n ingress-nginx-external -w
kubectl get svc -n ingress-nginx-external -w
```

### **2. Deploy in Order**

1. Infrastructure first (`deploy-infrastructure`)
2. Wait for completion (~60 min)
3. Then deploy Ingress (`deploy-ingress-nginx`)
4. Wait for LoadBalancers (~5 min)

### **3. Use Status Action**

Before making changes, check current state:

```
Workflow: deploy-ingress-nginx
Inputs:
  clusters: all
  action: status
```

### **4. Test in DEV First**

```bash
# Test in dev
./scripts/deploy-ingress-controllers.sh aks-dev

# Validate
kubectl get ingress -A

# Then promote to other envs
Workflow: deploy-ingress-nginx → clusters: stg, prd
```

### **5. Monitor LoadBalancer Provisioning**

```bash
# Watch service until EXTERNAL-IP appears
kubectl get svc -n ingress-nginx-external ingress-nginx-controller -w

# Azure LB takes 2-5 minutes typically
```

---

## Advanced Topics

### **Custom Configuration**

Edit ConfigMap to customize NGINX:

```bash
kubectl edit configmap ingress-nginx-controller -n ingress-nginx-external
```

Common customizations:
- `client-max-body-size`: Max upload size
- `proxy-connect-timeout`: Connection timeout
- `worker-processes`: Number of workers
- `max-worker-connections`: Connections per worker

**Note**: Changes require pod restart:
```bash
kubectl rollout restart deployment/ingress-nginx-controller -n ingress-nginx-external
```

---

### **Scaling**

**External Ingress** has HPA configured:
- Min: 2 replicas
- Max: 5 replicas
- Triggers: CPU 70%, Memory 80%

**Manual scaling:**
```bash
# Temporarily override HPA
kubectl scale deployment/ingress-nginx-controller \
  -n ingress-nginx-external \
  --replicas=3

# Or edit HPA
kubectl edit hpa ingress-nginx-controller -n ingress-nginx-external
```

---

### **Multi-Cluster Deployment**

Deploy to multiple clusters sequentially:

```bash
# Via script
for cluster in aks-dev aks-stg aks-prd; do
  echo "Deploying to $cluster..."
  ./scripts/deploy-ingress-controllers.sh $cluster rg-network
done

# Or via GitHub Actions
Workflow: deploy-ingress-nginx
Inputs:
  clusters: dev,stg,prd
  ingress_type: both
  action: apply
```

---

## Cleanup

### **Via GitHub Actions:**

```
Workflow: destroy-ingress-nginx
Inputs:
  clusters: all
  ingress_type: both
  confirm: yes  # REQUIRED
```

### **Via kubectl:**

```bash
# Remove external
kubectl delete -f manifests/aks-ingress-nginx-1.13.3-external.yaml

# Remove internal
kubectl delete -f manifests/aks-ingress-nginx-1.13.3-internal.yaml

# Cleanup stuck resources
kubectl delete namespace ingress-nginx-external --force --grace-period=0
kubectl delete namespace ingress-nginx-internal --force --grace-period=0
```

---

## Migration from Old Manifests

If you have old incomplete manifests deployed:

```bash
# 1. Remove old resources
kubectl delete -f manifests/ingress-nginx-external.yaml --ignore-not-found
kubectl delete -f manifests/ingress-nginx-internal.yaml --ignore-not-found

# 2. Cleanup namespaces
kubectl delete namespace ingress-nginx-external --ignore-not-found
kubectl delete namespace ingress-nginx-internal --ignore-not-found

# 3. Deploy new manifests
kubectl apply -f manifests/aks-ingress-nginx-1.13.3-external.yaml
kubectl apply -f manifests/aks-ingress-nginx-1.13.3-internal.yaml
```

---

## Monitoring

### **Pod Status:**

```bash
# Watch pods
kubectl get pods -n ingress-nginx-external -w
kubectl get pods -n ingress-nginx-internal -w

# Check HPA status (external only)
kubectl get hpa -n ingress-nginx-external
```

### **LoadBalancer Status:**

```bash
# External
kubectl get svc -n ingress-nginx-external ingress-nginx-controller -w

# Internal
kubectl get svc -n ingress-nginx-internal ingress-nginx-internal-controller -w
```

### **Metrics:**

```bash
# Port-forward to metrics endpoint
kubectl port-forward -n ingress-nginx-external \
  deployment/ingress-nginx-controller 10254:10254

# Access metrics
curl http://localhost:10254/metrics
```

---

## Summary

### **✅ What You Get:**

- 🚀 **Fast deployments**: ~5 min vs ~60 min
- 🎯 **Selective**: Choose clusters and types
- 🔒 **Safe**: Isolated from infrastructure changes
- 📊 **Validated**: Automatic validation after deploy
- 🔄 **Easy rollback**: Simple to revert changes
- 📝 **Well documented**: Complete guides and examples
- 🔗 **Consistent**: Same pattern as AWS/GCP landing zones

### **🎯 Recommended Workflow:**

```
1. Deploy Infrastructure
   └─> deploy-infrastructure (clusters=all)
   
2. Deploy Ingress (separate)
   └─> deploy-ingress-nginx (clusters=all, type=both)
   
3. Validate
   └─> deploy-ingress-nginx (action=status)
   
4. Deploy Applications
   └─> kubectl apply -f your-app.yaml
```

---

**Ready to deploy!** 🚀

Choose your method (GitHub Actions, script, or kubectl) and get your Ingress controllers running in minutes!
