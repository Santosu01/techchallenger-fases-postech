#!/bin/bash
# -----------------------------------------------------------------------------
# Script de Auto-Cura (Self-Healing) - ToggleMaster
# -----------------------------------------------------------------------------

TARGET_DEPLOYMENT="evaluation-service"
NAMESPACE="togglemaster"

echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🚨 Alerta de falha recebido!"
echo "[$(date '+%Y-%m-%d %H:%M:%S')] 🔧 Executando autocura no deployment: $TARGET_DEPLOYMENT..."

# Aciona a reinicialização segura (rolling restart) no cluster
kubectl rollout restart deployment/$TARGET_DEPLOYMENT -n $NAMESPACE

# Aguarda a conclusão da reinicialização (timeout de 60s)
if kubectl rollout status deployment/$TARGET_DEPLOYMENT -n $NAMESPACE --timeout=60s; then
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ✅ Self-healing concluído com sucesso. Pods do $TARGET_DEPLOYMENT reciclados."
else
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ❌ Erro: Falha ao restabelecer o deployment $TARGET_DEPLOYMENT dentro do limite de tempo."
    exit 1
fi
