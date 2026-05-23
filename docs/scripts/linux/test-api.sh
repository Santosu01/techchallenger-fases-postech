#!/bin/bash
# ==========================================
# TESTAR SERVIÇOS - ToggleMaste
# ==========================================
# EDITE AS VARIAVEIS ABAIXO:

# Namespace
NAMESPACE="togglemaster"

# ==========================================
# INÍCIO DO SCRIPT
# ==========================================

echo "=========================================="
echo "Testar Serviços - ToggleMaster"
echo "=========================================="

# Obter URL do Ingress
INGRESS_URL=$(kubectl get ingress togglemaster-ingress -n "$NAMESPACE" \
  -o jsonpath="{.status.loadBalancer.ingress[0].hostname}" 2>/dev/null)

if [ -z "$INGRESS_URL" ]; then
    echo "ERRO: Não foi possível obter a URL do Ingress."
    echo "Verifique se o ingress foi criado e possui endereço externo."
    exit 1
fi

echo ""
echo "Ingress URL: http://$INGRESS_URL"
echo ""

echo "=========================================="
echo "TESTE 1: Health Checks"
echo "=========================================="
echo ""
echo "[1/5] Auth Service..."
curl -s "http://$INGRESS_URL/auth/health"
echo ""

echo "[2/5] Flag Service..."
curl -s "http://$INGRESS_URL/flags/health"
echo ""

echo "[3/5] Targeting Service..."
curl -s "http://$INGRESS_URL/targeting/health"
echo ""

echo "[4/5] Evaluation Service..."
curl -s "http://$INGRESS_URL/evaluate/health"
echo ""

echo "[5/5] Analytics Service..."
curl -s "http://$INGRESS_URL/analytics/health"
echo ""

echo ""
echo "=========================================="
echo "TESTE 2: Criar Usuario"
echo "=========================================="
curl -s -X POST "http://$INGRESS_URL/auth/register" \
  -H "Content-Type: application/json" \
  -d '{"email":"teste@example.com","password":"123456"}'
echo ""
echo ""

echo "=========================================="
echo "TESTE 3: Listar Flags"
echo "=========================================="
curl -s "http://$INGRESS_URL/flags"
echo ""
echo ""

echo "=========================================="
echo "TESTE 4: Avaliar Flag"
echo "=========================================="
curl -s -X POST "http://$INGRESS_URL/evaluate" \
  -H "Content-Type: application/json" \
  -d '{"flagName":"test","userId":"user123"}'
echo ""
echo ""

echo "=========================================="
echo "TESTE 5: Analytics Stats"
echo "=========================================="
curl -s "http://$INGRESS_URL/analytics/stats"
echo ""
echo ""

echo "=========================================="
echo "Testes concluídos!"
echo "=========================================="
echo ""
