#!/bin/bash
# ==========================================
# CONFIGURAR KUBECTL - ToggleMaste
# ==========================================
# EDITE AS VARIAVEIS ABAIXO:

# Região AWS
REGIAO="us-east-1"

# Cluster EKS
CLUSTER_NAME="togglemaster-cluster"

# ==========================================
# INÍCIO DO SCRIPT
# ==========================================

echo "=========================================="
echo "Configurando kubectl para o Cluster EKS"
echo "=========================================="

echo ""
echo "Atualizando kubeconfig..."
echo "Cluster: $CLUSTER_NAME"
echo "Região: $REGIAO"
echo ""

aws eks update-kubeconfig --region "$REGIAO" --name "$CLUSTER_NAME"

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "SUCESSO! kubectl configurado."
    echo "=========================================="
    echo ""
    echo "Testando conexão..."
    kubectl get nodes
    echo ""
    echo "Verificando namespaces..."
    kubectl get namespaces
else
    echo ""
    echo "=========================================="
    echo "ERRO! Falha na configuração do kubectl."
    echo "=========================================="
    echo ""
    echo "Possíveis causas:"
    echo "1. AWS CLI não instalada"
    echo "2. kubectl não instalado"
    echo "3. Credenciais não configuradas"
    echo "4. Cluster EKS não existe ou não está ativo"
    exit 1
fi

echo ""
