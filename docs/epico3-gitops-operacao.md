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

**Senha RDS:** deve ser **identica** em todos estes pontos:

| Onde | Variavel / campo |
|------|------------------|
| GitHub Actions (apply Terraform) | secret `TF_VAR_RDS_MASTER_PASSWORD` |
| Terraform local | `rds_master_password` em `terraform.tfvars` |
| Kubernetes | `POSTGRES_PASSWORD` em `gitops/cluster/app-secrets.yaml` |
| Script ConfigMap | `RDS_MASTER_PASSWORD` ao rodar `sync-configmap-from-aws.sh` |

Exemplo usado no projeto: `Togglemaster123` (base64 `VG9nZ2xlbWFzdGVyMTIz` no secret).

Se o Terraform foi aplicado com senha diferente do GitOps, os pods falham com `password authentication failed`. Corrigir alinhando o secret GitHub **antes** do proximo apply, ou temporariamente:

```bash
aws rds modify-db-instance --db-instance-identifier togglemaster-homolog-auth-db \
  --master-user-password 'SUA_SENHA' --apply-immediately --region us-east-1
# Repetir para -flag-db e -targeting-db
```

**Postgres no RDS:** URLs usam `sslmode=require` e database `togglemaster_homolog_auth` / `_flag` / `_targeting` (nome gerado pelo Terraform).

---

## Sessao completa (gravacao ou teste)

### Fase A — Credenciais e infra (fora do cluster)

1. Atualizar `~/.aws/credentials` no WSL (sessao Academy; incluir `aws_session_token`).
2. `aws sts get-caller-identity` deve retornar conta `556939139551`.
3. Subir infra: workflow **Terraform Apply Manual** ou `terraform apply` em `infra/terraform`.
4. Aguardar EKS **Active** e RDS **available**.

### Fase B — Imagens no ECR

5. Garantir imagens no ECR por **CI** (push em `main` que altere codigo dos servicos) **ou** script local:

```bash
# ECR vazio apos terraform apply? Build/push local (WSL + Docker):
export ECR_IMAGE_TAG='22809c3'   # ou SHA curto desejado
python3 docs/scripts/linux/fix-crlf.py   # se scripts vieram do Windows
chmod +x docs/scripts/linux/push-all-ecr.sh
./docs/scripts/linux/push-all-ecr.sh
```

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

### Fase D — Argo CD (`gitops/argocd/`)

8. **Push** para `main` no GitHub: pasta `gitops/argocd/` + demais `gitops/` (Argo le o repo remoto).

9. Instalar Argo CD + Applications:

```bash
export RDS_MASTER_PASSWORD='senha_tfvars'
export ECR_IMAGE_TAG='tag_no_ecr'
chmod +x docs/scripts/linux/install-argocd.sh
./docs/scripts/linux/install-argocd.sh
```

Detalhes: [../gitops/argocd/README.md](../gitops/argocd/README.md).

10. UI: `kubectl port-forward svc/argocd-server -n argocd 8080:443` → `https://localhost:8080` (user `admin`).

11. Validar **6 apps** na UI: `togglemaster-cluster` + 5 microsservicos — **Synced/Healthy**.

12. `./docs/scripts/linux/update-aws-credentials.sh` (evaluation/analytics).

### Fase E — Demonstracao CI → GitOps → Argo

13. Job `update_gitops` em `.github/workflows/service-ci-base.yml`: apos push ECR, commita a linha `image:` em `gitops/apps/<servico>/deployment.yaml` na branch `main`.
14. Evidencia para o video: print do commit `gitops: bump ...` + Argo CD **Synced/Healthy** nos 5 servicos.

### Fase F — Encerrar sessao

15. `terraform destroy` (workflow manual) para nao consumir creditos.
16. Credenciais Academy expiram; na proxima sessao repetir Fase A.

---

## Validacao realizada (referencia — maio/2026)

Sessao efemera concluida com sucesso no cluster `togglemaster-eks-homolog` (conta `556939139551`):

| Item | Resultado |
|------|-----------|
| Argo CD | Instalado (`install-argocd.sh`) |
| Applications | 6 registradas; 5 servicos **Synced/Healthy** |
| Pods | 5/5 Running (1/1 Ready) |
| Tag ECR | `22809c3` (build local via `push-all-ecr.sh` apos ECR vazio) |
| `togglemaster-cluster` app | Synced, **Progressing** (ingress sem IP — NGINX Ingress nao instalado) |

Comandos de verificacao:

```bash
kubectl get applications -n argocd
kubectl get pods -n togglemaster
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

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
| `password authentication failed` | Senha tfvars != secret/ConfigMap/GitHub secret | Alinhar tabela de senha RDS acima ou `modify-db-instance` |
| ECR sem imagens apos apply | Repos criados vazios pelo Terraform | CI ou `push-all-ecr.sh` |
| `bash\r: Permission denied` (WSL) | CRLF nos scripts `.sh` | `python3 docs/scripts/linux/fix-crlf.py` |
| Argo sobrescreve AWS keys | `aws-credentials` vazio no Git | Secret so via `update-aws-credentials.sh` |
| App cluster Progressing | Ingress sem controller / HPA sem metrics | Opcional: instalar ingress-nginx e metrics-server |

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
  argocd/           # AppProject + 6 Applications (branch main)
```

Scripts auxiliares em `docs/scripts/linux/`:

| Script | Uso |
|--------|-----|
| `bootstrap-epico3.sh` | ConfigMap + cluster + apps + aws-credentials |
| `install-argocd.sh` | Argo CD + Applications (inclui bootstrap) |
| `push-all-ecr.sh` | Build/push das 5 imagens quando ECR esta vazio |
| `fix-crlf.py` | Converte `.sh` para LF (WSL) |
| `update-aws-credentials.sh` | Secret `aws-credentials` nos pods AWS |

Deployments **nao** usam `nodeSelector: eks.amazonaws.com/compute-type: auto` (node group padrao do Terraform).

---

## Checklist rapido Epico 3

- [x] Pasta GitOps no repositorio
- [x] Validacao manual no EKS (`kubectl`, pods 1/1 com ConfigMap correto)
- [x] Script regenerar ConfigMap apos apply
- [x] Script bootstrap de sessao (`docs/scripts/linux/bootstrap-epico3.sh`)
- [x] Argo CD instalado no EKS
- [x] 5 Applications + cluster (6 apps com autosync)
- [x] CI atualiza tag no GitOps (`update_gitops`)
- [x] Autosync + evidencia UI (5 servicos Healthy)
- [ ] Trecho no video: CI → Git → Argo sync (gravacao)

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
