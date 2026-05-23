# Epico 3 - GitOps, Argo CD e ambiente efemero

Guia operacional para **subir infra → validar/gravar → destruir**, sem manter o cluster ligado o tempo todo. A configuracao desejada fica no **Git** (`gitops/`); o que some no `terraform destroy` e recriado com scripts.

Documentos relacionados:

- Status por epico: [roteiro-fase3-status.md](roteiro-fase3-status.md)
- Checklist unificado: [checklist-roteiro-fase3.md](checklist-roteiro-fase3.md)
- Pasta GitOps: [../gitops/README.md](../gitops/README.md)
- CI (Epico 2): [epico2-ci-devsecops-operacao.md](epico2-ci-devsecops-operacao.md)

---

## Modelo efemero (o que some vs o que permanece)

| Some no `terraform destroy` | Permanece no repositorio / GitHub |
|---------------------------|-----------------------------------|
| EKS, node groups | `gitops/` (manifests) |
| RDS, Redis, SQS, DynamoDB (endpoints mudam no proximo apply) | Workflows CI |
| Argo CD (pods no cluster) | Imagens no ECR (ate apagar manualmente) |
| Secret `aws-credentials` no cluster | `gitops/scripts/sync-configmap-from-aws.sh` |
| Estado dos pods | Backend Terraform S3 (`556939139551-togglemaster-tfstate`) |

**Regra:** apos cada `terraform apply`, rode o script de ConfigMap com endpoints **novos** da AWS. Nao reutilize hostnames RDS de uma sessao anterior no `configmap.yaml` commitado.

---

## Nomes e convencoes (Terraform)

| Recurso | Valor tipico |
|---------|----------------|
| Cluster EKS | `togglemaster-eks-homolog` (`eks_cluster_name` + `environment`) |
| Regiao | `us-east-1` |
| Conta (Academy) | `556939139551` |
| RDS identifiers | `togglemaster-homolog-auth-db`, `-flag-db`, `-targeting-db` |
| Redis cluster id | `togglemaster-homolog-redis` |
| Fila SQS | `togglemaster-analytics-queue` |
| Namespace apps | `togglemaster` |
| Tag de imagem CI | SHA curto do commit (ex.: `22809c3`) — **nao** assumir `latest` |

**Senha RDS:** `rds_master_password` em `terraform.tfvars` deve ser **igual** a `POSTGRES_PASSWORD` em `gitops/cluster/app-secrets.yaml` (base64 `Togglemaster123` no exemplo atual) e ao valor usado em `sync-configmap-from-aws.sh`.

**Postgres no RDS:** URLs usam `sslmode=require` e database `togglemaster_homolog_auth` / `_flag` / `_targeting` (nome gerado pelo Terraform).

---

## Sessao completa (gravacao ou teste)

### Fase A — Credenciais e infra (fora do cluster)

1. Atualizar `~/.aws/credentials` no WSL (sessao Academy; incluir `aws_session_token`).
2. `aws sts get-caller-identity` deve retornar conta `556939139551`.
3. Subir infra: workflow **Terraform Apply Manual** ou `terraform apply` em `infra/terraform`.
4. Aguardar EKS **Active** e RDS **available**.

### Fase B — Imagens no ECR

5. Garantir secrets no GitHub Actions (Epico 2) e **push em `main`** que altere codigo dos servicos ou `service-ci-base.yml`, **ou** build/push manual.
6. Conferir tags: `aws ecr list-images --repository-name auth-service --region us-east-1`
7. Anotar a tag SHA (ex.: `22809c3`) para os cinco `gitops/apps/*/deployment.yaml`.

### Fase C — Bootstrap no cluster (script)

No WSL, na raiz do repo:

```bash
export RDS_MASTER_PASSWORD='mesma_senha_do_terraform_tfvars'
export ECR_IMAGE_TAG='22809c3'   # opcional; alinha deployments ao ECR
chmod +x docs/scripts/linux/bootstrap-epico3.sh
./docs/scripts/linux/bootstrap-epico3.sh
```

