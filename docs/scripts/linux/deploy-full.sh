#!/bin/bash
# ==========================================
# DEPLOY COMPLETO - ToggleMaste
# ==========================================
# EDITE AS VARIAVEIS ABAIXO:

# Região AWS
REGIAO="us-east-1"

# Seu ID da AWS (12 dígitos)
REGISTRY_ID="123456789012"

# Pasta onde estão os serviços
SERVICES_FOLDER="backend-services"

# Lista de serviços (separados por espaço)
SERVICES="auth-service flag-service targeting-service evaluation-service analytics-service"

# Cluster EKS
CLUSTER_NAME="togglemaster-cluster"
NAMESPACE="togglemaster"

# Diretorio k8s
K8S_DIR="$(dirname "$0")/../k8s"

# ==========================================
# INÍCIO DO SCRIPT
# ==========================================

echo "=========================================="
echo "Deploy Completo - ToggleMaster"
echo "=========================================="
echo ""
echo "ATENÇÃO: Este script irá:"
echo "1. Autenticar no ECR"
echo "2. Build e push das imagens"
echo "3. Configurar kubectl"
echo "4. Deploy no Kubernetes"
echo ""
read -p "Continuar? (s/N) " -n 1 -
echo ""
if [[ ! $REPLY =~ ^[Ss]$ ]]; then
    echo "Cancelado."
    exit 0
fi

clea
echo ""
echo "=========================================="
echo "[1/4] AUTENTICANDO NO ECR"
echo "=========================================="
aws ecr get-login-password --region "$REGIAO" | \
  docker login --username AWS --password-stdin "$REGISTRY_ID.dkr.ecr.$REGIAO.amazonaws.com"

if [ $? -ne 0 ]; then
    echo ""
    echo "ERRO: Falha na autenticação!"
    exit 1
fi

clea
echo ""
echo "=========================================="
echo "[2/4] BUILD E PUSH DAS IMAGENS"
echo "=========================================="
PROJECT_ROOT="$(dirname "$0")/../../.."
cd "$PROJECT_ROOT"

# Loop pelos serviços
for SERVICE in $SERVICES; do
    echo ""
    echo "Processando: $SERVICE"
    cd "$SERVICES_FOLDER/$SERVICE"
    docker build -t "$SERVICE" .
    docker tag "$SERVICE:latest" "$REGISTRY_ID.dkr.ecr.$REGIAO.amazonaws.com/$SERVICE:latest"
    docker push "$REGISTRY_ID.dkr.ecr.$REGIAO.amazonaws.com/$SERVICE:latest"
    cd ../..
done

clea
echo ""
echo "=========================================="
echo "[3/4] CONFIGURANDO KUBECTL"
echo "=========================================="
aws eks update-kubeconfig --region "$REGIAO" --name "$CLUSTER_NAME"

if [ $? -ne 0 ]; then
    echo ""
    echo "ERRO: Falha na configuração do kubectl!"
    exit 1
fi

clea
echo ""
echo "=========================================="
echo "[4/4] DEPLOY NO KUBERNETES"
echo "=========================================="

kubectl apply -f "$K8S_DIR/1-namespace.yaml"
kubectl apply -f "$K8S_DIR/2-secrets.yaml"
kubectl apply -f "$K8S_DIR/3-configmap.yaml"
kubectl apply -f "$K8S_DIR/4-deployments.yaml"
kubectl apply -f "$K8S_DIR/5-ingress.yaml"
kubectl apply -f "$K8S_DIR/6-hpa.yaml"

clea
echo ""
echo "=========================================="
echo "Verificando status dos pods..."
echo "=========================================="
kubectl get pods -n "$NAMESPACE"

echo ""
echo "=========================================="
echo "DEPLOY COMPLETO CONCLUÍDO!"
echo "=========================================="
echo ""
echo "Para testar os serviços, execute:"
echo "  ./test-api.sh"
echo ""
