# Roteiro Diário de Comandos: Inicialização Completa do Ambiente

Sempre que a sessão de 3 horas do AWS Academy expirar e você precisar recriar todo o ambiente e os dashboards do zero, execute a sequência de comandos abaixo.

---

## Passo 1: Atualizar as Credenciais
1. Copie as novas credenciais da AWS para o seu arquivo local em `~/.aws/credentials`.
2. Vá nas configurações do repositório no GitHub (**Settings > Secrets and variables > Actions**) e atualize as chaves:
   * `AWS_ACCESS_KEY_ID`
   * `AWS_SECRET_ACCESS_KEY`
   * `AWS_SESSION_TOKEN`

---

## Passo 2: Subir a Infraestrutura (Terraform)
1. No GitHub Actions, selecione o workflow **Terraform Apply Manual**.
2. Clique em **Run workflow**, digite `APPLY` e execute. Aguarde finalizar (10-15 min).

---

## Passo 3: Conectar seu Terminal ao Novo Cluster
No seu terminal local (PowerShell ou Bash), rode:
```bash
# Atualiza o arquivo kubeconfig com o novo endpoint do cluster
aws eks update-kubeconfig --name togglemaster-eks-homolog --region us-east-1

# Teste a conexão (deve listar 2 nós ativos)
kubectl get nodes
```

---

## Passo 4: Escalar o Cluster para 4 Nós (Importante!)
Os nós da AWS Academy limitam o tráfego de rede para no máximo **11 pods por instância**. Para que todas as aplicações e ferramentas de observabilidade caibam simultaneamente no cluster, escale a quantidade de nós para 4:
```bash
aws eks update-nodegroup-config --cluster-name togglemaster-eks-homolog --nodegroup-name togglemaster-eks-homolog-ng --scaling-config desiredSize=4,minSize=2,maxSize=4
```
*Aguarde 2 minutos até que `kubectl get nodes` mostre 4 nós no estado `Ready`.*

---

## Passo 5: Instalar o ArgoCD
Execute a instalação do ArgoCD via Helm:
```bash
helm repo add argo https://argoproj.github.io/argo-helm
helm repo update
helm install argocd argo/argo-cd --namespace argocd --create-namespace
```
*Aguarde 30 segundos até que os CRDs sejam registrados no Kubernetes.*

**Obter a Senha Inicial do ArgoCD:**

* **No Windows (PowerShell):**
  ```powershell
  [System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}")))
  ```
* **No Linux / macOS (Bash):**
  ```bash
  kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 --decode; echo
  ```

---


## Passo 6: Executar o Bootstrap do GitOps
Sincronize todos os microsserviços e configurações do ecossistema a partir da branch `Fase4`:
```bash
kubectl apply -f gitops/argocd-bootstrap.yaml
```

---

## Passo 7: Instalar a Stack de Observabilidade (Prometheus, Loki, Grafana)
Execute a criação do namespace de monitoramento e a instalação do Prometheus, Grafana e Loki Stack no cluster:
```bash
# Adicionar repositórios Helm
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo add grafana https://grafana.github.io/helm-charts
helm repo update

# Criar namespace isolado
kubectl create namespace monitoring

# Instalar Prometheus (sem alertmanager local)
helm install prometheus prometheus-community/prometheus --namespace monitoring --set alertmanager.enabled=false --set server.persistentVolume.enabled=false

# Instalar Grafana
helm install grafana grafana/grafana --namespace monitoring --set persistence.enabled=false --set service.type=LoadBalancer

# Instalar Loki (Loki-Stack com Promtail integrado)
helm install loki grafana/loki-stack --namespace monitoring --set loki.persistence.enabled=false,promtail.enabled=true
```

---

## Passo 8: Descriptografar a Senha do Grafana e Abrir Acesso
Para consultar a senha do usuário `admin` gerada dinamicamente:

**No Windows (PowerShell):**
```powershell
[System.Text.Encoding]::UTF8.GetString([System.Convert]::FromBase64String((kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}")))
```

**No Linux / macOS (Bash):**
```bash
kubectl get secret --namespace monitoring grafana -o jsonpath="{.data.admin-password}" | base64 --decode; echo
```

**Ativar o túnel local (Port-Forward):**
```bash
kubectl port-forward svc/grafana 3000:80 -n monitoring
```
Acesse o painel no navegador: **`http://localhost:3000`**

---

## Passo 9: Configurar Automaticamente as Fontes de Dados e Painéis (Script)
Para não ter que adicionar o Prometheus, Loki e criar os painéis manualmente toda vez na interface gráfica do Grafana, abra um console **PowerShell** no seu computador local e execute o bloco de código abaixo (substituindo a `senha_do_grafana` pela senha obtida no Passo 8):

```powershell
# DEFINA A SENHA GERADA AQUI
$password = "COLE_A_SENHA_AQUI"

$headers = @{ Authorization = "Basic " + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes("admin:$password")); "Content-Type" = "application/json" };

# 1. Cria Data Source do Prometheus
$promPayload = @{ name = "Prometheus"; type = "prometheus"; url = "http://prometheus-server.monitoring.svc.cluster.local"; access = "proxy"; isDefault = $true } | ConvertTo-Json;
Invoke-RestMethod -Method Post -Uri "http://localhost:3000/api/datasources" -Headers $headers -Body $promPayload;

# 2. Cria Data Source do Loki
$lokiPayload = @{ name = "Loki"; type = "loki"; url = "http://loki.monitoring.svc.cluster.local:3100"; access = "proxy"; isDefault = $false } | ConvertTo-Json;
Invoke-RestMethod -Method Post -Uri "http://localhost:3000/api/datasources" -Headers $headers -Body $lokiPayload;

# 3. Cria Dashboard Pos-Tech com Gráficos Reais
$dashboard = @{
  id = $null
  uid = "adq889d"
  title = "Pos-Tech"
  timezone = "browser"
  schemaVersion = 36
  version = 1
  panels = @(
    @{
      id = 1
      title = "Taxa de Requisições HTTP (OTel)"
      type = "timeseries"
      gridPos = @{ h = 8; w = 12; x = 0; y = 0 }
      datasource = @{ type = "prometheus"; uid = "efqxypsj90bnkb" }
      targets = @(
        @{
          expr = 'sum(rate(http_server_duration_count[5m])) by (service_name)'
          refId = "A"
          legendFormat = "{{service_name}}"
        }
      )
    },
    @{
      id = 2
      title = "Uso de CPU por Pod"
      type = "timeseries"
      gridPos = @{ h = 8; w = 12; x = 12; y = 0 }
      datasource = @{ type = "prometheus"; uid = "efqxypsj90bnkb" }
      targets = @(
        @{
          expr = 'sum(rate(container_cpu_usage_seconds_total{container!=""}[5m])) by (pod)'
          refId = "A"
          legendFormat = "{{pod}}"
        }
      )
    },
    @{
      id = 3
      title = "Logs Centralizados (Loki)"
      type = "logs"
      gridPos = @{ h = 10; w = 24; x = 0; y = 8 }
      datasource = @{ type = "loki"; uid = "afqxypt6f2f40a" }
      targets = @(
        @{
          expr = '{namespace=~"togglemaster|monitoring"}'
          refId = "A"
        }
      )
    }
  )
};
$payload = @{ dashboard = $dashboard; overwrite = $true } | ConvertTo-Json -Depth 10;
Invoke-RestMethod -Method Post -Uri "http://localhost:3000/api/dashboards/db" -Headers $headers -Body $payload;
```
*(Após rodar o script, basta recarregar a página do Grafana para ver o Dashboard montado e pronto para a demonstração!)*