O script: `update-kubeconfig` → regenera ConfigMap → aplica `gitops/cluster` e `gitops/apps` → `update-aws-credentials.sh` → valida pods.

### Fase D — Argo CD (Epico 3 — pendente de fechar checklist)

8. Instalar Argo CD (uma vez por sessao de cluster):

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait -n argocd --for=condition=available deployment/argocd-server --timeout=300s
```

9. UI: `kubectl port-forward svc/argocd-server -n argocd 8080:443` → `https://localhost:8080` (user `admin`, senha em `argocd-initial-admin-secret`).

10. Criar `Application`(s) apontando para `gitops/cluster` e cada `gitops/apps/<servico>` (manifests em `gitops/argocd/` quando adicionados ao repo).

11. **Autosync** habilitado; **nao** versionar `aws-credentials` no Git (aplicar via script apos sync do cluster).

### Fase E — Demonstracao CI → GitOps → Argo

12. Job no CI que, apos push ECR, commita alteracao da linha `image:` em `gitops/apps/<servico>/deployment.yaml`.
13. Evidencia: print do commit + Argo CD **Synced/Healthy** nos 5 servicos.

### Fase F — Encerrar sessao

14. `terraform destroy` (workflow manual) para nao consumir creditos.
15. Credenciais Academy expiram; na proxima sessao repetir Fase A.

---

## Problemas comuns (ja vistos no projeto)

| Sintoma | Causa | Acao |
|---------|-------|------|
| `No cluster found for name: togglemaster-cluster` | Nome errado | Usar `togglemaster-eks-homolog` |
| Pods `Pending` com `nodeSelector` auto | EKS Auto Mode label inexistente | Removido dos manifests GitOps; reaplicar apps |
| `ImagePullBackOff` conta `154367514500` | Registry de exemplo | Usar `556939139551.dkr.ecr...` |
| `latest: not found` | CI publica so SHA | Tag `22809c3` (ou atual) nos deployments |
| `no such host` no RDS | ConfigMap antigo | `sync-configmap-from-aws.sh` apos apply |
| `no encryption` / `pg_hba` | RDS exige SSL | `?sslmode=require` nas DATABASE_URL |
| `password authentication failed` | Senha tfvars != secret/ConfigMap | Alinhar senha ou `modify-db-instance` |
| Argo sobrescreve AWS keys | `aws-credentials` vazio no Git | Secret so via `update-aws-credentials.sh` |

---

## Estrutura `gitops/`

```
gitops/
  cluster/          # namespace, app-secrets, configmap, ingress, hpa
  apps/
    auth-service/   # deployment.yaml (CI altera image:), service.yaml
    ...
  scripts/
    sync-configmap-from-aws.sh
  argocd/           # (futuro) Applications e bootstrap Argo
```

Deployments **nao** usam `nodeSelector: eks.amazonaws.com/compute-type: auto` (node group padrao do Terraform).

---

## Checklist rapido Epico 3 (fechar epico)

- [x] Pasta GitOps no repositorio
- [x] Validacao manual no EKS (`kubectl`, pods 1/1 com ConfigMap correto)
- [x] Script regenerar ConfigMap apos apply
- [x] Script bootstrap de sessao (`docs/scripts/linux/bootstrap-epico3.sh`)
- [ ] Argo CD instalado no EKS
- [ ] 5 Applications + cluster (ou app-of-apps)
- [ ] CI atualiza tag no GitOps
- [ ] Autosync + evidencia UI
- [ ] Trecho no video: CI → Git → Argo sync

---

## Referencia de comandos (copiar na gravacao)

```bash
# Kubeconfig
aws eks update-kubeconfig --region us-east-1 --name togglemaster-eks-homolog
kubectl get nodes

# ConfigMap dinamico
export RDS_MASTER_PASSWORD='***'
./gitops/scripts/sync-configmap-from-aws.sh
kubectl apply -f gitops/cluster/configmap.yaml

# Credenciais pods AWS
./docs/scripts/linux/update-aws-credentials.sh

# Status
kubectl get pods,deploy -n togglemaster
```
