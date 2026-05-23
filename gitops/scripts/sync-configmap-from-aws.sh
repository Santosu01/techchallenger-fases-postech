#!/usr/bin/env bash
# Regenera gitops/cluster/configmap.yaml a partir dos endpoints atuais na AWS
# (RDS, ElastiCache, SQS) + conta do caller. Exige AWS CLI configurado.
#
# Uso:
#   export RDS_MASTER_PASSWORD='mesma_senha_do_terraform_tfvars'
#   ./gitops/scripts/sync-configmap-from-aws.sh
#
# Opcional: PROJECT_NAME, ENVIRONMENT, AWS_REGION, SQS_QUEUE_NAME, DYNAMODB_TABLE,
#           REDIS_TLS (true|false), CONFIGMAP_OUT (caminho do arquivo de saida).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUT="${CONFIGMAP_OUT:-$ROOT/cluster/configmap.yaml}"

PROJECT_NAME="${PROJECT_NAME:-togglemaster}"
ENVIRONMENT="${ENVIRONMENT:-homolog}"
AWS_REGION="${AWS_REGION:-us-east-1}"
SQS_QUEUE_NAME="${SQS_QUEUE_NAME:-togglemaster-analytics-queue}"
DYNAMODB_TABLE="${DYNAMODB_TABLE:-ToggleMasterAnalytics}"
REDIS_TLS="${REDIS_TLS:-false}"

RDS_MASTER_PASSWORD="${RDS_MASTER_PASSWORD:-${POSTGRES_PASSWORD:-}}"
if [[ -z "$RDS_MASTER_PASSWORD" ]]; then
  echo "Defina RDS_MASTER_PASSWORD (ou POSTGRES_PASSWORD) igual a rds_master_password do Terraform." >&2
  exit 1
fi

if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI nao encontrado no PATH." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "python3 e necessario para codificar a senha na URL." >&2
  exit 1
fi

URL_ENC_PASS="$(python3 -c "import urllib.parse,sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$RDS_MASTER_PASSWORD")"

account="$(aws sts get-caller-identity --query Account --output text)"

auth_host="$(aws rds describe-db-instances --region "$AWS_REGION" \
  --db-instance-identifier "${PROJECT_NAME}-${ENVIRONMENT}-auth-db" \
  --query 'DBInstances[0].Endpoint.Address' --output text)"
flag_host="$(aws rds describe-db-instances --region "$AWS_REGION" \
  --db-instance-identifier "${PROJECT_NAME}-${ENVIRONMENT}-flag-db" \
  --query 'DBInstances[0].Endpoint.Address' --output text)"
target_host="$(aws rds describe-db-instances --region "$AWS_REGION" \
  --db-instance-identifier "${PROJECT_NAME}-${ENVIRONMENT}-targeting-db" \
  --query 'DBInstances[0].Endpoint.Address' --output text)"

redis_addr="$(aws elasticache describe-cache-clusters --region "$AWS_REGION" \
  --cache-cluster-id "${PROJECT_NAME}-${ENVIRONMENT}-redis" --show-cache-node-info \
  --query 'CacheClusters[0].CacheNodes[0].Endpoint.Address' --output text)"

sqs_url="$(aws sqs get-queue-url --region "$AWS_REGION" --queue-name "$SQS_QUEUE_NAME" --query QueueUrl --output text)"

db_auth="${PROJECT_NAME}_${ENVIRONMENT}_auth"
db_flag="${PROJECT_NAME}_${ENVIRONMENT}_flag"
db_target="${PROJECT_NAME}_${ENVIRONMENT}_targeting"

auth_url="postgres://postgres:${URL_ENC_PASS}@${auth_host}:5432/${db_auth}?sslmode=require"
flag_url="postgres://postgres:${URL_ENC_PASS}@${flag_host}:5432/${db_flag}?sslmode=require"
target_url="postgres://postgres:${URL_ENC_PASS}@${target_host}:5432/${db_target}?sslmode=require"

redis_host_port="${redis_addr}:6379"
redis_url="redis://${redis_addr}:6379"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

cat >"$tmp" <<EOF
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
  namespace: togglemaster
data:
  AUTH_DB_HOST: "${auth_host}"
  FLAG_DB_HOST: "${flag_host}"
  TARGETING_DB_HOST: "${target_host}"

  REDIS_HOST: "${redis_host_port}"
  REDIS_TLS: "${REDIS_TLS}"
  REDIS_URL: "${redis_url}"

  AUTH_SERVICE_URL: "http://auth-service:8001"
  FLAG_SERVICE_URL: "http://flag-service:8002"
  TARGETING_SERVICE_URL: "http://targeting-service:8003"
  EVALUATION_SERVICE_URL: "http://evaluation-service:8004"
  ANALYTICS_SERVICE_URL: "http://analytics-service:8005"

  AWS_REGION: "${AWS_REGION}"
  AWS_SQS_URL: "${sqs_url}"
  AWS_DYNAMODB_TABLE: "${DYNAMODB_TABLE}"

  AWS_SQS_ENDPOINT_URL: ""
  AWS_DYNAMODB_ENDPOINT_URL: ""

  AUTH_DATABASE_URL: "${auth_url}"
  FLAG_DATABASE_URL: "${flag_url}"
  TARGETING_DATABASE_URL: "${target_url}"
EOF

mv "$tmp" "$OUT"
trap - EXIT
echo "Escrito: $OUT (conta ${account}, regiao ${AWS_REGION})"
