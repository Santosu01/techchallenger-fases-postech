# Scripts de Automação - ToggleMaster

Scripts para automatizar o deploy do ToggleMaster na AWS.

**Sessao efemera (Terraform apply → EKS → destroy):** use `linux/bootstrap-epico3.sh` ou `linux/install-argocd.sh` e o guia [epico3-gitops-operacao.md](../epico3-gitops-operacao.md). Cluster EKS: `togglemaster-eks-homolog`.

**ECR vazio apos apply:** `./linux/push-all-ecr.sh` (requer Docker no WSL).

**Erro `bash\r` no WSL:** `python3 linux/fix-crlf.py`

## 📁 Estrutura

```
scripts/
├── windows/                                # Scripts para Windows
│   ├── aws-configure.bat                   # Configurar AWS CLI
│   ├── ecr-authenticate.bat                # Autenticar no ECR
│   ├── ecr-create-repos.bat                # Criar repositórios ECR
│   ├── ecr-build-push-images.bat           # Build e push das imagens para ECR
│   ├── eks-configure-kubectl.bat           # Configurar kubectl para EKS
│   ├── k8s-apply-manifests.bat              # Deploy no Kubernetes
│   ├── check-resources.bat                  # Verificar status dos recursos
│   ├── test-api.bat                         # Testar todos os serviços
│   ├── deploy-full.bat                      # Deploy completo (tudo em um!)
│   └── cleanup-k8s.bat                      # Limpeza de recursos
├── linux/                                  # Scripts para Linux/Mac
│   ├── aws-configure.sh                     # Configurar AWS CLI
│   ├── ecr-authenticate.sh                  # Autenticar no ECR
│   ├── ecr-create-repos.sh                  # Criar repositórios ECR
│   ├── ecr-build-push-images.sh             # Build e push das imagens para ECR
│   ├── eks-configure-kubectl.sh             # Configurar kubectl para EKS
│   ├── k8s-apply-manifests.sh                # Deploy no Kubernetes
│   ├── check-resources.sh                    # Verificar status dos recursos
│   ├── test-api.sh                           # Testar todos os serviços
│   ├── deploy-full.sh                        # Deploy completo (tudo em um!)
│   ├── bootstrap-epico3.sh                   # Bootstrap GitOps apos terraform apply (Epico 3)
│   ├── install-argocd.sh                     # Instala Argo CD + Applications (Epico 3)
│   ├── push-all-ecr.sh                       # Build/push 5 imagens quando ECR vazio (Epico 3)
│   ├── fix-crlf.py                           # Converte scripts .sh para LF (WSL)
│   ├── update-aws-credentials.sh             # Credenciais AWS nos pods (evaluation/analytics)
│   └── cleanup-k8s.sh                        # Limpeza de recursos
└── README.md                                 # Este arquivo
```

## 🚀 Como Usar

### Windows

Entre na pasta windows e edite as constantes em cada script:

```powershell
cd docs/scripts/windows
```

**Cada script tem suas próprias constantes no início do arquivo!**

Edite as constantes conforme necessário e execute:

```powershell
# Passo 1: Configure suas credenciais AWS (PRIMEIRA VEZ)
.\aws-configure.bat

# Passo 2: Deploy completo (recomendado)
.\deploy-full.bat

# Ou execute passo a passo
.\ecr-create-repos.bat
.\ecr-authenticate.bat
.\ecr-build-push-images.bat
.\eks-configure-kubectl.bat
.\k8s-apply-manifests.bat
.\check-resources.bat
```

### Linux/Mac

Entre na pasta linux e edite as constantes em cada script:

```bash
cd docs/scripts/linux
```

**Cada script tem suas próprias constantes no início do arquivo!**

Edite as constantes conforme necessário e execute:

```bash
# Dar permissão de execução
chmod +x *.sh

# Passo 1: Configure suas credenciais AWS (PRIMEIRA VEZ)
./aws-configure.sh

# Passo 2: Deploy completo (recomendado)
./deploy-full.sh

# Ou execute passo a passo
./ecr-create-repos.sh
./ecr-authenticate.sh
./ecr-build-push-images.sh
./eks-configure-kubectl.sh
./k8s-apply-manifests.sh
./check-resources.sh
```

### Constantes de Configuração

**Cada script possui suas próprias constantes no início do arquivo.** Abra qualquer script e edite os valores na seção "EDITE AS VARIAVEIS ABAIXO":

**Windows (.bat):**
```batch
REM Pasta onde estao os servicos
set "SERVICES_FOLDER=backend-services"

REM Seu ID da AWS (12 dígitos)
set "REGIAO=us-east-1"
set "REGISTRY_ID=123456789012"

REM Cluster EKS
set "CLUSTER_NAME=togglemaster-cluster"
set "NAMESPACE=togglemaster"
```

**Linux (.sh):**
```bash
# Pasta onde estão os serviços
SERVICES_FOLDER="backend-services"

# Seu ID da AWS (12 dígitos)
REGIAO="us-east-1"
REGISTRY_ID="123456789012"

# Cluster EKS
CLUSTER_NAME="togglemaster-eks-homolog"
NAMESPACE="togglemaster"
```

**Importante:** Substitua os valores de exemplo pelos seus valores reais da AWS.

## 📋 Descrição dos Scripts

