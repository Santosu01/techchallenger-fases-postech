# Argo CD (Epico 3)

Pasta reservada para manifestos `Application` / `AppProject` (ou app-of-apps).

Instalacao e roteiro de sessao efemera: [../../docs/epico3-gitops-operacao.md](../../docs/epico3-gitops-operacao.md).

Quando adicionar Applications, apontar para:

- `path: gitops/cluster` (recursos compartilhados; excluir sync de `aws-credentials` — aplicar via script)
- `path: gitops/apps/<servico>` (um Application por microsservico)
