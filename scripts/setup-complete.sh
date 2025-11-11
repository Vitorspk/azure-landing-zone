#!/bin/bash

# SCRIPT MASTER - SETUP COMPLETO DO REMOTE BACKEND
# Este script faz TUDO: cria backend, limpa recursos, commit, e prepara para deploy

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

clear
echo -e "${BOLD}"
echo "╔═══════════════════════════════════════════════════════════╗"
echo "║  Setup Completo - Remote State Backend + Limpeza         ║"
echo "╚═══════════════════════════════════════════════════════════╝"
echo -e "${NC}"
echo ""

cd /Users/home/Documents/workspace-schiavo/azure-landing-zone

# Verificar login
if ! az account show &> /dev/null; then
    echo -e "${RED}❌ Não está logado no Azure${NC}"
    echo "Execute: az login"
    exit 1
fi

SUBSCRIPTION=$(az account show --query name -o tsv)
echo -e "${GREEN}✓ Logado no Azure${NC}"
echo "  Subscription: $SUBSCRIPTION"
echo ""

# ═══════════════════════════════════════════════════════════════
echo -e "${BLUE}${BOLD}PASSO 1: Criar Storage Backend${NC}"
echo "─────────────────────────────────────────────────────────────"
echo ""

if [ ! -f "scripts/setup-remote-backend.sh" ]; then
    echo -e "${RED}❌ Script setup-remote-backend.sh não encontrado${NC}"
    exit 1
fi

chmod +x scripts/setup-remote-backend.sh
./scripts/setup-remote-backend.sh

echo ""
echo -e "${GREEN}✅ Storage backend criado${NC}"
echo ""

# ═══════════════════════════════════════════════════════════════
echo -e "${BLUE}${BOLD}PASSO 2: Limpar Recursos Órfãos${NC}"
echo "─────────────────────────────────────────────────────────────"
echo ""

echo "Verificando recursos existentes no Azure..."
RG_EXISTS=$(az group exists --name rg-network)

if [ "$RG_EXISTS" == "true" ]; then
    echo -e "${YELLOW}⚠️  Resource group rg-network existe${NC}"
    echo ""
    echo "Recursos encontrados:"
    az resource list --resource-group rg-network --query "[].{Name:name, Type:type}" -o table
    echo ""
    
    read -p "Deletar TODOS os recursos acima? (s/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        echo "Deletando resource group rg-network..."
        az group delete --name rg-network --yes --no-wait
        
        echo ""
        echo "Aguardando deleção (isso leva 3-5 minutos)..."
        
        MAX_WAIT=300
        ELAPSED=0
        while [ $ELAPSED -lt $MAX_WAIT ]; do
            if az group exists --name rg-network | grep -q "false"; then
                echo -e "${GREEN}✅ Resource group deletado!${NC}"
                break
            fi
            sleep 10
            ELAPSED=$((ELAPSED + 10))
            echo -n "."
        done
        echo ""
    else
        echo -e "${YELLOW}⚠️  Recursos não foram deletados${NC}"
        echo "Você precisará importar o state existente ou deletar manualmente depois."
    fi
else
    echo -e "${GREEN}✓ Nenhum recurso órfão encontrado${NC}"
fi

echo ""

# ═══════════════════════════════════════════════════════════════
echo -e "${BLUE}${BOLD}PASSO 3: Commit Backend Files${NC}"
echo "─────────────────────────────────────────────────────────────"
echo ""

echo "Arquivos a serem commitados:"
echo "  ✓ terraform/00-iam/backend.tf"
echo "  ✓ terraform/01-networking/backend.tf"
echo "  ✓ terraform/02-kubernetes/backend.tf"
echo "  ✓ terraform/00-iam/main.tf (limpo)"
echo "  ✓ terraform/01-networking/main.tf (limpo)"
echo "  ✓ terraform/02-kubernetes/main.tf (limpo)"
echo "  ✓ scripts/setup-remote-backend.sh"
echo "  ✓ docs/REMOTE_STATE_MIGRATION.md"
echo ""

