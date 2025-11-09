# 📦 Kubernetes Manifests

Este diretório contém os manifestos Kubernetes para NGINX Ingress Controllers e exemplos de aplicações para Azure Kubernetes Service (AKS).

---

## 📂 **ESTRUTURA**

```
manifests/
├── aks-ingress-nginx-1.13.3-external.yaml    # NGINX Ingress Controller (público)
├── aks-ingress-nginx-1.13.3-internal.yaml    # NGINX Ingress Controller (privado)
└── README.md                                  # Este arquivo
```

---

## 🚀 **QUICK START**

### **Deployar NGINX Ingress Controllers:**

```bash
# Conectar ao cluster
az aks get-credentials --resource-group rg-network --name aks-dev

# Deploy external ingress (público)
kubectl apply -f manifests/aks-ingress-nginx-1.13.3-external.yaml

# Deploy internal ingress (privado)
kubectl apply -f manifests/aks-ingress-nginx-1.13.3-internal.yaml

# Verificar deployment
kubectl get pods -n ingress-nginx-external
kubectl get pods -n ingress-nginx-internal
```

---

## 📝 **INGRESS CONTROLLERS**

### **External Ingress (Público)**

- **Arquivo**: `aks-ingress-nginx-1.13.3-external.yaml`
- **Namespace**: `ingress-nginx-external`
- **IngressClass**: `nginx`
- **LoadBalancer**: Public Azure Load Balancer
- **Replicas**: 2 (with HPA 2-5)
- **Uso**: Aplicações públicas acessíveis pela internet

**Características:**
- ✅ Public IP automático
- ✅ Auto-scaling (HPA)
- ✅ Pod Disruption Budget
- ✅ Pod Anti-Affinity
- ✅ Health probes Azure-compatible

**Verificar status:**
```bash
kubectl get pods -n ingress-nginx-external
kubectl get svc -n ingress-nginx-external ingress-nginx-controller

# Obter IP público
kubectl get svc -n ingress-nginx-external ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

---

### **Internal Ingress (Privado)**

- **Arquivo**: `aks-ingress-nginx-1.13.3-internal.yaml`
- **Namespace**: `ingress-nginx-internal`
- **IngressClass**: `nginx-internal`
- **LoadBalancer**: Internal Azure Load Balancer (VNet only)
- **Replicas**: 1
- **Uso**: Aplicações internas/privadas

**Características:**
- ✅ Internal IP only (sem acesso público)
- ✅ Annotation: `service.beta.kubernetes.io/azure-load-balancer-internal: "true"`
- ✅ Acessível apenas de dentro da VNet
- ✅ Health probes Azure-compatible

**Verificar status:**
```bash
kubectl get pods -n ingress-nginx-internal
kubectl get svc -n ingress-nginx-internal ingress-nginx-internal-controller

# Obter IP interno
kubectl get svc -n ingress-nginx-internal ingress-nginx-internal-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}'
```

---

## 🎯 **CRIAR SEU PRÓPRIO INGRESS**

### **Template básico (HTTP):**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minha-app
  namespace: default
spec:
  ingressClassName: nginx  # Para público (external)
  # ingressClassName: nginx-internal  # Para privado (internal)
  rules:
  - host: app.meudominio.com  # Opcional: deixe vazio para aceitar qualquer host
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: meu-servico
            port:
              number: 80
```

---

### **Template avançado (com SSL/TLS e annotations):**

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minha-app
  namespace: default
  annotations:
    # NGINX Ingress annotations
    nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
    nginx.ingress.kubernetes.io/ssl-protocols: "TLSv1.2 TLSv1.3"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTP"
    nginx.ingress.kubernetes.io/proxy-body-size: "32m"
    nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
    nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
    
    # Rate limiting (opcional)
    nginx.ingress.kubernetes.io/limit-rps: "100"
    
    # CORS (opcional)
    nginx.ingress.kubernetes.io/enable-cors: "true"
    nginx.ingress.kubernetes.io/cors-allow-origin: "*"
spec:
  ingressClassName: nginx
  rules:
  - host: app.meudominio.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: meu-servico
            port:
              number: 80
      - path: /api
        pathType: Prefix
        backend:
          service:
            name: meu-api-servico
            port:
              number: 8080
  # TLS configuration (optional - for end-to-end encryption)
  tls:
  - hosts:
    - app.meudominio.com
    secretName: meu-tls-secret
