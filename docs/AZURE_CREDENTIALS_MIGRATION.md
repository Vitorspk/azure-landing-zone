# Migração de Credenciais Azure

## 📋 Resumo das Mudanças

Este documento descreve as mudanças realizadas para simplificar o gerenciamento de credenciais Azure no projeto, removendo a necessidade de passar `subscription_id` como variável Terraform e utilizando as variáveis de ambiente do GitHub Actions.

## ✅ O Que Foi Alterado

### 1. Remoção da Variável `subscription_id`

**Arquivos modificados:**
- `terraform/00-iam/variables.tf`
- `terraform/01-networking/variables.tf`
- `terraform/02-kubernetes/variables.tf`

**Mudança:**
```hcl
# ANTES
variable "subscription_id" {
  description = "Azure Subscription ID"
  type        = string
}

# DEPOIS
# Variável removida - subscription_id agora vem de ARM_SUBSCRIPTION_ID
```

### 2. Atualização dos Providers

**Arquivos modificados:**
- `terraform/00-iam/main.tf`
- `terraform/01-networking/main.tf`
- `terraform/02-kubernetes/main.tf`

**Mudança:**
```hcl
# ANTES
provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
}

# DEPOIS
provider "azurerm" {
  features {}
  # subscription_id will be read from ARM_SUBSCRIPTION_ID environment variable
}
```

### 3. Atualização dos Arquivos `.tfvars`

**Arquivos modificados:**
- `terraform/00-iam/terraform.tfvars`
- `terraform/00-iam/terraform.tfvars.example`
- `terraform/02-kubernetes/terraform.tfvars`
- `terraform/02-kubernetes/terraform.tfvars.example`
- `terraform/01-networking/terraform.tfvars.example`

**Mudança:**
```hcl
# ANTES
subscription_id = "35a5288e-6993-4afa-97a9-2862baaf944e"

# DEPOIS
# Note: subscription_id is now read from ARM_SUBSCRIPTION_ID environment variable
#       Set it via: export ARM_SUBSCRIPTION_ID="your-subscription-id"
#       Or in GitHub Actions secrets as: AZURE_SUBSCRIPTION_ID
```

## 🎯 Como Funciona Agora

### GitHub Actions (CI/CD)

O workflow já está configurado corretamente com as variáveis de ambiente:

```yaml
env:
  ARM_CLIENT_ID: ${{ secrets.AZURE_CLIENT_ID }}
  ARM_CLIENT_SECRET: ${{ secrets.AZURE_CLIENT_SECRET }}
  ARM_SUBSCRIPTION_ID: ${{ secrets.AZURE_SUBSCRIPTION_ID }}
  ARM_TENANT_ID: ${{ secrets.AZURE_TENANT_ID }}
```

O provider `azurerm` do Terraform **automaticamente** lê essas variáveis de ambiente:
- `ARM_SUBSCRIPTION_ID` → `subscription_id`
- `ARM_CLIENT_ID` → `client_id`
- `ARM_CLIENT_SECRET` → `client_secret`
- `ARM_TENANT_ID` → `tenant_id`

### Desenvolvimento Local

Para rodar Terraform localmente, você precisa configurar as variáveis de ambiente:

```bash
# Opção 1: Exportar variáveis de ambiente
export ARM_SUBSCRIPTION_ID="35a5288e-6993-4afa-97a9-2862baaf944e"
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"
export ARM_TENANT_ID="58729694-7d24-4182-94ef-60f4c02329e3"

# Opção 2: Usar Azure CLI (recomendado para desenvolvimento)
az login
# O Terraform usará automaticamente suas credenciais do Azure CLI
```

## 📝 Secrets Necessários no GitHub

Certifique-se de ter estes secrets configurados no seu repositório GitHub:

