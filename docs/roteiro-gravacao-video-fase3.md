# Roteiro de gravacao — Video Fase 3 (ToggleMaster)

**Duracao alvo:** 15–20 minutos  
**Publico:** avaliadores Tech Challenge  
**Repositorio:** `https://github.com/Santosu01/techchallenger-fase-2`  
**Referencias:** [roteiro-fase3-status.md](roteiro-fase3-status.md) | [epico3-gitops-operacao.md](epico3-gitops-operacao.md) | [epico2-ci-devsecops-operacao.md](epico2-ci-devsecops-operacao.md)

---

## Antes de gravar (checklist)

| Item | Onde conferir |
|------|----------------|
| Infra ligada (EKS, RDS, ECR, etc.) ou gravar o `terraform apply` ao vivo | AWS Console / workflow **Terraform Apply Manual** |
| Credenciais Academy validas (WSL + secrets GitHub Actions) | `aws sts get-caller-identity` |
| Cluster `togglemaster-eks-homolog`, regiao `us-east-1`, conta `556939139551` | `kubectl get nodes` |
| Senha RDS igual em Terraform secret, `app-secrets` e sync | Sem `password authentication failed` nos pods |
| Imagens no ECR (tag recente, ex. `1194f82` ou `faff57f`) | Console ECR ou `aws ecr list-images` |
| Argo CD instalado, 5 servicos **Synced/Healthy** | UI `https://localhost:8080` (port-forward) |
| `togglemaster-cluster` **Progressing** e aceitavel | Explicar ingress sem controller (roteiro abaixo) |
| Tela limpa: fechar abas irrelevantes, fonte legivel, notificacoes off | — |

**Abrir antes (abas sugeridas):** GitHub Actions, GitHub Commits em `main`, Argo CD UI, AWS Console (EKS/ECR), terminal WSL com kubeconfig.

---

## Estrutura do video (mapa)

| Bloco | Tempo | Obrigatorio enunciado |
|-------|-------|------------------------|
| 1. Abertura e arquitetura | 1–2 min | Sim |
| 2. IaC — Terraform | 3–4 min | Sim |
| 3. CI / DevSecOps | 4–5 min | Sim |
| 4. GitOps + Argo CD | 5–6 min | Sim |
| 5. Encerramento (efemero + custos) | 1–2 min | Recomendado |

---

## Bloco 1 — Abertura (1–2 min)

**Tela:** slide simples ou README do repo.

**Fala sugerida:**

> "Este video demonstra a Fase 3 do Tech Challenge — projeto ToggleMaster. Cobrimos infraestrutura como codigo com Terraform, pipelines de CI com DevSecOps para cinco microsservicos, e entrega continua com GitOps e Argo CD no Amazon EKS. O ambiente e efemero: subimos a infra para gravar e depois fazemos destroy para controlar custos na AWS Academy."

**Mostrar (10 s):** estrutura do repo — `infra/terraform/`, `.github/workflows/`, `gitops/`, `backend-services/`.

---

## Bloco 2 — Epico 1: Terraform / IaC (3–4 min)

### Cena 2.1 — Codigo modular (1 min)

**Tela:** VS Code — `infra/terraform/main.tf` e pastas `modules/{network,eks,data,ecr}`.

**Fala:**

> "O Terraform esta organizado em modulos: rede, EKS, dados — RDS, Redis, DynamoDB, SQS — e cinco repositorios ECR. O state fica remoto no S3, nao no laptop."

**Destacar:** `versions.tf` (backend S3), `terraform.tfvars.example` (senha RDS documentada).

### Cena 2.2 — Plan / Apply (2 min)

**Opcao A — ao vivo (mais forte):** terminal ou GitHub Actions → workflow **Terraform Apply Manual** → run recente ou disparar com comentario.

**Opcao B — recursos ja criados:** AWS Console → EKS `togglemaster-eks-homolog`, 3 RDS, ElastiCache, SQS, DynamoDB, ECR.

**Fala:**

> "No apply provisionamos VPC, cluster EKS com node group, tres PostgreSQL, Redis, fila SQS, tabela DynamoDB e os repositorios ECR. Em AWS Academy usamos roles pre-existentes — LabRole — configuradas via secrets no GitHub, sem criar IAM customizado no Terraform."