```

---

## 🛠️ **UTILITÁRIOS**

### **Verificar IngressClasses disponíveis:**

```bash
kubectl get ingressclass

# Deve mostrar:
# NAME             CONTROLLER                     AGE
# nginx            k8s.io/ingress-nginx           1h
# nginx-internal   k8s.io/ingress-nginx-internal  1h
```

---

### **Listar todos os Ingresses:**

```bash
# Todos os namespaces
kubectl get ingress -A

# Namespace específico
kubectl get ingress -n default
```

---

### **Debugar Ingress:**

```bash
# Ver detalhes
kubectl describe ingress <nome> -n <namespace>

# Ver logs do controller
kubectl logs -n ingress-nginx-external -l app.kubernetes.io/name=ingress-nginx-external --tail=100

# Ver configuração NGINX gerada
kubectl exec -n ingress-nginx-external deployment/ingress-nginx-controller -- cat /etc/nginx/nginx.conf
```

---

## 🔧 **DIFERENÇAS PARA AKS (vs EKS/GKE)**

### **Azure-Specific Annotations:**

```yaml
# Load Balancer Health Probe (obrigatório para AKS)
service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz

# Internal Load Balancer
service.beta.kubernetes.io/azure-load-balancer-internal: "true"

# Subnet específica (opcional)
service.beta.kubernetes.io/azure-load-balancer-internal-subnet: "nome-subnet"
```

### **Principais Diferenças:**

| Recurso | AWS/GKE | AKS | Nota |
|---------|---------|-----|------|
| **Health Probe** | Automático | Requer annotation | Obrigatório no AKS |
| **Internal LB** | Annotation diferente | `azure-load-balancer-internal: "true"` | Azure-specific |
| **NodeSelector** | `agentpool: ng-agent-01` | Node pool name | AKS usa "agentpool" |
| **proxy-real-ip-cidr** | `10.0.0.0/8` | `192.168.0.0/16` | Match VNet CIDR |

---

## 📊 **RECURSOS DEPLOYADOS**

### **Por Ingress Controller:**

| Recurso | External | Internal | Descrição |
|---------|----------|----------|-----------|
| Namespace | ✅ | ✅ | Isolamento |
| ServiceAccount | 2 | 2 | Controller + Admission |
| Role | 2 | 2 | Namespace permissions |
| ClusterRole | 2 | 2 | Cluster permissions |
| RoleBinding | 2 | 2 | Bind roles |
| ClusterRoleBinding | 2 | 2 | Bind cluster roles |
| ConfigMap | 1 | 1 | NGINX config |
| Service | 2 | 2 | LoadBalancer + ClusterIP |
| Deployment | 1 | 1 | Controller pods |
| PodDisruptionBudget | 1 | - | External only |
| HorizontalPodAutoscaler | 1 | - | External only (2-5 pods) |
| Job (create) | 1 | 1 | Webhook cert creation |
| Job (patch) | 1 | 1 | Webhook cert patch |
| IngressClass | 1 | 1 | nginx / nginx-internal |
| ValidatingWebhook | 1 | 1 | Admission validation |

---

## 🔐 **CONFIGURAR TLS/SSL**

### **Opção 1: Cert-Manager (Recomendado)**

Instalar cert-manager para gerenciar certificados automaticamente:

```bash
# Install cert-manager
kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.13.0/cert-manager.yaml

# Create ClusterIssuer for Let's Encrypt
kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: letsencrypt-prod
spec:
  acme:
    server: https://acme-v02.api.letsencrypt.org/directory
    email: seu-email@example.com
    privateKeySecretRef:
      name: letsencrypt-prod
    solvers:
    - http01:
        ingress:
          class: nginx
EOF
```

**Usar no Ingress:**
```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: minha-app
  annotations:
    cert-manager.io/cluster-issuer: "letsencrypt-prod"
spec:
  ingressClassName: nginx
  tls:
  - hosts:
    - app.meudominio.com
    secretName: app-tls-cert  # Cert-manager criará automaticamente
  rules:
  - host: app.meudominio.com
    # ...
```

---

### **Opção 2: Certificado Manual**

```bash
# Criar TLS secret
kubectl create secret tls meu-tls-secret \
  --cert=caminho/para/cert.crt \
  --key=caminho/para/cert.key \
  -n default

# Usar no Ingress (veja template acima)
```

---

## 🧪 **TESTAR CONECTIVIDADE**

### **Teste básico HTTP:**

```bash
# Obter IP do LoadBalancer
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx-external ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "External IP: $EXTERNAL_IP"

