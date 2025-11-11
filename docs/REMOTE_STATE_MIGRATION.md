# Migração para Remote State Backend

## 🎯 Problema Identificado

**Sintoma**: GitHub Actions diz "0 resources destroyed" mas recursos ainda existem no Azure.

**Causa**: Terraform no GitHub Actions **não tem state file**, então não sabe quais recursos deletar.

```
┌─────────────────────────────────────────────┐
│ GitHub Actions Runner (limpo a cada run)   │
├─────────────────────────────────────────────┤
│ 1. git clone (pega código)                 │
│ 2. terraform init (state vazio!)           │
│ 3. terraform destroy                       │
│    └─> "No objects to destroy" ❌          │
└─────────────────────────────────────────────┘
```

**Solução**: Usar **Remote State Backend** igual AWS e GCP.

---

## ✅ Comparação com Outros Projetos

### AWS Landing Zone
```hcl
backend "s3" {
  bucket         = "vschiavo-home-terraform-state"
  key            = "aws-landing-zone/iam/terraform.tfstate"
  encrypt        = true
  dynamodb_table = "terraform-state-lock"
}
```

### GCP Landing Zone
```hcl
backend "gcs" {
  bucket = "vschiavo-home-terraform-state"
  prefix = "gcp-landing-zone/iam/state"
}
```

### Azure Landing Zone (ANTES - SEM BACKEND)
```hcl
# Comentado = não usado!
# backend "azurerm" {
#   resource_group_name = "rg-terraform-state"
# }
```

### Azure Landing Zone (DEPOIS - COM BACKEND) ✅
```hcl
backend "azurerm" {
  resource_group_name  = "rg-terraform-state"
  storage_account_name = "vstfstate"
  container_name       = "tfstate"
  key                  = "azure-landing-zone/iam/terraform.tfstate"
}
```

---

## 🚀 Setup do Remote Backend

### Passo 1: Criar Storage no Azure

```bash
cd /Users/home/Documents/workspace-schiavo/azure-landing-zone

# Executar script de setup
chmod +x scripts/setup-remote-backend.sh
./scripts/setup-remote-backend.sh
```

**O que o script faz**:
1. ✅ Cria Resource Group: `rg-terraform-state`
2. ✅ Cria Storage Account: `vstfstate`
3. ✅ Habilita versionamento de blobs
4. ✅ Cria container: `tfstate`
5. ✅ Configura segurança (HTTPS only, sem acesso público)

**Tempo**: ~2-3 minutos

---

### Passo 2: Migrar State Existente (Se Houver)

**IMPORTANTE**: Se você tem recursos no Azure que foram criados com state local, precisa migrar o state.

#### Opção A: Você Tem State Local com Recursos

```bash
cd terraform/00-iam

# Migrar state local para remote
terraform init -migrate-state

# Responda "yes" quando perguntar:
# "Do you want to copy existing state to the new backend?"

# Verificar migração
terraform state list  # Deve mostrar recursos
```

Repetir para cada módulo:
```bash
cd ../01-networking
terraform init -migrate-state

cd ../02-kubernetes
terraform init -migrate-state
```

#### Opção B: Não Há State Local (Recursos Órfãos)

Se recursos existem no Azure mas não há state local:

```bash
# 1. LIMPAR TUDO NO AZURE
./scripts/cleanup-complete.sh

# 2. AGUARDAR 5 minutos para Azure processar

# 3. INICIALIZAR com backend vazio
cd terraform/00-iam
terraform init

cd ../01-networking
terraform init

cd ../02-kubernetes
terraform init

# 4. DEPLOY DO ZERO (agora com remote state)
# Via GitHub Actions ou local
```

---

### Passo 3: Commit dos Backend Files

```bash
cd /Users/home/Documents/workspace-schiavo/azure-landing-zone

# Adicionar backend.tf files
git add terraform/00-iam/backend.tf
git add terraform/01-networking/backend.tf
git add terraform/02-kubernetes/backend.tf

# Adicionar main.tf limpos (sem backend comentado)
git add terraform/00-iam/main.tf
git add terraform/01-networking/main.tf
git add terraform/02-kubernetes/main.tf

# Commit
git commit -m "feat: configure remote state backend using Azure Storage

Added dedicated backend.tf files for each module following
the pattern used in AWS and GCP landing zones.

Backend Configuration:
- Resource Group: rg-terraform-state
- Storage Account: vstfstate
- Container: tfstate
- Keys:
  * azure-landing-zone/iam/terraform.tfstate
  * azure-landing-zone/networking/terraform.tfstate
  * azure-landing-zone/kubernetes/terraform.tfstate

Benefits:
- ✅ State persistence across GitHub Actions runs
- ✅ State locking to prevent concurrent modifications
- ✅ Blob versioning for state recovery
- ✅ Destroy now works correctly in CI/CD
- ✅ Consistent with AWS and GCP landing zones

This fixes the issue where GitHub Actions destroy would report
'0 resources destroyed' because it had no state file.

To setup:
1. Run: ./scripts/setup-remote-backend.sh
2. Migrate state: terraform init -migrate-state (per module)
3. Test deploy/destroy via GitHub Actions"

git push
```

