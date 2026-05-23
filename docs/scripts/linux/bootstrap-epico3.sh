#!/usr/bin/env bash
# Bootstrap de uma sessao Epico 3: cluster novo ou recriado apos terraform apply.
# Uso (WSL, na raiz do repositorio):
#   export RDS_MASTER_PASSWORD='mesma_senha_do_terraform_tfvars'
#   export ECR_IMAGE_TAG='22809c3'   # opcional
#   ./docs/scripts/linux/bootstrap-epico3.sh
#
# Variaveis opcionais:
#   EKS_CLUSTER_NAME  (default: togglemaster-eks-homolog)
#   AWS_REGION        (default: us-east-1)
#   AWS_ACCOUNT_ID    (default: 556939139551)
#   SKIP_CONFIGMAP_SYNC=1
#   SKIP_AWS_CREDENTIALS=1

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-togglemaster-eks-homolog}"
AWS_REGION="${AWS_REGION:-us-east-1}"
AWS_ACCOUNT_ID="${AWS_ACCOUNT_ID:-556939139551}"
ECR_REGISTRY="${AWS_ACCOUNT_ID}.dkr.ecr.${AWS_REGION}.amazonaws.com"

echo "=========================================="
echo "Bootstrap Epico 3 - ToggleMaster"
echo "Repo: $ROOT"
echo "Cluster: $EKS_CLUSTER_NAME"
echo "=========================================="

for cmd in aws kubectl; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "ERRO: '$cmd' nao encontrado no PATH." >&2
    exit 1
  fi
done

echo ""
echo "[1/7] Validando credenciais AWS..."
aws sts get-caller-identity

echo ""
echo "[2/7] Configurando kubectl..."
aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME"
kubectl get nodes

if [[ "${SKIP_CONFIGMAP_SYNC:-}" != "1" ]]; then
  echo ""
  echo "[3/7] Regenerando gitops/cluster/configmap.yaml..."
  export RDS_MASTER_PASSWORD="${RDS_MASTER_PASSWORD:-${POSTGRES_PASSWORD:-}}"
  if [[ -z "${RDS_MASTER_PASSWORD}" ]]; then
    echo "AVISO: RDS_MASTER_PASSWORD nao definido; pulando sync-configmap (use ConfigMap ja commitado ou defina a variavel)." >&2
  else
    chmod +x "$ROOT/gitops/scripts/sync-configmap-from-aws.sh"
    "$ROOT/gitops/scripts/sync-configmap-from-aws.sh"
  fi
else
  echo ""
  echo "[3/7] SKIP_CONFIGMAP_SYNC=1 — pulando regeneracao do ConfigMap."
fi

echo ""
echo "[4/7] Aplicando manifests gitops/cluster..."
kubectl apply -f "$ROOT/gitops/cluster/00-namespace.yaml"
kubectl apply -f "$ROOT/gitops/cluster/app-secrets.yaml"
kubectl apply -f "$ROOT/gitops/cluster/configmap.yaml"
kubectl apply -f "$ROOT/gitops/cluster/ingress.yaml"
kubectl apply -f "$ROOT/gitops/cluster/evaluation-hpa.yaml"

echo ""
echo "[5/7] Aplicando gitops/apps (microsservicos)..."
if [[ -n "${ECR_IMAGE_TAG:-}" ]]; then
  echo "    Tag ECR: $ECR_IMAGE_TAG"
  for svc in auth-service flag-service targeting-service evaluation-service analytics-service; do
    dep="$ROOT/gitops/apps/$svc/deployment.yaml"
    if [[ -f "$dep" ]]; then
      sed -i "s|${ECR_REGISTRY}/${svc}:.*|${ECR_REGISTRY}/${svc}:${ECR_IMAGE_TAG}|g" "$dep"
    fi
  done
fi

for svc in auth-service flag-service targeting-service evaluation-service analytics-service; do
  kubectl apply -f "$ROOT/gitops/apps/$svc/"
done

if [[ "${SKIP_AWS_CREDENTIALS:-}" != "1" ]]; then
  echo ""
  echo "[6/7] Aplicando aws-credentials no cluster..."
  chmod +x "$ROOT/docs/scripts/linux/update-aws-credentials.sh"
  "$ROOT/docs/scripts/linux/update-aws-credentials.sh"
else
  echo ""
  echo "[6/7] SKIP_AWS_CREDENTIALS=1 — pulando secret aws-credentials."
fi

echo ""
echo "[7/7] Aguardando pods (ate 120s)..."
kubectl wait --for=condition=ready pod -l app=auth-service -n togglemaster --timeout=120s 2>/dev/null || true
kubectl get pods -n togglemaster
kubectl get deployment -n togglemaster

echo ""
echo "=========================================="
echo "Bootstrap concluido."
echo "Proximos passos (Epico 3):"
echo "  - Instalar Argo CD (ver docs/epico3-gitops-operacao.md)"
echo "  - CI atualizar tag em gitops/apps/*/deployment.yaml"
echo "  - Evidencia: Argo CD UI com 5 apps Synced"
echo "=========================================="