| Script | Descrição | Constantes Principais |
|--------|-----------|----------------------|
| `aws-configure.bat/.sh` | **Configura credenciais AWS CLI** (execute primeiro!) | Nenhuma |
| `ecr-authenticate.bat/.sh` | Autentica o Docker no Amazon ECR | `REGIAO`, `REGISTRY_ID` |
| `ecr-create-repos.bat/.sh` | Cria os 5 repositórios no ECR | `REGIAO`, `REGISTRY_ID` |
| `ecr-build-push-images.bat/.sh` | Build e push de todas as 5 imagens para o ECR (usa loop) | `REGIAO`, `REGISTRY_ID`, `SERVICES_FOLDER` |
| `eks-configure-kubectl.bat/.sh` | Configura kubectl para conectar ao cluster EKS | `REGIAO`, `CLUSTER_NAME` |
| `k8s-apply-manifests.bat/.sh` | Aplica todos os manifestos Kubernetes | `NAMESPACE` |
| `check-resources.bat/.sh` | Mostra status de todos os recursos | `REGIAO`, `CLUSTER_NAME`, `NAMESPACE` |
| `test-api.bat/.sh` | Testa todos os serviços via HTTP | `NAMESPACE` |
| `deploy-full.bat/.sh` | **Deploy completo!** Executa tudo em sequência | Todas as constantes acima |
| `bootstrap-epico3.sh` | Bootstrap GitOps apos `terraform apply` (Epico 3) | `RDS_MASTER_PASSWORD`, `ECR_IMAGE_TAG` |
| `install-argocd.sh` | Argo CD + Applications (Epico 3) | Idem bootstrap |
| `push-all-ecr.sh` | Build/push das 5 imagens para ECR local | `ECR_IMAGE_TAG`, Docker |
| `update-aws-credentials.sh` | Secret AWS nos pods | Credenciais em `~/.aws/credentials` |
| `cleanup-k8s.bat/.sh` | Limpa recursos do Kubernetes | `NAMESPACE`, `CLUSTER_NAME` |

## ⚡ Deploy Completo Automatizado

**Antes de executar, edite as constantes no `deploy-full.bat` (ou `.sh`)!**

**Windows:**
```powershell
cd docs/scripts/windows
notepad deploy-full.bat
# Edite as constantes no início do arquivo
.\deploy-full.bat
```

**Linux/Mac:**
```bash
cd docs/scripts/linux
nano deploy-full.sh
# Edite as constantes no início do arquivo
./deploy-full.sh
```

Este script executa automaticamente:
1. ✅ Autenticação no ECR
2. ✅ Build e push das 5 imagens
3. ✅ Configuração do kubectl
4. ✅ Deploy no Kubernetes
5. ✅ Verificação de status

## ⚠️ Pré-requisitos

### Windows
- PowerShell ou CMD
- Docker Desktop
- AWS CLI
- kubectl

### Linux/Mac
- Bash
- Docker
- AWS CLI
- kubectl

### Instalar AWS CLI
```bash
# Windows (PowerShell)
msiexec.exe /i https://awscli.amazonaws.com/AWSCLIV2.msi

# Mac
brew install awscli

# Linux
curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip"
unzip awscliv2.zip
sudo ./aws/install
```

### Instalar kubectl
```bash
# Windows
winget install kubernetes.kubectl

# Mac
brew install kubectl

# Linux
curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
```

### Configurar Credenciais AWS

**Use o script aws-configure (recomendado):**

**Windows:**
```powershell
cd docs/scripts/windows
.\aws-configure.bat
```

**Linux/Mac:**
```bash
cd docs/scripts/linux
./aws-configure.sh
```

**Ou manualmente:**
```bash
aws configure
# Entre com suas credenciais
# AWS Access Key ID: [sua key]
# AWS Secret Access Key: [sua secret]
# Default region name: us-east-1
# Default output format: json
```

## 🔧 Troubleshooting

### Erro: "docker login failed"
- Verifique se suas credenciais AWS estão corretas
- Execute `aws configure` novamente
- Verifique se o `REGISTRY_ID` está correto no script

### Erro: "repository already exists"
- Não é problema! O repositório já foi criado antes

### Erro: "No such host" ao pushar
- Verifique se o `REGISTRY_ID` está correto
- Verifique se você autenticou com `ecr-authenticate`

### Erro: "connection refused" no kubectl
- Execute `eks-configure-kubectl` para reconectar
- Verifique se o cluster EKS está ativo no console

## 🧹 Limpeza

Para remover recursos:

**Windows:**
```powershell
cd docs/scripts/windows
.\cleanup-k8s.bat
```

**Linux/Mac:**
```bash
cd docs/scripts/linux
./cleanup-k8s.sh
```

Em seguida, delete manualmente via Console AWS:
1. Cluster EKS
2. Instâncias RDS
3. ElastiCache
4. DynamoDB table
5. SQS queue
6. (Opcional) ECR repositories

## 🧪 Testar Serviços

Após o deploy, teste os serviços:

**Windows:**
```powershell
.\test-api.bat
```

**Linux/Mac:**
```bash
./test-api.sh
```

Este script executa:
- Health checks de todos os serviços
- Criação de usuário
- Listagem de flags
- Avaliação de flag
- Estatísticas de analytics

## 📝 Notas

- **Cada script tem suas próprias constantes no início do arquivo**
- **Edite os valores diretamente no topo de cada script antes de executar**
- Scripts .sh precisam de permissão de execução (`chmod +x`)
- Logs e erros são mostrados no terminal
- Substitua `123456789012` pelo seu ID da AWS real
- Ajuste a região se necessário (padrão: us-east-1)
- A pasta dos serviços (`SERVICES_FOLDER=backend-services`) pode ser alterada conforme sua estrutura
