#!/usr/bin/env bash
# Build e push das 5 imagens para o ECR (Epico 3).
# Use quando o terraform apply recriou repos ECR vazios e o CI ainda nao rodou.
#
# Uso (raiz do repo, WSL + Docker):
#   export ECR_IMAGE_TAG='22809c3'
#   python3 docs/scripts/linux/fix-crlf.py   # se necessario no WSL
#   ./docs/scripts/linux/push-all-ecr.sh
#
# Requer: aws cli, docker, credenciais Academy em ~/.aws/credentials

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
ACCOUNT="${AWS_ACCOUNT_ID:-556939139551}"
REGION="${AWS_REGION:-us-east-1}"
TAG="${ECR_IMAGE_TAG:-22809c3}"

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"

for svc in auth-service flag-service evaluation-service targeting-service analytics-service; do
  echo "========== BUILD $svc =========="
  cd "$ROOT/backend-services/$svc"
  docker build -t "${svc}:${TAG}" .
  ECR_URI="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/${svc}"
  docker tag "${svc}:${TAG}" "${ECR_URI}:${TAG}"
  docker push "${ECR_URI}:${TAG}"
  echo "Pushed ${ECR_URI}:${TAG}"
done

echo "ALL IMAGES PUSHED (tag=${TAG})"
