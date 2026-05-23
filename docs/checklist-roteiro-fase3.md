# Checklist Unificado - Roteiro Fase 3

Checklist consolidado a partir de:

- `docs/roteiro-fase3-status.md`
- `docs/fase3-setup-checklist.md`
- `docs/epico3-gitops-operacao.md`
- `docs/step-by-step.md` (secao de roteiro de video)

---

## 0) Modelo efemero (ler antes de comecar)

- [ ] Entender: cluster/Argo CD/RDS endpoints **somem** no destroy; **Git** (`gitops/`) permanece
- [ ] A cada sessao: credenciais novas → apply → bootstrap → (Argo) → destroy
- [ ] Cluster EKS correto: **`togglemaster-eks-homolog`** (nao `togglemaster-cluster`)
- [ ] Guia de sessao: [epico3-gitops-operacao.md](epico3-gitops-operacao.md)

---

## 1) Preparacao de ambiente e credenciais

- [ ] Confirmar AWS Account e regiao (`556939139551`, `us-east-1`)
- [ ] Validar roles EKS (`eks_cluster_role_arn`, `eks_node_role_arn`)
- [ ] Criar bucket de state Terraform (bootstrap do backend remoto)
- [ ] Criar `infra/terraform/terraform.tfvars` a partir do exemplo
- [ ] Preencher `rds_master_username` e `rds_master_password` (mesma senha em `gitops/cluster/app-secrets.yaml`)
- [ ] Configurar secrets no GitHub Actions:
  - [ ] `AWS_REGION`
  - [ ] `AWS_ACCOUNT_ID`
  - [ ] `AWS_ACCESS_KEY_ID`
  - [ ] `AWS_SECRET_ACCESS_KEY`
  - [ ] `AWS_SESSION_TOKEN` (quando aplicavel)
- [ ] WSL: `~/.aws/credentials` com session token (nao misturar com PowerShell sem CLI)

---

## 2) Epico 1 - Terraform e Infra

- [ ] Rodar `terraform init`
- [ ] Rodar `terraform validate`
- [ ] Rodar `terraform plan`
- [ ] Confirmar workflow `Terraform Validate Plan`
- [ ] Confirmar workflow `Terraform Apply Manual`
- [ ] Confirmar workflow `Terraform Destroy Manual`
- [ ] Validar recursos apos apply:
  - [ ] EKS `togglemaster-eks-homolog`
  - [ ] 3x RDS (`togglemaster-homolog-*-db`)
  - [ ] ElastiCache Redis `togglemaster-homolog-redis`
  - [ ] DynamoDB
  - [ ] SQS `togglemaster-analytics-queue`
  - [ ] 5x ECR
- [ ] Validar limpeza completa no destroy

---

## 3) Epico 2 - CI DevSecOps

- [ ] Executar pipeline de cada servico e ajustar falhas:
  - [ ] `auth-service-ci`
  - [ ] `evaluation-service-ci`
  - [ ] `flag-service-ci`
  - [ ] `targeting-service-ci`
  - [ ] `analytics-service-ci`
- [ ] Confirmar gates sem bypass (lint/test/SAST/SCA)
- [ ] Confirmar push no ECR para os 5 servicos
- [ ] Padronizar tag de imagem (`<service>:<sha-curto>`)
- [ ] Evidenciar bloqueio por vulnerabilidade critica
- [ ] Coletar evidencia de pipeline falhando e depois passando
- [ ] Documentacao: [epico2-ci-devsecops-operacao.md](epico2-ci-devsecops-operacao.md)

---

## 4) Epico 3 - GitOps e ArgoCD

### GitOps no repositorio (feito / manter)

- [x] Pasta `gitops/` (`cluster/`, `apps/<servico>/`)
- [x] `gitops/scripts/sync-configmap-from-aws.sh`
- [x] `docs/scripts/linux/bootstrap-epico3.sh`
- [x] `docs/epico3-gitops-operacao.md`
- [x] Secret `aws-credentials` **nao** versionado no Git

### Por sessao (apos terraform apply)

- [ ] `aws eks update-kubeconfig --name togglemaster-eks-homolog`
- [ ] `export RDS_MASTER_PASSWORD=...` + `./gitops/scripts/sync-configmap-from-aws.sh`
- [ ] `./docs/scripts/linux/bootstrap-epico3.sh` (ou apply manual na ordem do `gitops/README.md`)
- [ ] Tags ECR corretas em `gitops/apps/*/deployment.yaml` (`ECR_IMAGE_TAG` no bootstrap)
- [ ] `./docs/scripts/linux/update-aws-credentials.sh`
- [ ] `kubectl get pods -n togglemaster` — 5 deployments **1/1**

### Fechar epico (pendente)

- [ ] Instalar ArgoCD no EKS
- [ ] Configurar Applications para cluster + 5 servicos
- [ ] Habilitar autosync (prune/self-heal conforme politica)
- [ ] Integrar CI para atualizar tag no GitOps (commit em `main`)
- [ ] Validar sync automatico ponta a ponta (UI Argo CD)
- [ ] Print/evidencia para relatorio e video

---

## 5) Entregaveis obrigatorios da Fase 3

- [ ] 5 pipelines verdes com execucao comprovada
- [ ] 5 imagens no ECR com tag de commit
- [ ] Evidencia do gate de seguranca bloqueando PR/build
- [ ] Documentacao de operacao Epico 2 e Epico 3
- [ ] Roteiro de sessao efemera documentado e testado uma vez

---

## 6) Checklist de demonstracao (roteiro de video)

Ordem sugerida para gravacao (~20 min):

- [ ] (Opcional) `docker-compose` local
- [ ] `terraform plan` / apply ou recursos na console
- [ ] Cluster EKS Active + `kubectl get nodes`
- [ ] Bootstrap: ConfigMap sync + pods **Running**
- [ ] Pipeline CI falhando (seguranca) e depois passando
- [ ] CI atualiza tag no `gitops/` (commit visivel)
- [ ] Argo CD: 5 apps **Synced** apos mudanca no Git
- [ ] (Opcional) curl no Ingress / HPA / DynamoDB
- [ ] Explicar LabRole, RDS/Redis/DynamoDB, modelo efemero
- [ ] Mencionar `terraform destroy` ao encerrar

---

## 7) Evidencias a anexar no final

- [ ] Prints/links dos workflows verdes
- [ ] URI + tags das imagens no ECR
- [ ] Print do bloqueio de seguranca (gate)
- [ ] Print do ArgoCD sincronizando (5 microsservicos)
- [ ] Print/video curto do autoscaling (HPA) — opcional
- [ ] Print estimativa de custos AWS (relatorio)

---

## 8) Encerramento da sessao (economia de creditos)

- [ ] Workflow **Terraform Destroy Manual** ou `terraform destroy`
- [ ] Confirmar que nao restam recursos caros (EKS, RDS, NAT) na conta
- [ ] Anotar tag ECR e commit GitOps usados na gravacao (reproducao)
