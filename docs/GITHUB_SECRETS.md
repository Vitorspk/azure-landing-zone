# Configuração de Secrets no GitHub

## Secrets Necessários

Configure os seguintes secrets no GitHub para os workflows funcionarem:

### 1. AZURE_CLIENT_ID
Client ID do Service Principal

### 2. AZURE_CLIENT_SECRET
Client Secret do Service Principal

### 3. AZURE_SUBSCRIPTION_ID
ID da Subscription Azure
```bash
az account show --query id -o tsv
```

### 4. AZURE_TENANT_ID
ID do Tenant Azure
```bash
az account show --query tenantId -o tsv
```

## Como Adicionar

1. Vá em Settings > Secrets and variables > Actions
2. Clique em "New repository secret"
3. Adicione cada secret

## Via CLI

```bash
gh secret set AZURE_CLIENT_ID --body "<valor>"
gh secret set AZURE_CLIENT_SECRET --body "<valor>"
gh secret set AZURE_SUBSCRIPTION_ID --body "<valor>"
gh secret set AZURE_TENANT_ID --body "<valor>"
```

## Segurança

- Nunca commit secrets no código
- Use .gitignore
- Rotacione secrets regularmente
