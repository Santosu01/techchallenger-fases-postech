#!/bin/bash
# ==========================================
# BUILD E PUSH DE IMAGENS DOCKER - ToggleMaste
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

# ==========================================
# INÍCIO DO SCRIPT
# ==========================================

echo "=========================================="
echo "Build e Push de Imagens Docker"
echo "=========================================="

# Primeiro autenticar no ECR
echo ""
echo "[1/6] Autenticando no ECR..."
aws ecr get-login-password --region "$REGIAO" | \
  docker login --username AWS --password-stdin "$REGISTRY_ID.dkr.ecr.$REGIAO.amazonaws.com"

if [ $? -ne 0 ]; then
    echo "ERRO: Falha na autenticação!"
    exit 1
fi

# Define o diretório raiz do projeto
PROJECT_ROOT="$(dirname "$0")/../../.."
cd "$PROJECT_ROOT" || exit 1

# Contador para progresso
COUNTER=2

# Loop pelos serviços
for SERVICE in $SERVICES; do
    echo ""
    echo "==========================================="
    echo "[$COUNTER/6] Build e Push: $SERVICE"
    echo "==========================================="

    cd "$SERVICES_FOLDER/$SERVICE" || exit 1
    docker build -t "$SERVICE" . || exit 1
    docker tag "$SERVICE:latest" "$REGISTRY_ID.dkr.ecr.$REGIAO.amazonaws.com/$SERVICE:latest" || exit 1
    docker push "$REGISTRY_ID.dkr.ecr.$REGIAO.amazonaws.com/$SERVICE:latest" || exit 1
    cd ../..

    COUNTER=$((COUNTER + 1))
done

echo ""
echo "=========================================="
echo "SUCESSO! Todas as imagens foram pushadas!"
echo "=========================================="
echo ""
