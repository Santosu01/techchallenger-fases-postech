#!/bin/bash
# ==========================================
# AUTENTICAR NO ECR - ToggleMaste
# ==========================================
# EDITE AS VARIAVEIS ABAIXO:

# Região AWS
REGIAO="us-east-1"

# Seu ID da AWS (12 dígitos)
REGISTRY_ID="123456789012"

# ==========================================
# INÍCIO DO SCRIPT
# ==========================================

echo "=========================================="
echo "Autenticando no Amazon ECR..."
echo "=========================================="
echo ""
echo "Região: $REGIAO"
echo "Registry: $REGISTRY_ID.dkr.ecr.$REGIAO.amazonaws.com"
echo ""

aws ecr get-login-password --region "$REGIAO" | \
  docker login --username AWS --password-stdin "$REGISTRY_ID.dkr.ecr.$REGIAO.amazonaws.com"

if [ $? -eq 0 ]; then
    echo ""
    echo "=========================================="
    echo "SUCESSO! Autenticado no ECR."
    echo "=========================================="
else
    echo ""
    echo "=========================================="
    echo "ERRO! Falha na autenticação."
    echo "=========================================="
    echo ""
    echo "Possíveis causas:"
    echo "1. AWS CLI não instalada"
    echo "2. Credenciais não configuradas (execute: aws configure)"
    echo "3. REGISTRY_ID incorreto"
    exit 1
fi

echo ""
