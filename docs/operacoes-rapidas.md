# ToggleMaster - Guia Rápido de Operações

Referência rápida para operar o ToggleMaster no EKS.

| Cenario | Documento |
|---------|-----------|
| Setup Terraform + secrets GitHub | [fase3-setup-checklist.md](fase3-setup-checklist.md) |
| **GitOps / sessao efemera / gravacao** | **[epico3-gitops-operacao.md](epico3-gitops-operacao.md)** |
| CI DevSecOps | [epico2-ci-devsecops-operacao.md](epico2-ci-devsecops-operacao.md) |
| Status por epico | [roteiro-fase3-status.md](roteiro-fase3-status.md) |
| Legado (`k8s/` antigo) | [guia-completo-implementacao.md](guia-completo-implementacao.md) |

---

## 📋 Deploy rápido (GitOps — recomendado)

Cluster Terraform: **`togglemaster-eks-homolog`** (nao `togglemaster-cluster`).

```bash
# 1. Credenciais AWS validas no WSL
aws sts get-caller-identity

# 2. Kubeconfig
aws eks update-kubeconfig --region us-east-1 --name togglemaster-eks-homolog

# 3. Bootstrap (ConfigMap da AWS + apps + aws-credentials)
export RDS_MASTER_PASSWORD='mesma_senha_do_terraform_tfvars'
export ECR_IMAGE_TAG='tag_no_ecr'   # ex.: 22809c3
./docs/scripts/linux/bootstrap-epico3.sh

# 4. Verificar
kubectl get pods -n togglemaster
```

Detalhes, Argo CD e destroy: [epico3-gitops-operacao.md](epico3-gitops-operacao.md).

---

## 📋 Deploy legado (`k8s/` — referencia)

```bash
aws eks update-kubeconfig --region us-east-1 --name togglemaster-eks-homolog

kubectl apply -f k8s/1-namespace.yaml
kubectl apply -f k8s/2-secrets.yaml
kubectl apply -f k8s/3-configmap.yaml   # preferir regenerar via gitops/scripts
kubectl apply -f k8s/4-deployments.yaml
kubectl apply -f k8s/5-ingress.yaml
kubectl apply -f k8s/6-hpa.yaml

./docs/scripts/linux/update-aws-credentials.sh
kubectl get pods -n togglemaster
```

---

## 🔑 Renovar Credenciais AWS (Vocareum / AWS Academy)

As credenciais AWS Academy expiram a cada ~4 horas. Quando expiram, analytics-service e evaluation-service param de funcionar.

**Sintomas:**
- Logs: `AccessDeniedException`, `ExpiredTokenException`, `InvalidClientTokenId`
- analytics-service reinicia em loop (CrashLoopBackOff)

**Solução:**
```bash
# 1. Obter novas credenciais do Vocareum (AWS Details > Show)

# 2. Deletar e recriar o secret
kubectl delete secret aws-credentials -n togglemaster

kubectl create secret generic aws-credentials -n togglemaster \
  --from-literal=AWS_ACCESS_KEY_ID="ASIA..." \
  --from-literal=AWS_SECRET_ACCESS_KEY="..." \
  --from-literal=AWS_SESSION_TOKEN="IQoJb3..."

# 3. Reiniciar os pods que usam AWS
kubectl rollout restart deployment/analytics-service -n togglemaster
kubectl rollout restart deployment/evaluation-service -n togglemaster

# 4. Verificar logs (deve mostrar "Tabela ToggleMasterAnalytics já existe")
kubectl logs -n togglemaster deployment/analytics-service --tail=10

# 5. (Opcional) Atualizar credenciais locais
aws configure set aws_access_key_id "ASIA..."
aws configure set aws_secret_access_key "..."
aws configure set aws_session_token "IQoJb3..."
```

⚠️ **CUIDADO com tokens!** Copie o `AWS_SESSION_TOKEN` com extremo cuidado — ele é muito longo e um caractere errado causa `InvalidClientTokenId`.

