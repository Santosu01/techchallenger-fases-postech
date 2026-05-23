#!/bin/bash
# ==========================================
# LIMPEZA DE RECURSOS - ToggleMaste
# ==========================================
# ATENÇÃO: Este script irá deletar todos os recursos criados
# ==========================================
# EDITE AS VARIAVEIS ABAIXO:

# Namespace
NAMESPACE="togglemaster"

# Cluster EKS
CLUSTER_NAME="togglemaster-cluster"

# ==========================================
# INÍCIO DO SCRIPT
# ==========================================

echo "=========================================="
echo "ATENÇÃO! LIMPEZA DE RECURSOS"
echo "=========================================="
echo ""
echo "Este script irá deletar:"
echo "- Namespace do Kubernetes e todos os pods"
echo ""
echo "Para limpar recursos AWS, use o console AWS."
echo ""
read -p "Continuar? (s/N) " -n 1 -
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Cancelado."
    exit 0
fi

echo ""
echo "=========================================="
echo "Deletando namespace do Kubernetes..."
echo "=========================================="
kubectl delete namespace "$NAMESPACE"

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "Namespace deletado com sucesso!"
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "ERRO ou namespace não existe."
    echo "=========================================="
fi

echo ""
echo "=========================================="
echo "Para completar a limpeza, delete via Console AWS:"
echo "=========================================="
echo ""
echo "1. EKS Cluster: $CLUSTER_NAME"
echo "2. RDS Instances (togglemaster-*)"
echo "3. ElastiCache (togglemaster-cache)"
echo "4. DynamoDB Table (ToggleMasterAnalytics)"
echo "5. SQS Queue (togglemaster-analytics-queue)"
echo "6. ECR Repositories (opcional)"
echo ""