**Evidencia:** print ou clip do workflow verde **Terraform Validate Plan** + **Apply Manual**.

### Cena 2.3 — Kubeconfig (30 s)

**Tela:** terminal WSL.

```bash
aws sts get-caller-identity
aws eks update-kubeconfig --region us-east-1 --name togglemaster-eks-homolog
kubectl get nodes
```

**Fala:** "Cluster ativo com dois nodes Ready."

---

## Bloco 3 — Epico 2: CI e DevSecOps (4–5 min)

### Cena 3.1 — Pipeline por servico (1 min)

**Tela:** GitHub → Actions → ex. **Auth Service CI**.

**Fala:**

> "Cada microsservico tem workflow proprio que reutiliza `service-ci-base.yml`: build e testes, lint, SAST, SCA, build de imagem Docker, scan Trivy, push para ECR com tag igual ao SHA curto do commit."

**Mostrar:** grafo do workflow com jobs `build_test`, `container_scan`, `push_ecr`, `update_gitops`.

### Cena 3.2 — Gate de seguranca (1,5 min) — obrigatorio

**Tela:** run antiga que **falhou** (Trivy CRITICAL ou SAST) **ou** PR comentario/check vermelho.

**Fala:**

> "O pipeline falha de proposito quando ha vulnerabilidade critica — aqui o Trivy bloqueou o build. Apos corrigir a dependencia ou o Dockerfile, o mesmo pipeline passa."

**Depois:** run **verde** do mesmo servico (comparacao lado a lado ou sequencia).

### Cena 3.3 — Imagens no ECR (1 min)

**Tela:** AWS Console → ECR → `auth-service` (repetir mencao dos 5).

**Fala:**

> "As imagens nao usam latest vazio: cada push gera tag como `1194f82`, sete caracteres do commit, na conta `556939139551`."

### Cena 3.4 — (Opcional) Push local se ECR vazio

So se quiser mencionar sessao efemera:

> "Apos um novo terraform apply os repos ECR podem estar vazios; usamos o script `push-all-ecr.sh` ou o proprio CI."

---

## Bloco 4 — Epico 3: GitOps e Argo CD (5–6 min) — nucleo da nota

### Cena 4.1 — Repositorio GitOps (1 min)

**Tela:** GitHub → pasta `gitops/`.

**Fala:**

> "O Git e a fonte da verdade: `gitops/cluster` para namespace, secrets de app, configmap, ingress e HPA; `gitops/apps` um diretorio por microsservico. O ConfigMap e regenerado apos cada apply com endpoints novos do RDS via script sync. Credenciais AWS dos pods nao ficam no Git — aplicamos com `update-aws-credentials.sh`."

**Mostrar:** linha `image:` em `gitops/apps/auth-service/deployment.yaml`.

### Cena 4.2 — CI atualiza o Git (1,5 min) — obrigatorio

**Tela:** GitHub → Commits em `main` — filtrar mensagens `gitops: bump`.

**Fala:**

> "Depois do push no ECR, o job `update_gitops` commita automaticamente a nova tag no manifest. Varios servicos rodam em paralelo; usamos fila `gitops-update-main` e rebase para evitar conflito no push."

**Mostrar:** diff de um commit — tag antiga → tag nova (ex. `22809c3` → `1194f82`).

**Opcional:** reexecutar um workflow ou mostrar o commit `fix(ci): serializa update_gitops` como contexto tecnico (30 s).

### Cena 4.3 — Argo CD (2 min) — obrigatorio

**Preparar terminal 2:**

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

**Tela:** browser `https://localhost:8080` — login `admin` (senha do secret).

**Fala:**

> "Instalamos o Argo CD com `install-argocd.sh`, que registra seis Applications: um para o cluster compartilhado e cinco para os microsservicos. Autosync com prune e self-heal esta habilitado."

**Mostrar na UI:**

1. Lista de apps: `auth-service`, `flag-service`, … — **Synced + Healthy**
2. Clicar em um servico → **History and rollback** → ultimo sync apos commit GitOps
3. `togglemaster-cluster` — **Synced + Progressing**

**Fala sobre Progressing:**

> "O app de cluster fica Progressing porque o Ingress ainda nao tem endereco — nao instalamos o NGINX Ingress Controller nesta sessao. Os workloads dos cinco servicos ja estao saudaveis; isso nao impede a demonstracao GitOps."