# Testar HTTP
curl -v http://$EXTERNAL_IP

# Testar com hostname
curl -H "Host: app.meudominio.com" http://$EXTERNAL_IP
```

---

### **Teste interno:**

```bash
# Obter IP interno
INTERNAL_IP=$(kubectl get svc -n ingress-nginx-internal ingress-nginx-internal-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Internal IP: $INTERNAL_IP"

# Deploy pod de teste para acessar de dentro da VNet
kubectl run curl-test --image=curlimages/curl:latest -it --rm -- sh

# Dentro do pod:
curl http://$INTERNAL_IP
```

---

## 📈 **MONITORAMENTO**

### **Métricas Prometheus:**

```bash
# Port-forward para Prometheus metrics
kubectl port-forward -n ingress-nginx-external \
  deployment/ingress-nginx-controller 10254:10254

# Acessar métricas
curl http://localhost:10254/metrics
```

---

### **Logs estruturados (JSON):**

```bash
# Ver logs em formato JSON
kubectl logs -n ingress-nginx-external \
  -l app.kubernetes.io/name=ingress-nginx-external \
  --tail=20 | jq '.'
```

---

## 🔄 **ATUALIZAÇÃO**

### **Update Ingress Controller:**

```bash
# Baixar nova versão do manifesto
# Editar para versão desejada
# Aplicar
kubectl apply -f manifests/aks-ingress-nginx-1.13.3-external.yaml

# Verificar rollout
kubectl rollout status deployment/ingress-nginx-controller -n ingress-nginx-external
```

---

## 🗑️ **REMOVER**

```bash
# Remover external ingress
kubectl delete -f manifests/aks-ingress-nginx-1.13.3-external.yaml

# Remover internal ingress
kubectl delete -f manifests/aks-ingress-nginx-1.13.3-internal.yaml

# Verificar remoção
kubectl get ns | grep ingress-nginx
```

---

## 📚 **DOCUMENTAÇÃO ADICIONAL**

- **NGINX Ingress Docs**: https://kubernetes.github.io/ingress-nginx/
- **Azure Load Balancer Annotations**: https://learn.microsoft.com/en-us/azure/aks/load-balancer-standard
- **AKS Ingress Best Practices**: https://learn.microsoft.com/en-us/azure/aks/ingress-basic

---

## 🔧 **TROUBLESHOOTING**

### **Ingress não roteia tráfego:**

```bash
# 1. Verificar IngressClass
kubectl get ingress <nome> -n <namespace> -o yaml | grep ingressClassName

# 2. Verificar backend service existe
kubectl get svc -n <namespace>

# 3. Verificar endpoints
kubectl get endpoints -n <namespace> <service-name>

# 4. Ver logs do controller
kubectl logs -n ingress-nginx-external -l app.kubernetes.io/name=ingress-nginx-external
```

---

### **LoadBalancer não provisiona:**

```bash
# Ver eventos do service
kubectl describe svc -n ingress-nginx-external ingress-nginx-controller | tail -50

# Verificar annotations Azure
kubectl get svc -n ingress-nginx-external ingress-nginx-controller -o yaml | grep -A 10 annotations

# Verificar se Azure Load Balancer foi criado
az network lb list --resource-group MC_rg-network_aks-dev_brazilsouth --output table
```

---

### **Pods não iniciam:**

```bash
# Ver eventos dos pods
kubectl describe pod -n ingress-nginx-external -l app.kubernetes.io/name=ingress-nginx-external

# Ver logs
kubectl logs -n ingress-nginx-external -l app.kubernetes.io/name=ingress-nginx-external

# Verificar recursos
kubectl top pods -n ingress-nginx-external
```

---

### **Health probe falhando:**

Verifique se a annotation está correta:
```yaml
service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
```

O controller NGINX expõe `/healthz` na porta 10256 por padrão.

---

## ⚠️ **NOTAS IMPORTANTES AKS**

### **1. Azure Load Balancer Annotations**

**Obrigatório para AKS:**
```yaml
service.beta.kubernetes.io/azure-load-balancer-health-probe-request-path: /healthz
```

**Para LoadBalancer interno:**
```yaml
service.beta.kubernetes.io/azure-load-balancer-internal: "true"
```

### **2. Node Selector**

AKS usa `agentpool` como label padrão (não `nodepool` como em alguns clusters):
```yaml
nodeSelector:
  kubernetes.io/os: linux
```

Se quiser especificar pool específico:
```yaml
nodeSelector:
  agentpool: system  # ou ng-general-01, etc
  kubernetes.io/os: linux
```

### **3. ConfigMap - proxy-real-ip-cidr**

**Importante**: Deve match seu VNet CIDR:
```yaml
proxy-real-ip-cidr: "192.168.0.0/16"  # Match Azure VNet
```

### **4. LoadBalancer Provisioning Time**

Azure Load Balancer leva **2-5 minutos** para provisionar. Seja paciente! ⏱️

```bash
# Monitorar provisioning
kubectl get svc -n ingress-nginx-external ingress-nginx-controller -w
```

### **5. External Traffic Policy**

Usamos `externalTrafficPolicy: Local` para:
- ✅ Preservar source IP do cliente
- ✅ Evitar double-hop (melhor performance)
- ⚠️ Requer que pods estejam distribuídos nos nodes com LB

---

## 🌐 **CONFIGURAR DNS**

Após o LoadBalancer provisionar:

```bash
# 1. Obter IP público
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx-external ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

echo "Configure DNS A record:"
echo "app.seudominio.com → $EXTERNAL_IP"

# 2. Testar (após DNS propagar)
curl http://app.seudominio.com
```

---

## 📊 **COMPARAÇÃO: EXTERNAL vs INTERNAL**

| Característica | External | Internal | Notas |
|----------------|----------|----------|-------|
| **Acesso** | Internet | VNet only | Internal não tem IP público |
| **Replicas** | 2-5 (HPA) | 1 | External tem auto-scaling |
| **Anti-Affinity** | ✅ Yes | - | External distribui em nodes |
| **PDB** | ✅ Yes | - | External tem alta disponibilidade |
| **Annotation** | - | `azure-load-balancer-internal: "true"` | Define LB interno |
| **Use Case** | Apps públicas | APIs internas | - |

---

## 🚦 **EXEMPLO COMPLETO DE DEPLOYMENT**

```yaml
---
apiVersion: v1
kind: Namespace
metadata:
  name: nginx-example
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: nginx-app
  namespace: nginx-example
spec:
  replicas: 3
  selector:
    matchLabels:
      app: nginx
  template:
    metadata:
      labels:
        app: nginx
    spec:
      containers:
      - name: nginx
        image: nginx:1.25-alpine
        ports:
        - containerPort: 80
        resources:
          requests:
            cpu: 100m
            memory: 128Mi
          limits:
            cpu: 200m
            memory: 256Mi
        livenessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 10
        readinessProbe:
          httpGet:
            path: /
            port: 80
          initialDelaySeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: nginx-service
  namespace: nginx-example
spec:
  type: ClusterIP
  selector:
    app: nginx
  ports:
  - port: 80
    targetPort: 80
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx-ingress
  namespace: nginx-example
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /
spec:
  ingressClassName: nginx  # Público
  rules:
  - host: nginx.example.com
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx-service
            port:
              number: 80
```

**Deploy e teste:**
```bash
kubectl apply -f nginx-example.yaml

# Obter IP
EXTERNAL_IP=$(kubectl get svc -n ingress-nginx-external ingress-nginx-controller \
  -o jsonpath='{.status.loadBalancer.ingress[0].ip}')

# Testar
curl -H "Host: nginx.example.com" http://$EXTERNAL_IP
```

---

## 🎓 **BOAS PRÁTICAS**

### **1. Use namespaces dedicados**
Não deploy aplicações em `default` ou nos namespaces do ingress.

### **2. Configure resource limits**
Sempre defina `requests` e `limits` para CPU/memória.

### **3. Use TLS/SSL em produção**
Configure certificados para ambientes de produção.

### **4. Monitore seu Ingress**
Use as métricas Prometheus expostas na porta 10254.

### **5. Configure PodDisruptionBudget**
Para aplicações críticas, sempre use PDB.

### **6. Use annotation de health probe**
Obrigatório para AKS funcionar corretamente.

---

## 📖 **REFERÊNCIAS**

- **NGINX Ingress Official**: https://kubernetes.github.io/ingress-nginx/
- **AKS Load Balancer**: https://learn.microsoft.com/en-us/azure/aks/load-balancer-standard
- **AKS Ingress**: https://learn.microsoft.com/en-us/azure/aks/ingress-basic
- **Cert-Manager**: https://cert-manager.io/docs/

---

**Versão**: 1.13.3  
**Última atualização**: 09/11/2025  
**Testado em**: AKS 1.31
