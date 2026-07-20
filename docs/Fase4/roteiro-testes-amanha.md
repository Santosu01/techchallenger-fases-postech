# Checklist Final e Roteiro para Gravação de Vídeo (Fase 4)

Este documento contém apenas as ações que **faltam você executar** para tirar os prints necessários e gravar o vídeo de demonstração para a entrega do trabalho. Todas as configurações do cluster, banco de dados e envio de dados para o New Relic já foram concluídas com sucesso.

---

## 📅 Resumo Geral dos Acessos
Guarde estas informações para acessar os consoles durante a gravação e testes:

| Recurso | URL | Usuário | Senha / Chave |
| :--- | :--- | :--- | :--- |
| **🐙 ArgoCD** | [https://localhost:8080](https://localhost:8080) | `admin` | `uVSJnI36xJwQdi3u` |
| **📊 Grafana** | [http://localhost:3000](http://localhost:3000) | `admin` | `w08CSK3gxXHFsbUsESNFhEY23r0JRQiJ32QMvJXX` |
| **🌐 New Relic** | [https://one.newrelic.com](https://one.newrelic.com) | E-mail do grupo | Senha do grupo |

---

## 🚀 Checklist de Tarefas para Entrega

### [ ] Passo 1: Capturar os 4 Prints Obrigatórios

#### 📥 Print 1: Dashboard do Grafana
* **Ação:** Abra um terminal e inicie o redirecionamento:
  ```bash
  kubectl port-forward svc/grafana 3000:80 -n monitoring
  ```
* **Ação:** Acesse [http://localhost:3000](http://localhost:3000) no seu navegador, vá em **Dashboards** e abra o painel **"Pos-Tech"**.
* **Como preencher o gráfico:** Rode o comando abaixo algumas vezes no terminal para gerar requisições e ver os gráficos subirem em tempo real:
  ```bash
  kubectl run test-traffic -n togglemaster --image=curlimages/curl -i --rm --restart=Never -- http://evaluation-service:8004/evaluate
  ```
* **Captura:** Tire um print da tela do Grafana mostrando as curvas de tráfego, recursos de CPU/RAM e os logs consolidados do Loki embaixo.

#### 📥 Print 2: Trace Distribuído no APM (New Relic)
* **Ação:** Acesse o console do [New Relic](https://one.newrelic.com).
* **Ação:** No menu esquerdo, clique em **APM & Services** e depois clique no serviço **`evaluation-service`**.
* **Ação:** No menu do serviço, clique em **Distributed Tracing** (ou **Traces** no menu lateral principal) e selecione a rota `/evaluate` na tabela.
* **Captura:** Tire um print mostrando a árvore de spans da transação detalhada (mostrando o `evaluation-service` chamando o `flag-service`, `targeting-service` e o `auth-service` em cascata) e o **Service Map**.

#### 📥 Print 3: Notificação de Incidente no ChatOps
* **Ação:** No Grafana, vá em **Alerting** > **Contact points**.
* **Ação:** Edite o Contact Point (Discord ou Slack), cole a URL do Webhook do canal de texto do seu grupo e salve.
* **Ação:** Clique em **Test** (canto superior direito) > **Send test notification** para enviar um alerta falso imediato.
* **Captura:** Tire um print da mensagem de teste rica que chegou no canal do seu Discord/Slack.

#### 📥 Print 4: Log de Autocura (Self-Healing)
* **Captura:** Copie ou tire print diretamente do log de sucesso gerado no terminal do receptor de autocura que simulamos:
  ```text
  2026-07-09 00:23:05,899 - INFO - Alerta recebido: {'status': 'firing', 'alerts': [{'status': 'firing', 'labels': {'alertname': 'EvaluationHighErrorRate'}}]}
  2026-07-09 00:23:05,900 - INFO - 🚨 ALERTA DISPARADO (FIRING) recebido. Iniciando autocura do evaluation-service...
  2026-07-09 00:23:05,931 - INFO - ✅ Self-healing executado com sucesso: rolling restart do evaluation-service disparado às 2026-07-09T00:23:05.916180+00:00
  2026-07-09 00:23:05,932 - INFO - 127.0.0.1 - - [09/Jul/2026 00:23:05] "POST /alert HTTP/1.1" 200 -
  ```

---

### [ ] Passo 2: Gravar o Vídeo de Demonstração (Até 25 Minutos)
Roteiro sugerido para a gravação da tela:

1. **Abertura (1-2 min):**
   * Apresente os membros do grupo e a proposta do trabalho da Fase 4.
2. **Infraestrutura e GitOps no ArgoCD (3-5 min):**
   * Mostre o painel do ArgoCD com todas as aplicações sincronizadas com o estado `Synced` e `Healthy`.
   * Comente brevemente que a stack de observabilidade e as aplicações estão integradas via GitOps.
3. **Métricas e Logs no Grafana + Loki (3-5 min):**
   * Mostre o dashboard customizado **"Pos-Tech"** no Grafana.
   * Faça uma chamada no terminal usando `curl` e mostre o gráfico de requisições subindo na hora, bem como os logs das aplicações consolidados pelo Loki.
4. **Service Map e Tracing no New Relic (5-7 min):**
   * Apresente o painel do New Relic APM.
   * Mostre o **Service Map** montado automaticamente mostrando a comunicação entre os 5 microsserviços.
   * Mostre o rastreamento detalhado (**Distributed Tracing**) de uma transação `/evaluate` mostrando as chamadas síncronas/assíncronas em cascata.
5. **Autocura (Self-Healing) (5 min):**
   * Demonstre o fluxo de autocura simulando o alerta do Grafana:
     * Rode o redirecionamento de porta do `webhook-receiver` no terminal.
     * Envie a chamada de simulação de alerta (`Invoke-RestMethod` no PowerShell).
     * Exiba o pod do `evaluation-service` sofrendo o rolling update automático (`kubectl get pods -n togglemaster -w` para mostrar o pod antigo terminando e o novo subindo).
     * Exiba os logs do `webhook-receiver` comprovando o sucesso da execução da autocura.
6. **Encerramento (1 min):**
   * Agradeça e conclua a apresentação. 