### Cena 4.4 — Pods no cluster (1 min)

**Tela:** terminal.

```bash
kubectl get pods -n togglemaster
kubectl get applications -n argocd
```

**Fala:** "Cinco deployments 1/1 Running; Argo reflete o que esta no Git."

**Opcional (15 s):** `kubectl describe ingress togglemaster-ingress -n togglemaster` — sem ADDRESS.

---

## Bloco 5 — Encerramento (1–2 min)

**Tela:** diagrama mental ou lista no README.

**Fala:**

> "Fluxo completo: desenvolvedor faz push na main, CI testa e escaneia, publica imagem no ECR, atualiza o GitOps, Argo CD sincroniza o EKS. Para economizar creditos Academy, ao terminar executamos Terraform Destroy — a infra some, o codigo e os manifestos permanecem no GitHub."

**Mostrar:** workflow **Terraform Destroy Manual** (tela, nao precisa executar ao vivo).

**Fala final:**

> "Documentacao operacional nos arquivos `docs/epico3-gitops-operacao.md` e `docs/roteiro-fase3-status.md`. Obrigado."

---

## Roteiro alternativo — gravacao rapida (~12 min)

Se a infra **ja estiver no ar** e CI/Argo ja validados:

| Ordem | Conteudo | Tempo |
|-------|----------|-------|
| 1 | Abertura + arquitetura repo | 1 min |
| 2 | Console AWS: EKS + ECR (prints) | 2 min |
| 3 | GitHub Actions: 1 pipeline verde + 1 falha historica seguranca | 3 min |
| 4 | Commits `gitops: bump` + diff tag | 2 min |
| 5 | Argo CD: 5 Healthy + explicar cluster Progressing | 3 min |
| 6 | `kubectl get pods` + destroy mencionado | 1 min |

---

## Falas curtas — glossario tecnico

Use se o avaliador perguntar ou para legenda:

| Termo | Frase pronta |
|-------|----------------|
| GitOps | "Configuracao versionada no Git; o cluster converge para o repositorio." |
| Argo CD | "Operador que compara Git e cluster e aplica diff automaticamente." |
| LabRole | "Role da AWS Academy usada pelo EKS sem criar IAM via Terraform." |
| Tag SHA | "Rastreabilidade: mesma versao no ECR e no deployment.yaml." |
| Ambiente efemero | "Apply para demonstrar, destroy para nao deixar RDS/EKS ligados." |

---

## Evidencias para anexar ao relatorio (apos gravar)

- [ ] Link do video (YouTube/Drive)
- [ ] Screenshot: Terraform Apply verde
- [ ] Screenshot: pipeline falhou (seguranca) + pipeline passou
- [ ] Screenshot: ECR com 5 repos e tag SHA
- [ ] Screenshot: commit `gitops: bump <servico>`
- [ ] Screenshot: Argo CD — 5 apps Healthy
- [ ] Screenshot: `kubectl get pods` 5/5 Running
- [ ] Print calculadora de custos AWS (relatorio PDF)
- [ ] Nomes dos integrantes no PDF

---

## Problemas durante a gravacao

| Problema | O que dizer / fazer |
|----------|---------------------|
| Pod CrashLoopBackOff | "Senha RDS desalinhada" — mostrar alinhamento secrets; ou corte com pods ja Running |
| CI falhou no push GitOps | Mostrar commit `gitops: bump` ja existente + Argo sync |
| Argo nao abre | Refazer port-forward; senha via `kubectl -n argocd get secret argocd-initial-admin-secret ...` |
| ECR ImagePullBackOff | Mostrar tag no deployment = tag no ECR |
| Credenciais expiradas | Renovar Academy; nao gravar keys na tela |

---

## Ordem de gravacao recomendada (producao)

1. Gravar **takes** do terminal (`kubectl`, `aws`) com infra estavel  
2. Gravar **takes** da UI Argo CD e GitHub (commits + Actions)  
3. Gravar **voz** ou legenda em cima das takes  
4. Editar na ordem dos blocos 1 → 5  
5. Revisar duracao total ≤ 20 min  

---

*Ultima atualizacao: maio/2026 — alinhado ao estado do projeto (Argo CD validado, CI `update_gitops`, cluster app Progressing por ingress).*
