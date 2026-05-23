# Epico 3 — O que falar na gravacao (~5 min)

**Foco:** GitOps + Argo CD · somente o que voce diz, passo a passo.  
**Repo:** `github.com/Santosu01/techchallenger-fase-2` (branch `main`)

**Antes de gravar:** Argo em `https://localhost:8080` (port-forward no `argocd-server`), pods 5/5 Running, abas: GitHub `gitops/`, Actions, Commits, Argo.

---

## PASSO 1 — Abertura (~30 s)

**Onde voce esta:** camera ou README do projeto.

**O que falar:**

> Olá. Neste video mostro o Epico 3: entrega continua com GitOps e Argo CD.
>
> A ideia é simples: a configuracao do Kubernetes fica no GitHub, na pasta gitops. Quando o pipeline de CI gera uma nova imagem e publica no ECR, ele mesmo atualiza o arquivo de deployment com a tag nova. O Argo CD fica observando esse repositorio e aplica a mudanca no cluster automaticamente. Eu nao preciso entrar no cluster para fazer deploy na mao.

**Depois:** abra o GitHub, pasta `gitops/`.

---

## PASSO 2 — Pasta GitOps (~20 s)

**Onde voce esta:** GitHub → `gitops/`.

**O que falar:**

> Aqui está o coração do GitOps. Tudo que o cluster deve ter — namespace, configmap, deployments dos cinco microsserviços — está versionado nesta pasta. O Git é a fonte da verdade.

**Depois:** entre em `gitops/cluster/`.

---

## PASSO 3 — Arquivos do cluster (~25 s)

**Onde voce esta:** `gitops/cluster/`.

**O que falar:**

> Nesta pasta ficam os recursos compartilhados: namespace, secrets da aplicação, configmap com conexão dos bancos e do Redis, ingress e o HPA do evaluation. As credenciais temporárias da AWS dos pods não ficam aqui no Git por segurança — aplicamos isso direto no cluster com um script.

**Depois:** abra `gitops/apps/auth-service/deployment.yaml`.

---

## PASSO 4 — Tag da imagem (~25 s)

**Onde voce esta:** `deployment.yaml` do auth-service — linha `image:`.

**O que falar:**

> Em cada serviço, o deployment declara qual imagem usar no ECR. Reparem: a tag não é latest — é o hash curto do commit que o CI gerou, por exemplo 1194f82. Assim eu sei exatamente qual versão do código está rodando no cluster.

**Depois:** abra `gitops/argocd/applications/auth-service.yaml`.

---

## PASSO 5 — Argo no Git (~20 s)

**Onde voce esta:** Application do auth-service em `gitops/argocd/`.

**O que falar:**

> Aqui eu digo ao Argo CD o que monitorar: este repositório, branch main, pasta do serviço. São seis applications no total — uma para o cluster e cinco para os microsserviços. Todas com sync automático ligado.

**Depois:** GitHub → Actions → um pipeline verde, por exemplo Auth Service CI.

---

## PASSO 6 — O CI atualiza o Git (~45 s)

**Onde voce esta:** Actions → execução verde → job **Update GitOps**.

**O que falar:**

> O pipeline não termina no push da imagem. Depois do ECR, este job chamado update_gitops abre o repositório, altera só a linha da imagem no deployment, faz commit com a mensagem gitops bump e envia para a main.
>
> Se vários serviços rodam ao mesmo tempo, a gente serializa esses commits para não dar conflito no Git — um entra depois do outro na fila.

**Depois:** GitHub → Commits → abra um commit `gitops: bump`.

---

## PASSO 7 — O commit que o CI criou (~25 s)

**Onde voce esta:** diff do commit — uma linha mudando na `image:`.

**O que falar:**

> Este commit é a prova do GitOps: quem mudou o manifest não fui eu na mão — foi o próprio CI. A tag antiga virou a tag nova do build. Do código, para o Git, para o cluster — tudo amarrado pelo mesmo identificador.

**Depois:** abra o Argo CD no navegador.

---

## PASSO 8 — Os cinco apps saudáveis (~35 s)

