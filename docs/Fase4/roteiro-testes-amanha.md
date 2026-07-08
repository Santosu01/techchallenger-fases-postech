# Roteiro de Testes e Captura de Prints (Fase 4)

Este documento contém o roteiro passo a passo com links e comandos exatos para você realizar os testes e capturar os prints exigidos para a entrega da **Fase 4**.

---

## 1. 📊 Print do Dashboard do Grafana
O Grafana já está rodando e configurado com o Prometheus (métricas) e Loki (logs).
1. Faça o redirecionamento de porta (se não estiver rodando):
   ```bash
   kubectl port-forward svc/grafana 3000:80 -n monitoring
   ```
2. Acesse a URL: [http://localhost:3000](http://localhost:3000)
3. Credenciais de Acesso:
   * **Usuário:** `admin`
   * **Senha:** `w08CSK3gxXHFsbUsESNFhEY23r0JRQiJ32QMvJXX`
4. No menu esquerdo, navegue em **Dashboards**, selecione o dashboard preconfigurado **"Pos-Tech"** ou explore o painel de logs consolidados do Loki.
5. Capture o print da tela mostrando os gráficos preenchidos.

---

## 2. 🌐 Print de um Trace Distribuído no APM (Datadog / New Relic)
Para rastrear as chamadas e o Service Map, é necessário integrar com uma conta trial comercial de APM.
1. Crie uma conta gratuita de avaliação no [New Relic](https://newrelic.com/signup) ou no [Datadog](https://www.datadoghq.com/).
2. Obtenha sua chave de API e aplique no cluster EKS com o comando:
   ```bash
   kubectl create secret generic apm-secrets --namespace monitoring --from-literal=datadog-api-key="SUA_CHAVE_DATADOG" --from-literal=newrelic-api-key="SUA_CHAVE_NEW_RELIC" --dry-run=client -o yaml | kubectl apply -f -
   ```
3. Reinicie o coletor para aplicar a nova chave:
   ```bash
   kubectl rollout restart deployment/otel-collector -n monitoring
   ```
4. Gere tráfego de requisições de teste chamando a API do `evaluation-service`:
   ```bash
   kubectl run test-traffic -n togglemaster --image=curlimages/curl -i --rm --restart=Never -- http://evaluation-service:8004/evaluate
   ```
5. No painel do seu APM (New Relic ou Datadog), vá em **Distributed Tracing**, selecione a rota `/evaluate` e capture o print mostrando o trace completo cruzando os serviços (de `evaluation-service` chamando `flag-service`, `targeting-service` e `auth-service`).

---

## 3. 💬 Print da Notificação de Incidente no ChatOps (Discord / Slack)
Você pode usar a notificação de teste nativa do Grafana para tirar o print imediato sem precisar simular uma queda longa de serviço.
1. Crie um Webhook no Discord (Configurações do canal de texto > Integrações > Webhooks > Criar Webhook e copie a URL) ou no Slack.
2. Acesse o Grafana Alerting: [http://localhost:3000/alerting/notifications](http://localhost:3000/alerting/notifications).
3. Vá em **Contact points** > **Add contact point**.
4. Configure como **Discord** (ou **Slack**), cole a URL do webhook e salve.
5. Clique no botão **Test** no canto superior direito do contact point para disparar uma notificação imediata.
6. Capture o print da mensagem recebida no canal do Discord ou Slack.

---

## 4. 🛡️ Print do Log/Execução do Self-Healing
O receptor de autocura (`webhook-receiver`) está ativo no namespace `monitoring`. Para capturar o print da execução da autocura:
1. Dispense a necessidade de quebrar o banco de dados enviando uma chamada de teste que simula o alerta do Grafana disparando:
   * **No Windows (PowerShell) - Certifique-se de que a porta 5000 esteja livre:**
     * Primeiro redirecione a porta do webhook-receiver:
       ```bash
       kubectl port-forward svc/webhook-receiver -n monitoring 5000:5000
       ```
     * Em outro terminal, execute o POST de simulação:
       ```powershell
       Invoke-RestMethod -Uri "http://localhost:5000/alert" -Method Post -ContentType "application/json" -Body '{"status":"firing","alerts":[{"status":"firing","labels":{"alertname":"EvaluationHighErrorRate"}}]}'
       ```
2. Após receber a resposta de sucesso (`Self-healing triggered successfully`), consulte os logs do receptor rodando:
   ```bash
   kubectl logs -n monitoring -l app=webhook-receiver --tail=50
   ```
3. O log exibirá a execução do rolling restart no deployment `evaluation-service`:
   * `🚨 ALERTA DISPARADO (FIRING) recebido. Iniciando autocura do evaluation-service...`
   * `✅ Self-healing executado com sucesso: rolling restart do evaluation-service disparado...`
4. Capture o print do terminal contendo esses logs de sucesso.
