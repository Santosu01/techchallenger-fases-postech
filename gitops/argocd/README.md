# Argo CD (Epico 3)

Manifests para instalar e operar o GitOps no EKS.

## Conteudo

| Arquivo | Funcao |
|---------|--------|
| `app-project.yaml` | Projeto `togglemaster` (repo GitHub permitido) |
| `applications/togglemaster-cluster.yaml` | Sync de `gitops/cluster/` |
| `applications/*-service.yaml` | Sync de cada `gitops/apps/<servico>/` |

Repo: `https://github.com/Santosu01/techchallenger-fase-2.git` — branch `main` (altere `targetRevision` se usar outra branch).

**Autosync** com `prune` e `selfHeal` habilitados (demonstracao do enunciado).

O Secret `aws-credentials` **nao** esta em `gitops/cluster/`; aplique apos o sync:

`docs/scripts/linux/update-aws-credentials.sh`

## Instalacao rapida (sessao efemera)

```bash
export RDS_MASTER_PASSWORD='senha_do_terraform_tfvars'
export ECR_IMAGE_TAG='tag_no_ecr'
chmod +x docs/scripts/linux/install-argocd.sh
./docs/scripts/linux/install-argocd.sh
```

Guia completo: [../../docs/epico3-gitops-operacao.md](../../docs/epico3-gitops-operacao.md)

## Instalacao manual

```bash
kubectl create namespace argocd
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
kubectl wait -n argocd --for=condition=available deployment/argocd-server --timeout=600s
kubectl apply -f gitops/argocd/app-project.yaml
kubectl apply -f gitops/argocd/applications/
```

## UI

```bash
kubectl port-forward svc/argocd-server -n argocd 8080:443
```

Abra `https://localhost:8080` — usuario `admin`, senha inicial no secret `argocd-initial-admin-secret`.

## Proximo passo do epico

CI atualizando `image:` em `gitops/apps/*/deployment.yaml` apos push no ECR (workflow GitHub Actions).
