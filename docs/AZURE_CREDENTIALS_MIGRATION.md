# Migração de Credenciais Azure

## 📋 Resumo das Mudanças

Este documento descreve as mudanças realizadas para simplificar o gerenciamento de credenciais Azure no projeto, removendo a necessidade de passar `subscription_id` e `tenant_id` como variáveis Terraform e utilizando as variáveis de ambiente do GitHub Actions.

## ✅ O Que Foi Alterado

### 1. Remoção das Variáveis `subscription_id` e `tenant_id`

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

variable "tenant_id" {
  description = "Azure Tenant ID"
  type        = string
}

# DEPOIS
# Variáveis removidas - valores agora vêm de ARM_SUBSCRIPTION_ID e ARM_TENANT_ID
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

provider "azuread" {
  tenant_id = var.tenant_id
}

# DEPOIS
provider "azurerm" {
  features {}
  # subscription_id will be read from ARM_SUBSCRIPTION_ID environment variable
}

provider "azuread" {
  # tenant_id will be read from ARM_TENANT_ID environment variable
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
subscription_id = "<seu-subscription-id>"
tenant_id = "<seu-tenant-id>"

# DEPOIS
# Note: Azure credentials are now read from environment variables:
#   - ARM_SUBSCRIPTION_ID (subscription_id)
#   - ARM_TENANT_ID (tenant_id)
#   Set them via: export ARM_SUBSCRIPTION_ID="..." ARM_TENANT_ID="..."
#   Or in GitHub Actions secrets as: AZURE_SUBSCRIPTION_ID, AZURE_TENANT_ID
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
- `ARM_TENANT_ID` → `tenant_id`
- `ARM_CLIENT_ID` → `client_id`
- `ARM_CLIENT_SECRET` → `client_secret`

### Desenvolvimento Local

Para rodar Terraform localmente, você precisa configurar as variáveis de ambiente:

```bash
# Opção 1: Exportar variáveis de ambiente
export ARM_SUBSCRIPTION_ID="35a5288e-6993-4afa-97a9-2862baaf944e"
export ARM_TENANT_ID="58729694-7d24-4182-94ef-60f4c02329e3"
export ARM_CLIENT_ID="your-client-id"
export ARM_CLIENT_SECRET="your-client-secret"

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

## ⚠️ Permissões Necessárias

### Por Que Owner é Necessário?

O módulo `00-iam` do Terraform cria **role assignments** (atribuições de função) para as managed identities dos clusters AKS. Esta operação requer permissões elevadas que apenas as roles **Owner** ou **User Access Administrator** possuem.

**Recursos que o IAM cria:**
- ✅ Resource Group (`rg-network`) - Requer: Contributor
- ✅ User Assigned Identities (4x) - Requer: Contributor
- ❌ **Role Assignments** (8x) - Requer: **Owner** ou **User Access Administrator**

### Tabela de Permissões

| Azure Role | Criar Recursos | Criar Role Assignments | Recomendação |
|------------|----------------|----------------------|-------------|
| **Contributor** | ✅ Sim | ❌ Não | ❌ Não suficiente |
| **User Access Administrator** | ❌ Não | ✅ Sim | ⚠️ Usar com Contributor |
| **Owner** | ✅ Sim | ✅ Sim | ✅ Recomendado |

### Opções de Configuração

**Opção 1: Owner (Mais Simples)**
```bash
az role assignment create \
  --assignee "<CLIENT_ID>" \
  --role "Owner" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>"
```

**Opção 2: Contributor + User Access Administrator (Mais Granular)**
```bash
# Role para criar recursos
az role assignment create \
  --assignee "<CLIENT_ID>" \
  --role "Contributor" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>"

# Role para criar role assignments
az role assignment create \
  --assignee "<CLIENT_ID>" \
  --role "User Access Administrator" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>"
```

### Verificar Permissões

```bash
# Listar roles do Service Principal
az role assignment list --assignee "<CLIENT_ID>" --output table

# Deve mostrar:
# Principal    Role     Scope
# ----------   ------   ---------------------------
# <CLIENT_ID>  Owner    /subscriptions/<SUBSCRIPTION_ID>
```

## 🔧 Como Obter as Credenciais

Se você ainda não tem as credenciais configuradas:

```bash
# 1. Fazer login no Azure
az login

# 2. Obter Subscription ID
az account show --query id -o tsv

# 3. Criar Service Principal com role Owner
# IMPORTANTE: Use "Owner" e não "Contributor" para permitir criação de role assignments
az ad sp create-for-rbac \
  --name "sp-github-actions-landing-zone" \
  --role "Owner" \
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

### Erro: "AuthorizationFailed: Cannot perform action 'Microsoft.Authorization/roleAssignments/write'"

**Causa:** Service Principal não tem permissão para criar role assignments.

**Solução:**
```bash
# 1. Verificar permissões atuais
CLIENT_ID="<CLIENT_ID>"
az role assignment list --assignee "$CLIENT_ID" --output table

# 2. Adicionar role Owner se estiver faltando
az role assignment create \
  --assignee "$CLIENT_ID" \
  --role "Owner" \
  --scope "/subscriptions/<SUBSCRIPTION_ID>"

# 3. Aguardar 1-2 minutos para propagação
# 4. Executar o workflow novamente
```

**Verificação:** Após adicionar a role, você deve ver tanto "Contributor" quanto "Owner" listados.

### Erro: "subscription_id is required" ou "tenant_id is required"

**Causa:** Variáveis de ambiente não estão configuradas.

**Solução Local:**
```bash
export ARM_SUBSCRIPTION_ID="your-subscription-id"
export ARM_TENANT_ID="your-tenant-id"
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
- ❌ `ARM_TENANT_ID` / `AZURE_TENANT_ID`
- ❌ Service Principal credentials
- ❌ Access tokens

Sempre use:
- ✅ GitHub Secrets para CI/CD
- ✅ Environment variables para desenvolvimento local
- ✅ Azure CLI authentication quando possível
- ✅ `.gitignore` para arquivos sensíveis
