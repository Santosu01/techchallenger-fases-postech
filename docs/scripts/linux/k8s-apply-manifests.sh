#!/bin/bash
# ==========================================
# DEPLOY NO KUBERNETES - ToggleMaste
# ==========================================
# EDITE AS VARIAVEIS ABAIXO:

# Namespace
NAMESPACE="togglemaster"

# ==========================================
# INÍCIO DO SCRIPT
# ==========================================

echo "=========================================="
echo "Deploy no Kubernetes (EKS)"
echo "=========================================="

# Define o diretório dos manifestos
K8S_DIR="$(dirname "$0")/../k8s"

if [ ! -d "$K8S_DIR" ]; then
    echo "ERRO: Pasta k8s não encontrada em $K8S_DIR"
    echo "Crie a pasta e adicione os manifestos YAML primeiro."
    exit 1
fi

echo ""
echo "Diretório dos manifestos: $K8S_DIR"
echo "Namespace: $NAMESPACE"
echo ""

echo "=========================================="
echo "Aplicando manifestos em ordem:"
echo "=========================================="

echo ""
echo "[1/6] Namespace..."
kubectl apply -f "$K8S_DIR/1-namespace.yaml"

echo "[2/6] Secrets..."
kubectl apply -f "$K8S_DIR/2-secrets.yaml"

echo "[3/6] ConfigMap..."
kubectl apply -f "$K8S_DIR/3-configmap.yaml"

echo "[4/6] Deployments e Services..."
kubectl apply -f "$K8S_DIR/4-deployments.yaml"

echo "[5/6] Ingress..."
kubectl apply -f "$K8S_DIR/5-ingress.yaml"

echo "[6/6] HPA..."
kubectl apply -f "$K8S_DIR/6-hpa.yaml"

echo ""
echo "=========================================="
echo "Verificando status dos pods..."
echo "=========================================="
kubectl get pods -n "$NAMESPACE"

echo ""
echo "=========================================="
echo "Verificando services..."
echo "=========================================="
kubectl get services -n "$NAMESPACE"

echo ""
echo "=========================================="
echo "Verificando ingress..."
echo "=========================================="
kubectl get ingress -n "$NAMESPACE"

echo ""
echo "=========================================="
echo "Verificando HPA..."
echo "=========================================="
kubectl get hpa -n "$NAMESPACE"

echo ""
echo "=========================================="
echo "Deploy concluído!"
echo "=========================================="
echo ""
