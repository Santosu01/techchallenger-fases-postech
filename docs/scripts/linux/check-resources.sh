#!/bin/bash
# ==========================================
# VERIFICAR STATUS - ToggleMaste
# ==========================================
# EDITE AS VARIAVEIS ABAIXO:

# Região AWS
REGIAO="us-east-1"

# Cluster EKS
CLUSTER_NAME="togglemaster-cluster"
NAMESPACE="togglemaster"

# ==========================================
# INÍCIO DO SCRIPT
# ==========================================

echo "=========================================="
echo "Status dos Recursos - ToggleMaster"
echo "=========================================="

echo ""
echo "=========================================="
echo "CLUSTER EKS"
echo "=========================================="
echo "Cluster: $CLUSTER_NAME"
aws eks describe-cluster --name "$CLUSTER_NAME" --region "$REGIAO" \
  --query "cluster.status" --output text

echo ""
echo "=========================================="
echo "NODES"
echo "=========================================="
kubectl get nodes

echo ""
echo "=========================================="
echo "PODS - Namespace: $NAMESPACE"
echo "=========================================="
kubectl get pods -n "$NAMESPACE"

echo ""
echo "=========================================="
echo "SERVICES - Namespace: $NAMESPACE"
echo "=========================================="
kubectl get services -n "$NAMESPACE"

echo ""
echo "=========================================="
echo "INGRESS - Namespace: $NAMESPACE"
echo "=========================================="
kubectl get ingress -n "$NAMESPACE"

echo ""
echo "=========================================="
echo "HPA - Namespace: $NAMESPACE"
echo "=========================================="
kubectl get hpa -n "$NAMESPACE"

echo ""
echo "=========================================="
echo "INGRESS URL"
echo "=========================================="
INGRESS_URL=$(kubectl get ingress togglemaster-ingress -n "$NAMESPACE" \
  -o jsonpath="{.status.loadBalancer.ingress[0].hostname}" 2>/dev/null)
if [ -n "$INGRESS_URL" ]; then
    echo "URL: http://$INGRESS_URL"
else
    echo "Ingress não encontrado ou não possui endereço externo ainda."
fi

echo ""
echo "=========================================="
echo "RDS INSTANCES"
echo "=========================================="
aws rds describe-db-instances --region "$REGIAO" \
  --query "DBInstances[?contains(DBInstanceIdentifier, 'togglemaster')].{ID:DBInstanceIdentifier,Status:DBInstanceStatus,Endpoint:Endpoint.Address}" \
  --output table

echo ""
echo "=========================================="
echo "ELASTICACHE"
echo "=========================================="
aws elasticache describe-cache-clusters --region "$REGIAO" \
  --query "CacheClusters[?contains(CacheClusterId, 'togglemaster')].{ID:CacheClusterId,Status:CacheClusterStatus,Endpoint:CacheNodes[0].Endpoint.Address}" \
  --output table

echo ""
echo "=========================================="
echo "DYNAMODB TABLES"
echo "=========================================="
aws dynamodb list-tables --region "$REGIAO" \
  --query "TableNames[?contains(@, 'Toggle')]" \
  --output table

echo ""
