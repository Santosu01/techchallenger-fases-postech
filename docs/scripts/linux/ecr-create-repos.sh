#!/bin/bash
# ==========================================
# CRIAR REPOSITÓRIOS ECR - ToggleMaste
# ==========================================
# EDITE AS VARIAVEIS ABAIXO:

# Região AWS
REGIAO="us-east-1"

# Seu ID da AWS (12 dígitos)
REGISTRY_ID="123456789012"

# Nomes dos repositórios
REPO_AUTH="auth-service"
REPO_FLAG="flag-service"
REPO_TARGETING="targeting-service"
REPO_EVALUATION="evaluation-service"
REPO_ANALYTICS="analytics-service"

# ==========================================
# INÍCIO DO SCRIPT
# ==========================================

echo "=========================================="
echo "Criar Repositórios no Amazon ECR"
echo "=========================================="

echo ""
echo "Criando repositórios no ECR..."
echo "Região: $REGIAO"
echo ""

echo "[1/5] Criando repositório: $REPO_AUTH"
aws ecr create-repository --repository-name "$REPO_AUTH" --region "$REGIAO" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Criado com sucesso!"
else
    echo "Já existe ou erro na criação."
fi

echo "[2/5] Criando repositório: $REPO_FLAG"
aws ecr create-repository --repository-name "$REPO_FLAG" --region "$REGIAO" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Criado com sucesso!"
else
    echo "Já existe ou erro na criação."
fi

echo "[3/5] Criando repositório: $REPO_TARGETING"
aws ecr create-repository --repository-name "$REPO_TARGETING" --region "$REGIAO" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Criado com sucesso!"
else
    echo "Já existe ou erro na criação."
fi

echo "[4/5] Criando repositório: $REPO_EVALUATION"
aws ecr create-repository --repository-name "$REPO_EVALUATION" --region "$REGIAO" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Criado com sucesso!"
else
    echo "Já existe ou erro na criação."
fi

echo "[5/5] Criando repositório: $REPO_ANALYTICS"
aws ecr create-repository --repository-name "$REPO_ANALYTICS" --region "$REGIAO" 2>/dev/null
if [ $? -eq 0 ]; then
    echo "Criado com sucesso!"
else
    echo "Já existe ou erro na criação."
fi

echo ""
echo "=========================================="
echo "Listando todos os repositórios:"
echo "=========================================="
aws ecr describe-repositories --region "$REGIAO" \
  --query "repositories[].repositoryName" \
  --output table

echo ""
