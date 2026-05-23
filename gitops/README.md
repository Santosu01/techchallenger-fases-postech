# GitOps (ToggleMaster)

Manifests para **Argo CD** ou `kubectl apply`. O CI (Epico 3) deve atualizar a **tag** da imagem em `apps/<servico>/deployment.yaml`.

**Operacao (ambiente efemero, gravacao, troubleshooting):** [../docs/epico3-gitops-operacao.md](../docs/epico3-gitops-operacao.md)

**Bootstrap de uma sessao (apos `terraform apply`):**

```bash
export RDS_MASTER_PASSWORD='mesma_senha_do_terraform_tfvars'
export ECR_IMAGE_TAG='22809c3'   # tag existente no ECR; opcional
chmod +x ../docs/scripts/linux/bootstrap-epico3.sh
../docs/scripts/linux/bootstrap-epico3.sh
```

---

## Estrutura

| Caminho | Conteudo |
|---------|----------|
| `cluster/00-namespace.yaml` | Namespace `togglemaster` |
| `cluster/app-secrets.yaml` | Postgres + MASTER_KEY (base64) |
| `cluster/configmap.yaml` | RDS, Redis, SQS, URLs internas — **regenerar** apos cada apply |
| `cluster/ingress.yaml` | Ingress nginx |
| `cluster/evaluation-hpa.yaml` | HPA evaluation-service |
| `apps/<servico>/deployment.yaml` | Deployment; CI altera `image:` |
| `apps/<servico>/service.yaml` | Service ClusterIP |
| `scripts/sync-configmap-from-aws.sh` | Lê endpoints na AWS e reescreve `configmap.yaml` |

O Secret **`aws-credentials` nao esta** em `gitops/cluster/` (evita Argo CD sobrescrever credenciais de sessao). Use `docs/scripts/linux/update-aws-credentials.sh`.

---

## Ordem manual com `kubectl`

1. `kubectl apply -f gitops/cluster/00-namespace.yaml`
2. `kubectl apply -f gitops/cluster/app-secrets.yaml`
3. Regenerar e aplicar ConfigMap (ver script abaixo)
4. `kubectl apply -f gitops/cluster/ingress.yaml` e `evaluation-hpa.yaml`
5. `kubectl apply -f gitops/apps/<cada-servico>/`
6. `update-aws-credentials.sh`

---

## Regenerar `configmap.yaml` apos mudar infra na AWS

```bash
export RDS_MASTER_PASSWORD='sua_senha_rds'
chmod +x gitops/scripts/sync-configmap-from-aws.sh
./gitops/scripts/sync-configmap-from-aws.sh
kubectl apply -f gitops/cluster/configmap.yaml
kubectl rollout restart deployment -n togglemaster auth-service flag-service targeting-service
```

Variaveis opcionais: `PROJECT_NAME`, `ENVIRONMENT`, `AWS_REGION`, `SQS_QUEUE_NAME`, `DYNAMODB_TABLE`, `REDIS_TLS`, `CONFIGMAP_OUT`.

---

## Imagens ECR

- Registry: `556939139551.dkr.ecr.us-east-1.amazonaws.com/<servico>:<tag>`
- CI publica tag **SHA curto** (7 caracteres); nao assumir `latest` no ECR.
- Deployments **sem** `nodeSelector: eks.amazonaws.com/compute-type: auto` (node group Terraform).

---

## Argo CD (Epico 3 — em implementacao)

Pasta `gitops/argocd/` reservada para `Application` manifests. Instalacao e sync: ver [epico3-gitops-operacao.md](../docs/epico3-gitops-operacao.md).