---

## 🌐 URLs do Ingress

O ingress usa `rewrite-target: /$2` que reescreve as URLs. Padrão de uso:

### Health Checks
```bash
INGRESS_URL=$(kubectl get ingress togglemaster-ingress -n togglemaster -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')

curl http://$INGRESS_URL/auth/health
curl http://$INGRESS_URL/flags/health
curl http://$INGRESS_URL/targeting/health
curl http://$INGRESS_URL/evaluate/health
curl http://$INGRESS_URL/analytics/health
```

### Fluxo Completo de Teste
```bash
# 1. Criar API Key
API_KEY=$(curl -s -X POST http://$INGRESS_URL/auth/admin/keys \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer GD9/5xt9n+HuYu7sHUnn4KdjQZmzDMjDgyef/dnmvSo=" \
  -d '{"name":"demo-key"}' | jq -r '.key')

# 2. Criar flag
curl -X POST http://$INGRESS_URL/flags/flags \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -d '{"name":"dark-mode","description":"Modo escuro","is_enabled":true}'

# 3. Criar regra
curl -X POST http://$INGRESS_URL/targeting/rules \
  -H "Content-Type: application/json" \
  -H "X-API-Key: $API_KEY" \
  -d '{"flag_name":"dark-mode","is_enabled":true,"rules":{"type":"PERCENTAGE","value":50}}'

# 4. Avaliar (⚠️ prefixo duplo: /evaluate/evaluate)
curl "http://$INGRESS_URL/evaluate/evaluate?flag_name=dark-mode&user_id=user123"

# 5. Ver analytics
curl "http://$INGRESS_URL/analytics/events"
```

### Tabela de Mapeamento de URLs

| Serviço | URL Externa | Path interno |
|---------|-------------|-------------|
| Auth health | `/auth/health` | `/health` |
| Auth admin | `/auth/admin/keys` | `/admin/keys` |
| Flags CRUD | `/flags/flags` | `/flags` |
| Flag por nome | `/flags/flags/dark-mode` | `/flags/dark-mode` |
| Targeting | `/targeting/rules` | `/rules` |
| **Evaluate** | **`/evaluate/evaluate?...`** | `/evaluate?...` |
| Analytics events | `/analytics/events` | `/events` |
| Analytics health | `/analytics/health` | `/health` |

---

## 🧪 Teste de Carga (HPA)

```bash
# Terminal 1: Monitorar HPA
kubectl get hpa -n togglemaster -w

# Terminal 2: Monitorar pods
kubectl get pods -n togglemaster -w

# Terminal 3: Gerar carga
hey -z 3m -c 100 -q 200 "http://$INGRESS_URL/evaluate/evaluate?flag_name=dark-mode&user_id=loadtest"
```

**Resultados esperados:**
- ~6000+ requests em 3 minutos
- 100% HTTP 200
- ~0.87s latência média
- HPA escala de 1→2+ replicas do evaluation-service

---

## 🔧 Rebuild e Redeploy de Serviço

Quando alterar código de um serviço:

```bash
# 1. Autenticar no ECR
aws ecr get-login-password --region us-east-1 | \
  docker login --username AWS --password-stdin \
  154367514500.dkr.ecr.us-east-1.amazonaws.com

# 2. Build e push (exemplo: analytics-service)
cd backend-services/analytics-service
docker build -t analytics-service .
docker tag analytics-service:latest 154367514500.dkr.ecr.us-east-1.amazonaws.com/analytics-service:latest
docker push 154367514500.dkr.ecr.us-east-1.amazonaws.com/analytics-service:latest

# 3. Forçar pull da nova imagem
kubectl patch deployment analytics-service -n togglemaster --type=json \
  -p='[{"op":"replace","path":"/spec/template/spec/containers/0/imagePullPolicy","value":"Always"}]'
kubectl rollout restart deployment/analytics-service -n togglemaster

# 4. Verificar
kubectl get pods -n togglemaster -w
kubectl logs -n togglemaster deployment/analytics-service --tail=20
```