**Onde voce esta:** Argo CD → Applications — cinco serviços verdes.

**O que falar:**

> No Argo CD eu vejo o resultado. Os cinco microsserviços estão Synced e Healthy. Isso significa que o que está no Git já foi aplicado no cluster e os pods estão rodando bem.
>
> O autosync faz o Argo olhar o repositório o tempo todo. Quando o CI commita a tag nova, o Argo detecta e sincroniza sozinho.

**Depois:** clique em **auth-service**.

---

## PASSO 9 — Detalhe e histórico (~35 s)

**Onde voce esta:** tela do auth-service → Summary e History.

**O que falar:**

> Abrindo um serviço, vejo de onde vem o manifest: repositório, pasta gitops/apps/auth-service, branch main.
>
> No histórico de sync dá para ver quando o Argo aplicou cada revisão do Git. É aqui que eu fecho o ciclo: mudança no repositório, Argo sincroniza, Kubernetes sobe a versão nova.

**Depois:** volte e clique em **togglemaster-cluster**.

---

## PASSO 10 — Por que Progressing (~25 s)

**Onde voce esta:** `togglemaster-cluster` — Synced + Progressing.

**O que falar:**

> Este application do cluster pode aparecer Progressing mesmo estando Synced. Na prática o Ingress ainda não tem endereço porque não instalamos o controller de ingress nesta demo.
>
> Isso não atrapalha o Epico 3: o que importa são os cinco microsserviços, e eles já estão Healthy. O GitOps está funcionando.

**Depois:** terminal com kubectl.

---

## PASSO 11 — Confirmar no cluster (~30 s)

**Onde voce esta:** terminal — rode:

```bash
kubectl get applications -n argocd
kubectl get pods -n togglemaster
```

**O que falar:**

> No terminal eu confirmo: as applications do Argo existem no cluster e os cinco pods estão Running. Git, Argo e Kubernetes alinhados.
>
> Reparem que eu não rodei kubectl apply nos apps nesta demo — quem aplicou foi o Argo CD a partir do Git.

**Depois:** volte para a lista de Applications no Argo ou para a camera.

---

## PASSO 12 — Encerramento (~25 s)

**Onde voce esta:** Argo com os cinco apps verdes, ou camera.

**O que falar:**

> Para resumir o Epico 3: o CI publica a imagem versionada, atualiza o GitOps no GitHub, e o Argo CD leva essa mudança para o EKS sem intervenção manual.
>
> Esse é o fluxo de entrega contínua que o desafio pede. Obrigado.

**FIM.**

---

## Texto único (se preferir ler de uma vez)

Use só se quiser ensaiar sem pausar entre passos:

> Olá. Neste video mostro o Epico 3: GitOps e Argo CD. A configuracao do Kubernetes fica no Git, na pasta gitops. O CI publica a imagem no ECR e atualiza a tag no deployment. O Argo CD observa o Git e sincroniza o cluster sozinho.
>
> Na pasta gitops ficam namespace, secrets, configmap, ingress e os cinco microsservicos. Cada deployment usa tag do commit, nao latest. No argocd defino seis applications com autosync.
>
> No pipeline, depois do ECR, o job update_gitops commita gitops bump na main. Aqui no historico de commits vemos a tag mudar — o CI escreveu no Git.
>
> No Argo, os cinco servicos estao Synced e Healthy. No historico vejo quando cada revisao foi aplicada. O app de cluster pode ficar Progressing por causa do ingress, mas os microsservicos estao ok.
>
> No kubectl confirmo pods Running. Quem aplicou foi o Argo, nao apply manual.
>
> Resumo: CI, Git, Argo, cluster — entrega continua ponta a ponta. Obrigado.

---

## Dica de gravacao

- Fale olhando para a camera nos passos 1 e 12; no meio, fale olhando para a tela mas em voz clara.
- Se um commit `gitops: bump` nao existir ao vivo, diga: *"Na ultima execucao do pipeline o CI ja gerou este commit."*
- Nao precisa explicar como subiu a infra — foque no fluxo Git → Argo → pods.

---

*Epico 3 · roteiro de falas · ~5 min*
