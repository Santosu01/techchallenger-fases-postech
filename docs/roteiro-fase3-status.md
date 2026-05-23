# Roteiro Fase 3 - Organizado por Epico

Este roteiro segue os requisitos oficiais do Tech Challenge e marca com check tudo que ja foi concluido.

**Checklist operacional:** [checklist-roteiro-fase3.md](checklist-roteiro-fase3.md) | **GitOps / sessao efemera:** [epico3-gitops-operacao.md](epico3-gitops-operacao.md)

## Premissas de ambiente (AWS Academy x Conta Pessoal)

- [x] Regra documentada: em AWS Academy nao criar IAM Roles/Policies via Terraform
- [x] Uso de LabRole para EKS e Node Groups considerado no projeto
- [x] Alternativa documentada: em conta pessoal e permitido criar IAM via Terraform

## Ambiente efemero (subir → testar/gravar → destroy)

Infra **nao fica ligada o tempo todo**. O que permanece e o **Git** (`gitops/`, CI, Terraform state no S3). A cada nova sessao:

1. Credenciais AWS Academy no WSL (`~/.aws/credentials`)
2. `terraform apply` (ou workflow manual)
3. Push/confirmar imagens no ECR (tag SHA)
4. `./docs/scripts/linux/bootstrap-epico3.sh` (ConfigMap dinamico + apps + aws-credentials)
5. Instalar/configurar Argo CD (quando fechar Epico 3)
6. `terraform destroy` ao terminar

Guia completo: [epico3-gitops-operacao.md](epico3-gitops-operacao.md)

| Recurso | Nome correto (nao usar docs antigos `togglemaster-cluster`) |
|---------|--------------------------------------------------------------|
| Cluster EKS | `togglemaster-eks-homolog` |
| Regiao | `us-east-1` |

---

## Epico 1 - Infraestrutura como Codigo (Terraform)
**Status geral:** Concluido

### Escopo obrigatorio do epico
- [x] Projeto Terraform organizado em modulos (`network`, `eks`, `data`, `ecr`)
- [x] Networking provisionado por codigo (VPC/Subnets/IGW/Routes)
- [x] Cluster EKS e Node Groups provisionados por codigo
- [x] 3 instancias RDS PostgreSQL provisionadas
- [x] ElastiCache Redis provisionado
- [x] Tabela DynamoDB provisionada
- [x] Fila SQS provisionada
- [x] 5 repositorios ECR provisionados

### Requisito de estado remoto
- [x] `terraform.tfstate` fora do ambiente local (backend remoto S3)
- [x] Backend remoto validado em execucao real

### Automacao e validacao
- [x] Workflow `Terraform Validate Plan` funcionando
- [x] Workflow `Terraform Apply Manual` funcionando
- [x] Workflow `Terraform Destroy Manual` funcionando
- [x] Apply validado com criacao dos recursos principais
- [x] Destroy validado com limpeza completa

---

## Epico 2 - CI + DevSecOps
**Status geral:** Em andamento

### Requisitos de pipeline por microsservico
- [x] Workflows criados para os 5 microsservicos
- [x] Base reutilizavel em `service-ci-base.yml`
- [x] Jobs base definidos: build/test, lint, SAST/SCA, docker
- [x] Pipeline rodando automaticamente em Pull Request
- [x] Pipeline rodando automaticamente em Push na `main`

### Estagios tecnicos obrigatorios
- [x] Build e Unit Test validados nos 5 servicos
- [x] Linter/Static Analysis validados nos 5 servicos
- [x] SCA de dependencias validado nos 5 servicos
- [x] SAST de codigo validado nos 5 servicos
- [x] Regra de bloqueio por vulnerabilidade CRITICA comprovada
- [x] Docker build com scan de imagem (Trivy) validado
- [x] Login no ECR validado
- [x] Push no ECR com tag por hash de commit validado

### Evidencias e entregaveis do epico
- [x] Execucoes recentes dos 5 workflows com sucesso (conforme rodada exibida)
- [x] 5 imagens no ECR com tag padronizada (ex: `<service>:<sha-curto>`)
  - [x] `auth-service:e4de419` (`sha256:55920c0348a449f2c189ebe2e12e2e9f0971f3782ba33d5ee567296476e3a61d`)
  - [x] `evaluation-service:e4de419` (`sha256:4ec09b273cef66b65c2e6589a7aaa2d9b03774fbca3a39d80ea4a0604487e965`)
  - [x] `flag-service:e4de419` (`sha256:de7b70923ef6b376024f316a78e9b716dc72d2ed4b02678c7fc44cbdf5888d6e`)
  - [x] `targeting-service:e4de419` (`sha256:e192de86eb4e65defd332fcc2d38bb420412eda504f030df9e3f459e08d569f2`)
  - [x] `analytics-service:e4de419` (`sha256:8bc16b469866e2eb58324736f339ab609d62ecc83006073c8ac62e20aa6a640c`)
- [x] Evidencia de falha do gate de seguranca e posterior correcao
- [x] Documentacao curta de execucao e leitura de falhas (`docs/epico2-ci-devsecops-operacao.md`)

### Observacoes
- Build/Lint/Test/SAST/SCA podem ser executados sem AWS ativa
- Push para ECR depende de AWS ativa e credenciais validas

---

## Epico 3 - CD + GitOps (ArgoCD)
**Status geral:** Concluido no cluster (Argo CD + 5 servicos Synced/Healthy). Pendente: evidencia de video (CI→Git→Argo) e ingress/HPA opcionais.

