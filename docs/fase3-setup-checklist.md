# Fase 3 - Checklist de Setup (Terraform + GitHub Actions)

Este arquivo lista os dados que faltam para fechar a configuracao real do Epico 1 e pipelines.

## Conta e regiao (ja definidos no projeto)

- **AWS Account ID:** `556939139551`
- **Regiao:** `us-east-1`

## 1) Terraform (obrigatorio)

- `aws_region` (ex: `us-east-1`)
- `aws_profile` (se usar perfil local)
- `eks_cluster_role_arn`
- `eks_node_role_arn`
- `rds_master_username`
- `rds_master_password`

Roles EKS da conta (ja validadas):

- `eks_cluster_role_arn`: `arn:aws:iam::556939139551:role/c208526a5300486l14867713t1w556939-LabEksClusterRole-2AFY32J2abPo`
- `eks_node_role_arn`: `arn:aws:iam::556939139551:role/c208526a5300486l14867713t1w556939139-LabEksNodeRole-HKbXTIoFsL6x`

### Backend remoto (S3 state)

O backend esta configurado em `infra/terraform/providers.tf` com o bucket:

- **`556939139551-togglemaster-tfstate`** (nome globalmente unico com prefixo da conta)

**Bootstrap obrigatorio:** o bucket precisa existir **antes** do primeiro `terraform init`. Crie no console AWS (S3) ou via CLI, com versionamento e bloqueio de acesso publico recomendados.

## 2) GitHub Actions (credenciais)

**Sim: o ideal e usar GitHub Secrets** (Settings > Secrets and variables > Actions > Repository secrets). Nunca commitar chaves no repositorio.

Secrets usados pelos workflows atuais (**nomes exatos**, case-sensitive):

| Secret no GitHub | Uso |
|------------------|-----|
| `AWS_REGION` | ex: `us-east-1` |
| `AWS_ACCOUNT_ID` | ex: `556939139551` (mesmo `sts get-caller-identity`) |
| `AWS_ACCESS_KEY_ID` | Credencial temporaria Academy |
| `AWS_SECRET_ACCESS_KEY` | Credencial temporaria Academy |
| `AWS_SESSION_TOKEN` | Obrigatorio no Academy (uma linha, sem aspas) |
| `TF_VAR_EKS_CLUSTER_ROLE_ARN` | **Nao** `TF_VAR_eks_cluster_role_arn` — ARN LabEksClusterRole |
| `TF_VAR_EKS_NODE_ROLE_ARN` | **Nao** `TF_VAR_eks_node_role_arn` — ARN LabEksNodeRole |
| `TF_VAR_RDS_MASTER_USERNAME` | ex: `postgres` |
| `TF_VAR_RDS_MASTER_PASSWORD` | mesma senha do `terraform.tfvars` local |

ARNs EKS validados na conta `556939139551` (copiar do IAM ou do exemplo se ainda existirem no lab):

- `TF_VAR_EKS_CLUSTER_ROLE_ARN`: `arn:aws:iam::556939139551:role/c208526a5300486l14867713t1w556939-LabEksClusterRole-2AFY32J2abPo`
- `TF_VAR_EKS_NODE_ROLE_ARN`: `arn:aws:iam::556939139551:role/c208526a5300486l14867713t1w556939139-LabEksNodeRole-HKbXTIoFsL6x`

Erro `Cross-account pass role is not allowed`: quase sempre **conta das keys AWS != conta no meio do ARN** (`arn:aws:iam::XXXXXXXXXXXX:role/...`) ou secret de role **vazio/nome errado**. O workflow **Terraform Apply Manual** agora valida isso antes do `terraform apply`.

Sem esses secrets, o pipeline executa build/lint/scans, mas o push no ECR e pulado.

**Melhor pratica (opcional, fase seguinte):** trocar chaves longas por **OIDC** (`aws-actions/configure-aws-credentials` com `role-to-assume`), sem `AWS_SECRET_ACCESS_KEY` no GitHub.

## 3) Recomendacoes imediatas

1. Copiar `infra/terraform/terraform.tfvars.example` para `infra/terraform/terraform.tfvars`.
2. Preencher os valores reais do ambiente.
3. Rodar localmente:
   - `terraform init`
   - `terraform validate`
   - `terraform plan`
4. Abrir PR para validar os 5 workflows em branch.

## 4) Senha RDS

Use uma senha forte em `terraform.tfvars` (arquivo local, listado no `.gitignore`). Nao coloque senha em issue/PR; compartilhe apenas pelo canal seguro do grupo se necessario.

Regras importantes do RDS para senha (`MasterUserPassword`):

- Nao pode conter: `/`, `@`, `"`, espaco
- Deve usar apenas caracteres ASCII imprimiveis permitidos
- Exemplo valido: `Togglemaster#1234`

## 5) Economia de creditos (Academy)

- Preferir ambiente efemero: subir para teste/demonstracao e destruir ao fim.
- Usar pipeline manual de destroy (sem cron) para evitar apagar ambiente em horario errado.

## 6) Epico 3 - GitOps (apos Epico 1 apply)

**Guia completo:** [epico3-gitops-operacao.md](epico3-gitops-operacao.md)

Resumo por sessao:

1. Credenciais WSL atualizadas (`aws sts get-caller-identity`).
2. Cluster: `togglemaster-eks-homolog` (nao `togglemaster-cluster`).
3. Imagens no ECR com tag SHA (CI em `main` ou push manual).
4. Bootstrap:

```bash
export RDS_MASTER_PASSWORD='mesma_senha_do_tfvars'
export ECR_IMAGE_TAG='sha_do_ecr'
./docs/scripts/linux/bootstrap-epico3.sh
```

5. Argo CD + Applications + CI atualizando `gitops/apps/*/deployment.yaml` (checklist em [roteiro-fase3-status.md](roteiro-fase3-status.md)).
6. `terraform destroy` ao terminar.

**Alinhamento de senha:** `rds_master_password` (tfvars) = `POSTGRES_PASSWORD` (Secret `app-secrets`) = variavel no `sync-configmap-from-aws.sh`.

**ConfigMap:** apos cada apply, hosts RDS/Redis mudam — sempre rodar `gitops/scripts/sync-configmap-from-aws.sh` antes de aplicar no cluster.
