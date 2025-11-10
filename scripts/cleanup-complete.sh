#!/bin/bash

# Script para limpar COMPLETAMENTE todos os recursos do Azure
# USE COM CUIDADO - Isso deletará TUDO

set -e

echo "🧹 Limpeza Completa do Azure Landing Zone"
echo "=========================================="
echo ""
echo "⚠️  ATENÇÃO: Este script vai deletar:"
echo "   - Resource Group: rg-network"
echo "   - Todas as Managed Identities (mi-aks-*)"
echo "   - Todos os clusters AKS"
echo "   - Todos os recursos dentro do resource group"
echo ""

read -p "Tem certeza? Digite 'SIM' para continuar: " -r
if [[ ! $REPLY == "SIM" ]]; then
    echo "Operação cancelada."
    exit 0
fi

echo ""
echo "Iniciando limpeza..."
echo ""

# 1. Deletar todas as Managed Identities órfãs
echo "1️⃣  Deletando Managed Identities..."
for env in dev stg prd sdx; do
    IDENTITY_ID=$(az identity show \
        --name "mi-aks-$env" \
        --resource-group "rg-network" \
        --query id -o tsv 2>/dev/null || echo "")
    
    if [ -n "$IDENTITY_ID" ]; then
        echo "   🗑️  Deletando mi-aks-$env..."
        az identity delete --ids "$IDENTITY_ID" 2>/dev/null || echo "   ⚠️  Falha ao deletar mi-aks-$env"
    else
        echo "   ✅ mi-aks-$env não existe"
    fi
done

echo ""

# 2. Deletar todos os clusters AKS
echo "2️⃣  Deletando clusters AKS..."
AKS_CLUSTERS=$(az aks list --query "[].{name:name, rg:resourceGroup}" -o json 2>/dev/null)

if [ "$AKS_CLUSTERS" != "[]" ]; then
    echo "$AKS_CLUSTERS" | jq -r '.[] | "\(.name)|\(.rg)"' | while IFS='|' read -r name rg; do
        echo "   🗑️  Deletando AKS: $name (em $rg)..."
        az aks delete --name "$name" --resource-group "$rg" --yes --no-wait
    done
    echo "   ⏳ Clusters AKS sendo deletados em background..."
else
    echo "   ✅ Nenhum cluster AKS encontrado"
fi

echo ""

# 3. Deletar Resource Group
echo "3️⃣  Deletando Resource Group..."
if az group exists --name "rg-network" 2>/dev/null | grep -q "true"; then
    echo "   🗑️  Deletando rg-network..."
    az group delete --name "rg-network" --yes --no-wait
    echo "   ⏳ Resource group sendo deletado em background..."
else
    echo "   ✅ rg-network não existe"
fi

echo ""

# 4. Deletar Resource Groups de nodes dos AKS (se existirem)
echo "4️⃣  Verificando Resource Groups de nodes AKS..."
for env in dev stg prd sdx; do
    NODE_RG="rg-network-aks-$env-nodes"
    if az group exists --name "$NODE_RG" 2>/dev/null | grep -q "true"; then
        echo "   🗑️  Deletando $NODE_RG..."
        az group delete --name "$NODE_RG" --yes --no-wait
    fi
done

echo ""
echo "=========================================="
echo "✅ Limpeza iniciada!"
echo ""
echo "⏳ Aguardando deleção completa (isso leva 3-5 minutos)..."
echo ""

# Aguardar até rg-network ser deletado
MAX_WAIT=300  # 5 minutos
ELAPSED=0
while [ $ELAPSED -lt $MAX_WAIT ]; do
    if az group exists --name "rg-network" 2>/dev/null | grep -q "false"; then
        echo "✅ rg-network deletado!"
        break
    fi
    
    sleep 10
    ELAPSED=$((ELAPSED + 10))
    echo "   Aguardando... ${ELAPSED}s"
done

echo ""
echo "=========================================="
echo "🎯 Próximos Passos:"
echo ""
echo "1. Verifique se tudo foi deletado:"
echo "   az group list --query \"[?name=='rg-network'].name\" -o tsv"
echo ""
echo "2. Execute o workflow no GitHub Actions:"
echo "   - Module: all"
echo "   - Action: apply"
echo "   - Clusters: all"
echo ""
echo "3. O deployment deve funcionar sem erros agora!"
echo ""
