#!/usr/bin/env bash
# Instala Argo CD no EKS e registra Applications do GitOps (Epico 3).
# Pre-requisito: terraform apply concluido, kubeconfig apontando para togglemaster-eks-homolog.
#
# Uso (raiz do repo):
#   export RDS_MASTER_PASSWORD='senha_tfvars'   # recomendado: sync ConfigMap antes
#   export ECR_IMAGE_TAG='22809c3'              # opcional, se gitops ainda nao tem tag certa
#   ./docs/scripts/linux/install-argocd.sh
#
# Variaveis:
#   EKS_CLUSTER_NAME (default: togglemaster-eks-homolog)
#   AWS_REGION (default: us-east-1)
#   ARGOCD_INSTALL_URL (default: stable install manifest)
#   SKIP_CONFIGMAP_SYNC=1
#   SKIP_BOOTSTRAP_APPS=1   # se apps ja estao no cluster via kubectl

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)"
cd "$ROOT"

EKS_CLUSTER_NAME="${EKS_CLUSTER_NAME:-togglemaster-eks-homolog}"
AWS_REGION="${AWS_REGION:-us-east-1}"
ARGOCD_INSTALL_URL="${ARGOCD_INSTALL_URL:-https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml}"

echo "=========================================="
echo "Instalacao Argo CD + Applications"
echo "Cluster: $EKS_CLUSTER_NAME"
echo "=========================================="

for cmd in aws kubectl; do
  command -v "$cmd" >/dev/null || { echo "ERRO: $cmd nao encontrado"; exit 1; }
done

aws eks update-kubeconfig --region "$AWS_REGION" --name "$EKS_CLUSTER_NAME"

if [[ "${SKIP_CONFIGMAP_SYNC:-}" != "1" ]] && [[ -n "${RDS_MASTER_PASSWORD:-${POSTGRES_PASSWORD:-}}" ]]; then
  echo ""
  echo "[1/6] Sincronizando ConfigMap com AWS..."
  chmod +x "$ROOT/gitops/scripts/sync-configmap-from-aws.sh"
  "$ROOT/gitops/scripts/sync-configmap-from-aws.sh"
else
  echo ""
  echo "[1/6] Pulando sync ConfigMap (defina RDS_MASTER_PASSWORD ou SKIP_CONFIGMAP_SYNC=1)."
fi

if [[ "${SKIP_BOOTSTRAP_APPS:-}" != "1" ]]; then
  echo ""
  echo "[2/6] Bootstrap workloads (kubectl) antes do Argo assumir..."
  chmod +x "$ROOT/docs/scripts/linux/bootstrap-epico3.sh"
  export SKIP_CONFIGMAP_SYNC=1
  "$ROOT/docs/scripts/linux/bootstrap-epico3.sh"
else
  echo ""
  echo "[2/6] SKIP_BOOTSTRAP_APPS=1 — pulando bootstrap kubectl."
fi

echo ""
echo "[3/6] Instalando Argo CD..."
kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
kubectl apply -n argocd -f "$ARGOCD_INSTALL_URL"

echo ""
echo "[4/6] Aguardando Argo CD server..."
kubectl wait -n argocd --for=condition=available deployment/argocd-server --timeout=600s

echo ""
echo "[5/6] Registrando AppProject e Applications..."
kubectl apply -f "$ROOT/gitops/argocd/app-project.yaml"
kubectl apply -f "$ROOT/gitops/argocd/applications/"

echo ""
echo "[6/6] Aguardando sync inicial (ate 3 min)..."
sleep 15
kubectl get applications -n argocd
kubectl get pods -n togglemaster

echo ""
echo "=========================================="
echo "Argo CD instalado."
echo ""
echo "UI (outro terminal):"
echo "  kubectl port-forward svc/argocd-server -n argocd 8080:443"
echo "  https://localhost:8080  (user: admin)"
echo "  Senha: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo"
echo ""
echo "Credenciais AWS nos pods (se ainda nao fez):"
echo "  ./docs/scripts/linux/update-aws-credentials.sh"
echo "=========================================="