1. **`AZURE_SUBSCRIPTION_ID`** - ID da subscription Azure
2. **`AZURE_CLIENT_ID`** - Application (client) ID do Service Principal
3. **`AZURE_CLIENT_SECRET`** - Client secret do Service Principal
4. **`AZURE_TENANT_ID`** - Directory (tenant) ID

### Como Verificar

```bash
# Listar secrets configurados (não mostra os valores)
gh secret list

# Ou via interface web:
# Settings → Secrets and variables → Actions → Repository secrets
```

## 🔧 Como Obter as Credenciais

Se você ainda não tem as credenciais configuradas:

```bash
# 1. Fazer login no Azure
az login

# 2. Obter Subscription ID
az account show --query id -o tsv

# 3. Criar Service Principal
az ad sp create-for-rbac \
  --name "github-actions-terraform" \
  --role "Contributor" \
  --scopes /subscriptions/<SUBSCRIPTION_ID> \
  --sdk-auth

# O comando acima retorna:
# {
#   "clientId": "...",          → AZURE_CLIENT_ID
#   "clientSecret": "...",      → AZURE_CLIENT_SECRET
#   "subscriptionId": "...",    → AZURE_SUBSCRIPTION_ID
#   "tenantId": "..."           → AZURE_TENANT_ID
# }
```

## ✨ Benefícios da Mudança

### 1. **Segurança Melhorada**
- Subscription ID não precisa mais estar em arquivos de código
- Todas as credenciais sensíveis vêm de secrets do GitHub
- Reduz risco de commit acidental de credenciais

### 2. **Consistência com Padrões Azure**
- Alinhado com as [melhores práticas da HashiCorp](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret)
- Usa o padrão `ARM_*` environment variables
- Compatível com Azure CLI e outras ferramentas

### 3. **Simplificação do Código**
- Menos variáveis para gerenciar
- Menos parâmetros para passar no GitHub Actions
- Código mais limpo e fácil de manter

### 4. **Flexibilidade**
- Funciona automaticamente com Azure CLI em desenvolvimento local
- Funciona com Service Principal em CI/CD
- Funciona com Managed Identity em Azure Cloud Shell

## 🚀 Próximos Passos

1. **Testar localmente:**
   ```bash
   cd terraform/00-iam
   terraform init
   terraform plan
   ```

2. **Testar no GitHub Actions:**
   - Acesse: Actions → Deploy Infrastructure
   - Selecione: Module: `00-iam`, Action: `plan`
   - Verifique se o plan executa sem pedir `subscription_id`

3. **Validar outros módulos:**
   - Repita o teste para `01-networking` e `02-kubernetes`

## 🐛 Troubleshooting

### Erro: "subscription_id is required"

**Causa:** Variáveis de ambiente não estão configuradas.

**Solução Local:**
```bash
export ARM_SUBSCRIPTION_ID="your-subscription-id"
# ou
az login
```

**Solução GitHub Actions:**
Verifique se os secrets estão configurados corretamente.

### Erro: "Error building ARM Config: obtain subscription"

**Causa:** Credenciais de autenticação inválidas ou expiradas.

**Solução:**
```bash
# Local
az login
az account show

# GitHub Actions
# Recriar o Service Principal e atualizar os secrets
```

## 📚 Referências

- [Azure Provider Authentication](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#authenticating-to-azure)
- [Service Principal Authentication](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/guides/service_principal_client_secret)
- [Environment Variables](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs#argument-reference)

## 🔐 Nota de Segurança

**IMPORTANTE:** Nunca commite os seguintes valores no Git:
- ❌ `ARM_CLIENT_SECRET` / `AZURE_CLIENT_SECRET`
- ❌ `ARM_SUBSCRIPTION_ID` / `AZURE_SUBSCRIPTION_ID`
- ❌ Service Principal credentials
- ❌ Access tokens

Sempre use:
- ✅ GitHub Secrets para CI/CD
- ✅ Environment variables para desenvolvimento local
- ✅ Azure CLI authentication quando possível
- ✅ `.gitignore` para arquivos sensíveis