---

## 🔍 Diagnóstico Rápido

### Pod em CrashLoopBackOff
```bash
kubectl describe pod <POD_NAME> -n togglemaster
kubectl logs <POD_NAME> -n togglemaster --previous
```

### Verificar conectividade entre serviços
```bash
# DNS funciona?
kubectl run dns-test --rm -i --restart=Never --image=busybox -n togglemaster -- nslookup flag-service

# Redis funciona? (deve retornar PONG)
kubectl run redis-test --rm -i --restart=Never --image=redis:alpine -n togglemaster -- \
  redis-cli -h togglemaster-cache-6cviqx.serverless.use1.cache.amazonaws.com -p 6379 --tls --insecure PING
```

### Verificar DynamoDB
```bash
aws dynamodb scan --table-name ToggleMasterAnalytics --region us-east-1 --max-items 5
```

### Ver todos os recursos
```bash
kubectl get all -n togglemaster
kubectl get ingress -n togglemaster
kubectl get hpa -n togglemaster
```

---

## 📊 Arquitetura - Portas dos Serviços

| Serviço | Container Port | K8s Service Port | Linguagem |
|---------|---------------|-----------------|-----------|
| auth-service | 8001 | 8001 | Go |
| flag-service | 8002 | 8002 | Python |
| targeting-service | 8003 | 8003 | Python |
| evaluation-service | 8004 | 8004 | Go |
| analytics-service | **8006** | **8005** | Python |

⚠️ **analytics-service** roda na porta 8006 internamente, mas o K8s Service mapeia 8005→8006.

---

## ⚠️ Armadilhas Comuns (Lições Aprendidas)

1. **AUTH_SERVICE_URL obrigatório**: flag-service e targeting-service PRECISAM desta variável. Sem ela, fazem fallback para `http://auth-app:8001` (nome do Docker Compose) que não existe no K8s. Resultado: erro 503.

2. **DynamoDB key = `requestId`**: A tabela usa `requestId` como partition key, NÃO `event_id`. O código do analytics-service deve usar `requestId` no item do DynamoDB.

3. **Secret `aws-credentials` separado**: As credenciais AWS ficam no secret `aws-credentials` (não `app-secrets`). Inclui `AWS_SESSION_TOKEN` obrigatório para AWS Academy.

4. **imagePullPolicy: Always**: Use `Always` para garantir que novas imagens sejam baixadas. `IfNotPresent` causa problemas quando se faz rebuild com tag `:latest`.

5. **ElastiCache Serverless = TLS obrigatório**: `REDIS_TLS: "true"` no ConfigMap.

6. **`or None` nos endpoints boto3**: Em `app.py` do analytics, usar `os.getenv("AWS_SQS_ENDPOINT_URL") or None` para que strings vazias virem `None` (boto3 rejeita string vazia).

7. **Ingress prefixo duplo**: URLs como `/evaluate/evaluate?...` são necessárias por causa do `rewrite-target: /$2`.

---

## 🗂️ Estrutura dos Manifestos K8s

Use os arquivos **numerados** na pasta `k8s/`:

| Arquivo | Conteúdo |
|---------|----------|
| `1-namespace.yaml` | Namespace `togglemaster` |
| `2-secrets.yaml` | Secret `app-secrets` (Postgres, MASTER_KEY) |
| `3-configmap.yaml` | ConfigMap `app-config` (endpoints, URLs, DATABASE_URLs) |
| `4-deployments.yaml` | 5 Deployments + 5 Services |
| `5-ingress.yaml` | Ingress NGINX com rewrite-target |
| `6-hpa.yaml` | HPA para evaluation-service (1-5 replicas, 70% CPU) |

> **Ignorar** os arquivos não-numerados (`configmap.yaml`, `deployments.yaml`, etc.) — são versões antigas.
