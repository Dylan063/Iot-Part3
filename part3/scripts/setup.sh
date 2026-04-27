#!/bin/bash
set -e

GITHUB_REPO="https://github.com/Dylan063/Iot-Part3.git"
ARGOCD_VERSION="v2.9.3"
MANIFEST_URL="https://raw.githubusercontent.com/argoproj/argo-cd/${ARGOCD_VERSION}/manifests/install.yaml"

echo "[1/8] Cleanup..."
pkill -f "port-forward" 2>/dev/null || true
k3d cluster delete iot 2>/dev/null || true

echo "[2/8] Creating K3d cluster..."
k3d cluster create iot \
  -p "8888:8888@loadbalancer" \
  --wait
echo "  Waiting for node..."
kubectl wait --for=condition=Ready nodes --all --timeout=60s

echo "[3/8] Creating namespaces..."
kubectl create namespace argocd
kubectl create namespace dev

echo "[4/8] Installing Argo CD ${ARGOCD_VERSION}..."
TMPFILE=$(mktemp /tmp/argocd-manifest.XXXXXX.yaml)
curl -sSL "$MANIFEST_URL" -o "$TMPFILE"

python3 -c "
import sys
content = open('$TMPFILE').read()
# Replace Docker Hub redis image with ECR mirror
content = content.replace('redis:7.0.11-alpine', 'public.ecr.aws/docker/library/redis:7.0-alpine')
docs = content.split('\n---')
result = []
for doc in docs:
    if 'kind: NetworkPolicy' not in doc:
        result.append(doc)
sys.stdout.write('\n---'.join(result))
" | kubectl apply -n argocd -f -
rm -f "$TMPFILE"

echo "[5/8] Waiting for Argo CD to start (this may take 2-3 minutes)..."
sleep 10
echo "  Waiting for pods to be created..."
until [ "$(kubectl get pods -n argocd --no-headers 2>/dev/null | wc -l)" -ge 5 ]; do
  sleep 5
done

echo "  Waiting for all deployments..."
kubectl rollout status deployment/argocd-redis -n argocd --timeout=300s
kubectl rollout status deployment/argocd-repo-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-dex-server -n argocd --timeout=300s
kubectl rollout status deployment/argocd-applicationset-controller -n argocd --timeout=300s
kubectl rollout status deployment/argocd-notifications-controller -n argocd --timeout=300s
echo "  All ArgoCD deployments rolled out."

kubectl wait --for=condition=Established crd/applications.argoproj.io --timeout=60s

echo "[6/8] Getting Argo CD credentials..."
RETRIES=0
while ! kubectl -n argocd get secret argocd-initial-admin-secret >/dev/null 2>&1; do
  RETRIES=$((RETRIES + 1))
  if [ "$RETRIES" -ge 30 ]; then
    echo "ERROR: admin secret never created"
    kubectl get pods -n argocd
    exit 1
  fi
  sleep 5
done
ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
  -o jsonpath="{.data.password}" | base64 -d)

echo "[7/9] Pre-loading application image..."
if ! docker image inspect wil42/playground:v1 >/dev/null 2>&1; then
  docker pull wil42/playground:v1
fi
k3d image import wil42/playground:v1 -c iot

echo "[8/9] Creating ArgoCD Application..."
cat <<EOF | kubectl apply -f -
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: dravaono-playground
  namespace: argocd
spec:
  project: default
  source:
    repoURL: ${GITHUB_REPO}
    targetRevision: HEAD
    path: .
  destination:
    server: https://kubernetes.default.svc
    namespace: dev
  syncPolicy:
    automated:
      selfHeal: true
      prune: true
EOF

echo "[9/9] Waiting for application in dev namespace..."
RETRIES=0
while [ "$(kubectl get pods -n dev --no-headers 2>/dev/null | wc -l)" -eq 0 ]; do
  RETRIES=$((RETRIES + 1))
  if [ "$RETRIES" -ge 60 ]; then
    echo "ERROR: no pods appeared in dev namespace"
    echo "ArgoCD app status:"
    kubectl get application -n argocd -o wide 2>/dev/null
    exit 1
  fi
  sleep 5
done
kubectl rollout status deployment/dravaono-playground -n dev --timeout=120s

kubectl port-forward svc/argocd-server -n argocd 8080:443 >/dev/null 2>&1 &

sleep 3
argocd login localhost:8080 \
  --username admin \
  --password "$ARGOCD_PASSWORD" \
  --insecure 2>/dev/null || echo "  (CLI login skipped — use the web UI instead)"

echo ""
echo "=========================================="
echo "  Setup complete!"
echo "=========================================="
echo "  Argo CD UI:   https://localhost:8080"
echo "  Username:     admin"
echo "  Password:     $ARGOCD_PASSWORD"
echo "  Application:  http://localhost:8888"
echo "=========================================="
echo ""
sleep 2
curl -s http://localhost:8888 || echo "(App may need a few more seconds)"
echo ""