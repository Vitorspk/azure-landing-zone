# Kubernetes Manifests

Manifestos Kubernetes para os clusters AKS.

## Ingress Controllers

### Deploy Ingress NGINX Externo
```bash
kubectl apply -f ingress-nginx-external.yaml
```

### Deploy Ingress NGINX Interno
```bash
kubectl apply -f ingress-nginx-internal.yaml
```

### Verificar
```bash
kubectl get pods -n ingress-nginx
kubectl get svc -n ingress-nginx
```

## Uso

Após deployar os Ingress Controllers, você pode criar Ingress resources para suas aplicações.
