#!/usr/bin/env bash
set -euo pipefail
ACCOUNT="${AWS_ACCOUNT_ID:-556939139551}"
REGION="${AWS_REGION:-us-east-1}"
FROM_TAG="${1:-22809c3}"
TO_TAG="${2:-4ed8add}"

aws ecr get-login-password --region "$REGION" \
  | docker login --username AWS --password-stdin "${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com"

for svc in auth-service flag-service evaluation-service targeting-service analytics-service; do
  URI="${ACCOUNT}.dkr.ecr.${REGION}.amazonaws.com/${svc}"
  docker pull "${URI}:${FROM_TAG}"
  docker tag "${URI}:${FROM_TAG}" "${URI}:${TO_TAG}"
  docker push "${URI}:${TO_TAG}"
  echo "pushed ${svc}:${TO_TAG}"
done