---

## 🔄 Workflow de Migração Completo

### Se Você Quer Começar do Zero (RECOMENDADO)

```bash
# 1. Setup storage backend
./scripts/setup-remote-backend.sh

# 2. Limpar recursos órfãos no Azure
./scripts/cleanup-complete.sh

# 3. Aguardar 5 minutos
sleep 300

# 4. Commit backend files
git add terraform/*/backend.tf terraform/*/main.tf
git commit -m "feat: add remote state backend"
git push

# 5. Deploy via GitHub Actions (agora com remote state!)
# Workflow: deploy-infrastructure
#   module: all
#   action: apply
#   clusters: all

# 6. Testar destroy
# Workflow: deploy-infrastructure
#   module: all
#   action: destroy
#   clusters: all
#   confirm_destroy: DESTROY
```

---

### Se Você Quer Preservar State Existente

```bash
# 1. Setup storage backend
./scripts/setup-remote-backend.sh

# 2. Migrar state de cada módulo
cd terraform/00-iam
terraform init -migrate-state  # Responda "yes"

cd ../01-networking
terraform init -migrate-state  # Responda "yes"

cd ../02-kubernetes
terraform init -migrate-state  # Responda "yes"

# 3. Verificar que state foi migrado
terraform state list  # Em cada módulo

# 4. Deletar state files locais
rm terraform/*/terraform.tfstate*

# 5. Commit
git add terraform/*/backend.tf terraform/*/main.tf
git commit -m "feat: add remote state backend and migrate state"
git push

# 6. Testar no GitHub Actions
# Deploy/Destroy devem funcionar agora!
```

---

## 🔍 Verificação do Backend

### Verificar que backend está configurado

```bash
cd terraform/00-iam
terraform init

# Deve mostrar:
# "Initializing the backend..."
# "Successfully configured the backend "azurerm"!"
```

### Verificar state files no Azure

```bash
# Listar blobs no container
az storage blob list \
    --container-name tfstate \
    --account-name vstfstate \
    --output table

# Deve mostrar:
# azure-landing-zone/iam/terraform.tfstate
# azure-landing-zone/networking/terraform.tfstate
# azure-landing-zone/kubernetes/terraform.tfstate
```

### Verificar state locking

```bash
# Tentar apply em dois terminais simultaneamente
# O segundo deve esperar o primeiro terminar
cd terraform/00-iam
terraform plan  # Terminal 1
terraform plan  # Terminal 2 (vai esperar)
```

---

## ⚠️ IMPORTANTE

### NÃO Delete o Resource Group de State!

```bash
# ❌ NUNCA FAÇA ISSO:
# az group delete --name rg-terraform-state

# O resource group rg-terraform-state deve ser PERMANENTE
# Se deletá-lo, você perde todo o histórico de state!
```

### Backup do State

O state já tem versionamento habilitado, mas você pode fazer backup manual:

```bash
# Download dos states
az storage blob download-batch \
    --source tfstate \
    --destination ./state-backup-$(date +%Y%m%d) \
    --account-name vstfstate \
    --pattern "azure-landing-zone/*"
```

---

## 📊 Antes vs Depois

### ANTES (Sem Remote Backend)

```
Local:
  terraform apply ✅ (cria resources + state local)
  terraform destroy ✅ (lê state local)

GitHub Actions:
  terraform apply ✅ (cria resources, state perdido após run)
  terraform destroy ❌ (sem state = "0 resources")
```

### DEPOIS (Com Remote Backend)

```
Local:
  terraform apply ✅ (cria resources + state no Azure)
  terraform destroy ✅ (lê state do Azure)

GitHub Actions:
  terraform apply ✅ (cria resources + state no Azure)
  terraform destroy ✅ (lê state do Azure)
```

---

## 🎯 Próximos Passos

1. **AGORA**: Executar `./scripts/setup-remote-backend.sh`
2. **ESCOLHER**: Migrar state ou começar do zero
3. **COMMIT**: Arquivos backend.tf
4. **TESTAR**: Deploy/Destroy via GitHub Actions

**Após isso, destroy vai funcionar perfeitamente!** ✅
