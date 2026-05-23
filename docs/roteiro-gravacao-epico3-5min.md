# Roteiro de gravacao — Epico 3 apenas (GitOps + Argo CD)

**Duracao:** ~5 minutos (4:30–5:30)  
**Premissa:** infra e CI ja rodaram; EKS, ECR e Argo CD estao no ar.  
**Repo:** `https://github.com/Santosu01/techchallenger-fase-2` (branch `main`)

Documentacao de apoio: [epico3-gitops-operacao.md](epico3-gitops-operacao.md)

---

## Preparacao (antes de apertar REC)

| # | Acao |
|---|------|
| 1 | `aws eks update-kubeconfig --region us-east-1 --name togglemaster-eks-homolog` |
| 2 | `kubectl get pods -n togglemaster` — 5 deployments **1/1 Running** |
| 3 | Terminal 1: `kubectl port-forward svc/argocd-server -n argocd 8080:443` (deixar aberto) |
| 4 | Browser: `https://localhost:8080` — login Argo (`admin` + senha do secret) |
| 5 | Abas: GitHub **Commits** (`main`), GitHub **Actions** (ultimo CI verde), Argo **Applications** |
| 6 | Anotar uma tag recente no ECR/GitOps (ex.: `1194f82`, `faff57f`) para citar na fala |

Senha Argo (se precisar):

```bash
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

---

## Linha do tempo (5 minutos)

| Tempo | Cena | Tela principal |
|-------|------|----------------|
| 0:00–0:30 | Gancho Epico 3 | Voce / slide minimo |
| 0:30–1:30 | GitOps no Git | GitHub `gitops/` |
| 1:30–2:45 | CI → atualiza Git | Actions + commit `gitops: bump` |
| 2:45–4:15 | Argo CD sincroniza | UI Argo CD |
| 4:15–4:45 | Prova no cluster | Terminal `kubectl` |
| 4:45–5:00 | Fechamento | Argo apps + uma frase |

---

## 0:00 – 0:30 | Abertura

**Tela:** voce na camera ou README na raiz do repo.

**Fala (leia com naturalidade):**

> "Neste trecho mostro somente o Epico 3: entrega continua com GitOps e Argo CD. A fonte da verdade dos manifests Kubernetes fica no GitHub, na pasta `gitops`. O pipeline de CI, depois de publicar a imagem no ECR, atualiza automaticamente a tag no repositorio. O Argo CD observa esse Git e aplica a mudanca no cluster EKS `togglemaster-eks-homolog`, sem deploy manual no kubectl."

**Transicao:** alt-tab para GitHub, pasta `gitops/`.

---

## 0:30 – 1:30 | Estrutura GitOps no repositorio

**Tela:** GitHub → Code → `gitops/`

**Passo a passo na tela:**

1. Abrir `gitops/cluster/` — mostrar rapidamente:
   - `00-namespace.yaml`
   - `app-secrets.yaml` (dizer: *senha Postgres versionada aqui; credencial AWS da sessao nao*)
   - `configmap.yaml` (dizer: *endpoints RDS/Redis regenerados apos cada terraform apply*)
   - `ingress.yaml`, `evaluation-hpa.yaml`

2. Abrir `gitops/apps/auth-service/deployment.yaml` — **zoom na linha `image:`**

**Fala:**

> "Separo recursos compartilhados em `cluster` e cada microsservico em `apps`. O deployment declara a imagem do ECR com tag fixa — por exemplo esta tag `1194f82` — que corresponde ao commit que gerou o build. Nao usamos `latest` vazio."

3. (10 s) Abrir `gitops/argocd/applications/auth-service.yaml`

**Fala:**

> "No `argocd` defino seis Applications: uma para o cluster e cinco para os servicos. Todas apontam para este repositorio, branch `main`, com autosync, prune e self-heal."

**Transicao:** GitHub → **Actions**.

---

## 1:30 – 2:45 | CI atualiza o Git (GitOps write-back)

**Tela:** GitHub Actions → workflow de um servico (ex. **Auth Service CI** ou **Targeting Service CI**) — run **verde** recente.

**Passo a passo:**

1. Clicar na run → expandir job **Update GitOps - auth-service** (ou nome do servico).

2. Mostrar steps:
   - `Bump image tag in GitOps manifest`
   - `Commit and push GitOps change`

**Fala:**

> "Apos o push no ECR, o job reutilizavel `update_gitops` faz checkout da `main`, altera so a linha da imagem no `deployment.yaml`, commita com mensagem padrao `gitops: bump` e faz push. Varias pipelines podem rodar juntas; por isso serializamos com concurrency `gitops-update-main` e rebase antes do push."

3. Alt-tab → GitHub → **Commits** na `main` → filtrar/buscar `gitops: bump`

4. Abrir **um commit** → aba **Files changed** — mostrar diff de uma linha na `image:`

**Fala:**

> "Aqui esta a evidencia que o CI escreve no Git: a tag antiga troca pela tag do commit do build — rastreabilidade do codigo ate o cluster."

**Dica gravacao:** se nao houver commit novo ao vivo, use um commit ja existente e diga: *"Na ultima execucao o CI gerou este commit"*.

**Transicao:** browser Argo CD.

---

## 2:45 – 4:15 | Argo CD — monitoramento e sync

**Tela:** `https://localhost:8080` → **Applications**

