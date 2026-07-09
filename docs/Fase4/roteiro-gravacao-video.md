# 🎬 Roteiro de Gravação e Script do Vídeo (Fase 4)

Este roteiro foi elaborado para guiar a gravação do seu vídeo de apresentação da **Fase 4 (até 25 minutos)**. Ele divide a gravação em blocos de tempo, indicando exatamente **o que mostrar**, **o que executar**, **o que falar** e quais pastas do projeto destacar.

---

## 🏗️ Preparação Antes de Gravar (Checklist Inicial)
Deixe estas abas do navegador já abertas para agilizar a transição:
1. **Aba 1:** Console do ArgoCD ([https://localhost:8080](https://localhost:8080)) - *Login feito.*
2. **Aba 2:** Dashboard do Grafana ([http://localhost:3000](http://localhost:3000)) - *Login feito no Dashboard "Pos-Tech".*
3. **Aba 3:** Console do New Relic ([https://one.newrelic.com](https://one.newrelic.com)) - *Login feito na aba "APM & Services".*
4. **Aba 4:** Canal do Discord/Slack com a notificação recebida do Webhook.
5. **VS Code:** Aberto na raiz do projeto com a estrutura de arquivos visível na barra lateral esquerda.
6. **Terminais abertos:** 
   * **Terminal 1:** Rodando o port-forward do ArgoCD: `kubectl port-forward service/argocd-server -n argocd 8080:443`
   * **Terminal 2:** Rodando o port-forward do Grafana: `kubectl port-forward svc/grafana 3000:80 -n monitoring`
   * **Terminal 3:** Livre para execução de comandos (`kubectl get pods`, `curl`, etc.).

---

## ⏱️ Roteiro Passo a Passo do Vídeo

### Bloco 1: Introdução e Estrutura do Projeto
* **Tempo sugerido:** 00:00 - 02:30 (2.5 minutos)
* **O que mostrar na tela:** O editor de código (VS Code) exibindo as pastas do projeto.
* **Pastas a destacar no VS Code:**
  * [gitops/](file:///c:/Users/anale/OneDrive/Documentos/Carreira/Pós/Fase%202/techchallenger-fase-2/gitops) (onde estão os manifestos Kubernetes das apps e de monitoramento).
  * [infra/terraform/](file:///c:/Users/anale/OneDrive/Documentos/Carreira/Pós/Fase%202/techchallenger-fase-2/infra/terraform) (IaC do cluster EKS e RDS PostgreSQL).
  * [docs/Fase4/](file:///c:/Users/anale/OneDrive/Documentos/Carreira/Pós/Fase%202/techchallenger-fase-2/docs/Fase4) (relatórios técnicos e de testes).
* **Falas sugeridas:**
  > "Olá, professores e avaliadores. Somos o grupo [Nome/Número do Grupo] e vamos apresentar a entrega do Tech Challenge Fase 4. O objetivo desta fase foi estruturar a observabilidade completa, GitOps e resiliência (autocura) de nossa aplicação distribuída no Amazon EKS. 
  > Aqui no VS Code, podemos ver a estrutura do nosso projeto: a pasta 'infra' com o provisionamento Terraform do EKS e dos bancos de dados RDS; a pasta 'gitops' que gerencia todo o estado do cluster de forma declarativa; e a pasta 'docs' contendo todos os relatórios de arquitetura e decisões de projeto."

---

### Bloco 2: Sincronização Declarativa com GitOps (ArgoCD)
* **Tempo sugerido:** 02:30 - 06:00 (3.5 minutos)
* **O que mostrar na tela:** O navegador na aba do **ArgoCD**.
* **Falas sugeridas:**
  > "Para garantir o deploy contínuo e a conformidade do ambiente, implementamos o GitOps utilizando o ArgoCD. 
  > Como podem ver no painel, temos as aplicações sincronizadas com sucesso. O ArgoCD monitora o nosso repositório no GitHub na branch 'Fase4' e aplica automaticamente no cluster qualquer alteração. 
  > Temos a aplicação principal 'togglemaster-apps' gerando nossos 5 microsserviços (`auth`, `flag`, `targeting`, `evaluation` e `analytics`), todos em estado 'Healthy' e 'Synced', conectando-se de forma segura às instâncias do RDS PostgreSQL. 
  > E ao lado, temos o aplicativo 'monitoring-stack', que gerencia nossa stack de observabilidade declarativamente no namespace `monitoring`."

---

### Bloco 3: Observabilidade com Grafana e Loki
* **Tempo sugerido:** 06:00 - 10:00 (4 minutos)
* **O que mostrar na tela:** O navegador na aba do **Grafana** (Dashboard "Pos-Tech") e o Terminal 3.
* **Comando a executar no Terminal 3:**
  ```bash
  # Execute este comando 3 a 5 vezes para movimentar os gráficos ao vivo:
  kubectl run test-traffic -n togglemaster --image=curlimages/curl -i --rm --restart=Never -- http://evaluation-service:8004/evaluate
  ```
* **Falas sugeridas:**
  > "Vamos agora para o Grafana. Criamos um dashboard customizado chamado 'Pos-Tech' para centralizar a visualização da integridade do sistema. 
  > Na parte superior do painel, monitoramos os recursos de CPU e memória RAM dos nós do cluster Kubernetes. 
  > No meio, temos o gráfico de taxa de requisições por segundo dos microsserviços. Vou rodar um comando de teste no terminal enviando requisições à rota `/evaluate`. Observem que o gráfico atualiza dinamicamente registrando o tráfego de entrada. 
  > Na parte inferior do painel, integramos o Grafana Loki. Todos os logs de stdout e stderr dos 5 microsserviços do cluster são consolidados aqui, permitindo fazer pesquisas rápidas e correlacionar erros diretamente com picos de tráfego, sem precisar acessar a linha de comando."

---

### Bloco 4: Rastreamento Distribuído no APM (New Relic)
* **Tempo sugerido:** 10:00 - 15:00 (5 minutos)
* **O que mostrar na tela:** O navegador na aba do **New Relic** (APM & Services > evaluation-service).
* **Falas sugeridas:**
  > "Para a observabilidade no nível da aplicação (APM), configuramos o OpenTelemetry Collector no cluster para exportar dados para a nuvem do New Relic utilizando o protocolo OTLP/HTTP. 
  > Ao abrirmos a visão do `evaluation-service`, podemos ver o **Service Map** (Mapa de Serviço) gerado automaticamente. Ele ilustra visualmente o fluxo de comunicação: quando um cliente chama a API de avaliação de flags, ela se comunica de maneira distribuída com os serviços de banco de dados, autorização, flags e segmentação. 
  > Se clicarmos em **Traces** (Distributed Tracing) e selecionarmos a transação `/evaluate`, temos uma visão detalhada do tempo de resposta. Conseguimos ver cada etapa da chamada (spans), permitindo descobrir gargalos e latências instantaneamente em qualquer microsserviço da cadeia."

---

### Bloco 5: ChatOps e Notificação de Incidentes
* **Tempo sugerido:** 15:00 - 18:00 (3 minutos)
* **O que mostrar na tela:** O navegador na aba do Grafana (Alerting) e depois a aba do **Discord/Slack**.
* **Ação no Grafana:** Vá em *Alerting* > *Contact points*, selecione o seu canal e clique em **Test** > **Send test notification**.
* **Falas sugeridas:**
  > "Para garantir que o time de engenharia seja notificado rapidamente em caso de falhas, estruturamos uma integração de ChatOps. 
  > Configuramos regras de alertas de alta taxa de erro no Grafana. Quando um limite é atingido, o alerta é enviado por Webhook a um canal corporativo. 
  > Vou forçar o disparo de uma notificação de teste direto do Grafana. Como podem ver no nosso canal do Discord [ou Slack], a notificação rica chega imediatamente informando o nome do alerta, a gravidade e o link de acesso rápido ao painel correspondente."

---

### Bloco 6: Autocura em Ação (Self-Healing)
* **Tempo sugerido:** 18:00 - 23:00 (5 minutos)
* **O que mostrar na tela:** Terminal dividido ao meio (Split-pane) ou duas janelas de terminal lado a lado:
  * **Janela Superior:** Executando `kubectl get pods -n togglemaster -w` (para ver os pods mudando de estado ao vivo).
  * **Janela Inferior:** Para disparar o comando de simulação.
* **Comando 1 (Port-forward do webhook) no Terminal 1 (garanta que esteja rodando):**
  ```bash
  kubectl port-forward svc/webhook-receiver -n monitoring 5000:5000
  ```
* **Comando 2 (Simulação do Alerta) na Janela Inferior:**
  ```powershell
  Invoke-RestMethod -Uri "http://localhost:5000/alert" -Method Post -ContentType "application/json" -Body '{"status":"firing","alerts":[{"status":"firing","labels":{"alertname":"EvaluationHighErrorRate"}}]}'
  ```
* **Comando 3 (Logs de Autocura) logo em seguida:**
  ```bash
  kubectl logs -n monitoring -l app=webhook-receiver --tail=10
  ```
* **Falas sugeridas:**
  > "A cereja do bolo da nossa arquitetura de resiliência é o mecanismo de **Self-Healing (Autocura)**. Desenvolvemos um microsserviço receptor (`webhook-receiver`) que escuta alertas críticos de falha do Grafana. 
  > Se o `evaluation-service` apresentar instabilidade ou erros persistentes, o Grafana envia um POST para o receptor. O receptor se comunica com a API interna do Kubernetes e inicia um rolling update do serviço afetado para limpar conexões travadas ou falhas de memória. 
  > Vamos simular o Grafana disparando o alerta crítico no terminal de baixo. 
  > Observem a janela de cima: assim que o alerta é recebido, o Kubernetes inicia imediatamente a terminação do pod com problemas e sobe uma nova réplica saudável de forma transparente e automática. 
  > Ao consultarmos os logs do webhook receiver, podemos ver o registro exato: Alerta recebido, rolling restart disparado com sucesso. O sistema se recuperou sozinho sem necessidade de intervenção humana manual."

---

### Bloco 7: Conclusão
* **Tempo sugerido:** 23:00 - 24:00 (1 minuto)
* **O que mostrar na tela:** O painel do ArgoCD ou do Grafana.
* **Falas sugeridas:**
  > "Com isso, demonstramos a entrega de um ambiente resiliente, escalável, monitorado de ponta a ponta e governado pelas melhores práticas de IaC e GitOps. Agradecemos a atenção de todos e estamos à disposição para dúvidas."

---

## 💡 Dicas de Sucesso para a Gravação
* **Qualidade de Áudio:** Utilize um fone com microfone limpo em um ambiente silencioso.
* **Sem Pressa:** Fale de forma pausada e natural. Se errar alguma palavra, pare por 3 segundos e repita a frase (você pode editar o vídeo depois facilmente ou apenas continuar de forma natural).
* **Conexão Segura:** Lembre-se de aceitar o alerta de certificado SSL do ArgoCD (`https://localhost:8080`) antes de começar a filmar para evitar surpresas na hora de mostrar o console.