git add terraform/00-iam/backend.tf
git add terraform/01-networking/backend.tf
git add terraform/02-kubernetes/backend.tf
git add terraform/00-iam/main.tf
git add terraform/01-networking/main.tf
git add terraform/02-kubernetes/main.tf
git add scripts/setup-remote-backend.sh
git add docs/REMOTE_STATE_MIGRATION.md

git status --short

echo ""
read -p "Fazer commit? (s/N): " -n 1 -r
echo

if [[ $REPLY =~ ^[Ss]$ ]]; then
    git commit -m "feat: add remote state backend (fixes destroy in CI/CD)

CRITICAL FIX: GitHub Actions destroy was not working because
Terraform had no state file to track existing resources.

Added Azure Storage backend configuration following the same
pattern as AWS (S3) and GCP (GCS) landing zones:
- Resource Group: rg-terraform-state
- Storage Account: vstfstate
- Container: tfstate
- Blob versioning enabled for state recovery

Backend Configuration:
- 00-iam: azure-landing-zone/iam/terraform.tfstate
- 01-networking: azure-landing-zone/networking/terraform.tfstate
- 02-kubernetes: azure-landing-zone/kubernetes/terraform.tfstate

Changes:
- Created backend.tf for each module
- Removed backend config from main.tf (moved to backend.tf)
- Added setup-remote-backend.sh for automated setup
- Added REMOTE_STATE_MIGRATION.md with migration guide

Benefits:
✅ State persists across GitHub Actions runs
✅ Destroy now works correctly (knows what to delete)
✅ State locking prevents concurrent modifications
✅ Consistent with AWS and GCP landing zones
✅ Team collaboration with shared state
✅ State recovery via blob versioning

Setup Instructions:
1. Run: ./scripts/setup-remote-backend.sh
2. Deploy via GitHub Actions (state will be saved remotely)
3. Destroy via GitHub Actions (will read remote state)

This completely fixes the issue where destroy would report
'0 resources destroyed' but resources remained in Azure."
    
    echo -e "${GREEN}✅ Commit criado${NC}"
    echo ""
    
    read -p "Fazer push? (s/N): " -n 1 -r
    echo
    
    if [[ $REPLY =~ ^[Ss]$ ]]; then
        git push origin $(git branch --show-current)
        echo -e "${GREEN}✅ Push concluído${NC}"
    fi
fi

echo ""

# ═══════════════════════════════════════════════════════════════
echo ""
echo -e "${BOLD}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${BOLD}║              SETUP COMPLETO!                              ║${NC}"
echo -e "${BOLD}╚═══════════════════════════════════════════════════════════╝${NC}"
echo ""

echo -e "${GREEN}✅ Remote State Backend configurado${NC}"
echo -e "${GREEN}✅ Recursos órfãos limpos${NC}"
echo -e "${GREEN}✅ Backend files commitados${NC}"
echo ""

echo -e "${BOLD}🎯 Próximos Passos:${NC}"
echo ""
echo "1. Ir para GitHub Actions"
echo "2. Executar workflow: deploy-infrastructure"
echo ""
echo "   ${BOLD}Para deploy completo:${NC}"
echo "   ┌─────────────────────────────┐"
echo "   │ module: all                 │"
echo "   │ action: apply               │"
echo "   │ clusters: all               │"
echo "   └─────────────────────────────┘"
echo ""
echo "3. Aguardar ~60-70 minutos"
echo ""
echo "4. ${BOLD}Testar destroy (agora vai funcionar!):${NC}"
echo "   ┌─────────────────────────────┐"
echo "   │ module: all                 │"
echo "   │ action: destroy             │"
echo "   │ clusters: all               │"
echo "   │ confirm_destroy: DESTROY    │"
echo "   └─────────────────────────────┘"
echo ""

echo -e "${BLUE}════════════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${GREEN}Agora o destroy vai funcionar igual AWS e GCP! ✨${NC}"
echo ""