**Passo a passo:**

1. Vista geral — destacar **5 apps de servico**:
   - `auth-service`
   - `flag-service`
   - `targeting-service`
   - `evaluation-service`
   - `analytics-service`  
   Status esperado: **Synced** + **Healthy** (verde).

**Fala:**

> "O Argo CD compara o estado desejado no Git com o cluster. Com autosync, cada commit na `main` dispara reconciliacao. Os cinco microsservicos aparecem saudaveis porque o manifest no Git, a imagem no ECR e o deployment no EKS estao alinhados."

2. Clicar em **auth-service** (ou outro):
   - Aba **Summary** → mostrar **Repository**, **Path** `gitops/apps/auth-service`, **Target Revision** `main`
   - Aba **Sync** → botao **Sync** (nao precisa clicar se ja Synced)
   - **History and rollback** → ultimo sync com mensagem/revision ligada ao commit Git

**Fala:**

> "Se eu abrir o historico, vejo qual revisao do Git foi aplicada — isso fecha o ciclo GitOps: mudanca no repositorio, operador sincroniza, Kubernetes roda a nova revisao."

3. Clicar em **togglemaster-cluster** — **Synced** + **Progressing**

**Fala (importante — 20 s):**

> "O application de cluster pode ficar Progressing mesmo Synced: o Ingress ainda nao tem IP porque nao instalamos o NGINX Ingress Controller nesta demonstracao. Isso nao invalida o Epico 3 — o requisito e a entrega continua dos microsservicos, que ja estao Healthy."

4. (Opcional 15 s) **App Details** → **Tree** → expandir `Deployment` → `Pod` Running

**Transicao:** terminal WSL.

---

## 4:15 – 4:45 | Validacao no cluster (kubectl)

**Tela:** terminal — fonte grande, fundo escuro.

**Comandos (digitar devagar ou colar):**

```bash
kubectl get applications -n argocd
kubectl get pods -n togglemaster
kubectl get deploy -n togglemaster -o wide
```

**Fala:**

> "No cluster confirmo: Applications do Argo registradas, cinco pods Running, deployments com a mesma revisao que esta no Git. Nao foi necessario `kubectl apply` manual na gravacao — o Argo ja convergiu o estado."

**Opcional (10 s, se couber tempo):**

```bash
grep "image:" gitops/apps/auth-service/deployment.yaml
```

> "A tag no arquivo local bate com o que o Argo aplicou."

---

## 4:45 – 5:00 | Fechamento Epico 3

**Tela:** voltar para Argo — vista Applications (5 verdes) **ou** diagrama falado.

**Fala final:**

> "Resumindo o Epico 3: CI publica imagem versionada no ECR, atualiza o GitOps no GitHub, Argo CD detecta a mudanca e sincroniza o EKS automaticamente. O modelo e efemero — ao encerrar a sessao fazemos terraform destroy — mas o fluxo GitOps permanece documentado no repositorio. Obrigado."

**Fade / stop.**

---

## Roteiro alternativo — disparar sync AO VIVO (+2 min)

Se quiser estender para **~7 min** com momento "ao vivo":

1. Antes de gravar: alterar **uma linha** em `backend-services/auth-service/README.md` (ou comentario em `service-ci-base.yml`).
2. Push `main` → esperar CI verde (~3–8 min) — gravar tela de espera em aceleracao.
3. Mostrar commit `gitops: bump auth-service` aparecendo.
4. Argo → **Refresh** no `auth-service` → watch **Syncing** → **Healthy**.

**Fala ao vivo:**

> "Disparei um push na main; o CI rebuildou, atualizou o manifest e o Argo esta sincronizando agora."

---

## Checklist de evidencia (Epico 3 sozinho)

Para o relatorio ou corte do video longo:

- [ ] Print: pasta `gitops/` no GitHub
- [ ] Print: diff commit `gitops: bump *`
- [ ] Print: job **Update GitOps** verde no Actions
- [ ] Print/video: Argo CD — 5 apps **Synced/Healthy**
- [ ] Print: `togglemaster-cluster` **Progressing** + explicacao ingress
- [ ] Print: `kubectl get pods -n togglemaster` (5/5)

---

## O que NAO entrar nestes 5 minutos

Evite desviar tempo para:

- `terraform plan/apply` (Epico 1)
- Detalhe de SAST/Trivy (Epico 2) — no maximo 1 frase: *"o CI ja validou a imagem antes do push"*
- `docker-compose` local
- Instalacao completa do Argo do zero (mencionar script `install-argocd.sh` em 1 frase se necessario)

---

## Troubleshooting na gravacao

| Sintoma | Acao rapida |
|---------|-------------|
| Argo nao abre | Refazer port-forward; aceitar certificado em `localhost:8080` |
| App **Degraded** | `kubectl logs` do pod; checar tag ECR vs `deployment.yaml` |
| Sem commit `gitops: bump` | Re-run workflow do servico ou mostrar commit anterior |
| Tela vazia Actions | Filtrar branch `main`, workflow `*-service-ci` |

---

*Epico 3 — CD + GitOps (Argo CD). Duracao alvo ~5 min. Maio/2026.*