**Documentacao:** [epico3-gitops-operacao.md](epico3-gitops-operacao.md) | **Bootstrap:** `docs/scripts/linux/bootstrap-epico3.sh` | **Argo CD:** `docs/scripts/linux/install-argocd.sh` | **ECR local:** `docs/scripts/linux/push-all-ecr.sh` | **ConfigMap AWS:** `gitops/scripts/sync-configmap-from-aws.sh`

### Requisitos obrigatorios
- [x] Repositorio (ou pasta) GitOps definido com manifestos/Helm (`gitops/`, ver `gitops/README.md`)
- [x] Manifestos validados no EKS (apply manual / bootstrap; tag ECR ex.: `22809c3`, sem `nodeSelector` Auto Mode)
- [x] ConfigMap alinhavel apos cada `terraform apply` (script sync + `sslmode=require` + DB names Terraform)
- [x] `aws-credentials` fora do Git (`gitops/cluster/app-secrets.yaml` apenas; credenciais AWS via script)
- [x] Roteiro de sessao efemera documentado (subir → gravar → destroy)
- [x] Manifestos Argo CD no Git (`gitops/argocd/app-project.yaml` + 6 Applications)
- [x] CI atualizando automaticamente a tag da imagem no repositorio GitOps (`update_gitops` em `service-ci-base.yml`)
- [x] ArgoCD instalado no EKS (`docs/scripts/linux/install-argocd.sh`)
- [x] ArgoCD monitorando repositorio GitOps e sincronizando automaticamente (autosync prune/selfHeal)
- [x] Sync validado na UI: 5 microsservicos **Synced/Healthy** (maio/2026, cluster `togglemaster-eks-homolog`)
- [ ] Evidencia gravada: pipeline CI commita tag → Argo detecta e sincroniza (trecho do video)

### O que ja foi aprendido / corrigido (referencia)
- Registry ECR: conta `556939139551` (nao `154367514500` dos exemplos antigos)
- Imagem: tag do CI (SHA curto), nao `latest` vazio no ECR
- **ECR vazio apos novo `terraform apply`:** usar CI ou `./docs/scripts/linux/push-all-ecr.sh`
- RDS: hosts mudam a cada apply; regenerar ConfigMap obrigatorio
- Senha RDS: **obrigatorio** alinhar `TF_VAR_RDS_MASTER_PASSWORD` (GitHub), `app-secrets`, `RDS_MASTER_PASSWORD` no sync e `rds_master_password` no Terraform — se divergir, `password authentication failed` nos pods
- Scripts `.sh` no Windows/WSL: rodar `python3 docs/scripts/linux/fix-crlf.py` se aparecer erro `bash\r`
- `togglemaster-cluster` Application pode ficar **Progressing** sem NGINX Ingress Controller (ingress sem ADDRESS)

---

## Epico 4 (Estudo) - Observabilidade e Seguranca em Runtime
**Status geral:** Nao iniciado

### Objetivo do epico
- [ ] Adicionar visibilidade operacional e deteccao de ameacas em runtime no cluster EKS
- [ ] Consolidar aprendizado pratico de seguranca cloud-native apos GitOps

### Escopo sugerido (modo estudo)
- [ ] Opcao A (recomendada para estudo): Falco (open source) para deteccao em runtime
- [ ] Opcao B (comparativo de mercado): Sysdig (trial/SaaS), se disponivel
- [ ] Dashboards basicos de saude do cluster e workloads (CPU/Memoria/Restart/Erros)
- [ ] Regras iniciais de deteccao para eventos suspeitos em containers
- [ ] Alertas enviados para canal de notificacao (Slack/Webhook)

### Cenarios minimos para validacao
- [ ] Simular execucao de shell interativo em container e registrar alerta
- [ ] Simular pod com privilegio elevado e registrar alerta
- [ ] Simular comportamento anomalo simples (ex: acesso inesperado a binarios sensiveis)
- [ ] Evidenciar trilha de investigacao do incidente (evento -> alerta -> acao)

### Entregaveis do epico
- [ ] Guia de instalacao e operacao (`docs/epico4-runtime-security-operacao.md`)
- [ ] Evidencias (prints/logs) de pelo menos 3 deteccoes disparadas
- [ ] Tabela curta de tuning: falso positivo, ajuste aplicado e resultado
- [ ] Comparativo breve Falco x Sysdig para contexto academico

### Criterios de pronto
- [ ] Stack de deteccao em runtime ativa no EKS
- [ ] Pelo menos 3 regras relevantes validadas com evidencias
- [ ] Alertas chegando no canal definido
- [ ] Runbook simples de resposta documentado

---

## Entregaveis finais da Fase 3

### 1) Video de demonstracao (ate 20 min)
- [ ] IaC: mostrar `terraform plan` + `terraform apply` (ou recursos finais na AWS)
- [ ] DevSecOps: demonstrar pipeline falhando em seguranca e depois passando
- [ ] GitOps: mostrar pipeline atualizando tag no repositorio GitOps
- [ ] ArgoCD: sync automatico (5 apps ja validados Synced/Healthy — falta gravar)

### 2) Codigo fonte no repositorio
- [x] Codigo Terraform estruturado e componentizado
- [x] Workflows CI em `.github/workflows` com esteira base implementada
- [x] Job CI `update_gitops` (push ECR → commit em `gitops/apps/`)
- [x] Manifestos Kubernetes GitOps + Argo CD Applications
- [x] Scripts de operacao Epico 3 (bootstrap, install-argocd, push-all-ecr, fix-crlf)
- [x] Guia Epico 3 (`docs/epico3-gitops-operacao.md`)

### 3) Relatorio de entrega (PDF ou TXT)
- [ ] Nomes dos participantes
- [ ] Link da documentacao e do video
- [ ] Resumo dos desafios e decisoes tecnicas
- [ ] Print da estimativa de custos AWS
