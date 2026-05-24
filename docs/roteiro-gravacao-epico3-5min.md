# Epico 3 — Roteiro simples (~5 min)

**Antes de gravar:** Argo em `https://localhost:8080` · pods 5/5 Running · abas: GitHub `gitops/`, Actions, Commits, Argo.

---

## PASSO 1 — Introducao (~45 s)

**Tela:** camera ou README.

**Falar:**

> Olá. Vou mostrar o Epico 3: GitOps com Argo CD.
>
> Tudo que roda no cluster está no Git, na pasta gitops. O CI publica a imagem no ECR e atualiza a tag no repositório. O Argo CD vê essa mudança e aplica no cluster sozinho — sem deploy manual.

---

## PASSO 2 — GitOps no GitHub (~1 min)

**Tela:** GitHub → `gitops/` → abrir `apps/auth-service/deployment.yaml` (linha `image:`).

**Falar:**

> Aqui está a fonte da verdade. Cada serviço tem seu deployment com a imagem do ECR e uma tag fixa — o hash do commit do CI, não latest.
>
> Na pasta argocd estão as Applications que dizem ao Argo o que monitorar, todos com sync automático.

---

## PASSO 3 — CI atualiza o Git (~1 min 15 s)

**Tela:** Actions → pipeline verde → job **Update GitOps** → depois Commits → um commit `gitops: bump` (mostrar o diff da tag).

**Falar:**

> Depois do push no ECR, o CI commita na main a tag nova no deployment. Essa mensagem gitops bump é a prova: quem mudou o manifest foi o pipeline, não eu na mão.
>
> Da imagem no ECR até o arquivo no Git — mesma versão, rastreável pelo commit.

---

## PASSO 4 — Argo CD (~1 min 30 s)

**Tela:** Argo → Applications (5 serviços Synced/Healthy) → clicar em um → History.

**Falar:**

> No Argo os cinco microsserviços estão Synced e Healthy. Quando o CI commita, o autosync traz a mudança para o cluster.
>
> No histórico vejo qual revisão do Git foi aplicada — fecha o ciclo GitOps.
>
> O app togglemaster-cluster pode ficar Progressing por causa do Ingress sem controller; os serviços já estão ok.

---

## PASSO 5 — Terminal e fechamento (~45 s)

**Tela:** `kubectl get pods -n togglemaster` → voltar ao Argo (5 apps verdes).

**Falar:**

> No cluster, cinco pods Running. Não usei kubectl apply — foi o Argo que convergiu o estado a partir do Git.
>
> Resumo: CI → Git → Argo → cluster. Entrega contínua ponta a ponta. Obrigado.

---

## Texto unico (ensaiar tudo de uma vez)

> Olá. Epico 3: GitOps e Argo CD. Configuração no Git, pasta gitops. CI publica no ECR e atualiza a tag no deployment. Argo sincroniza o cluster sozinho.
>
> No Git vejo a imagem com tag do commit. No Actions, o job update_gitops commita gitops bump. No Argo, cinco apps Synced e Healthy. No kubectl, cinco pods Running.
>
> CI, Git, Argo, cluster — entrega contínua. Obrigado.

---

*5 passos · ~5 min · sem Terraform*
