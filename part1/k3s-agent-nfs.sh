#!/bin/bash
set -e

SERVER_IP="192.168.56.110"
AGENT_IP="192.168.56.111"
SHARED_DIR="/vagrant_shared"
TOKEN_FILE="${SHARED_DIR}/node-token"

echo "[AGENT] Mise à jour du système..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl

echo "[AGENT] Attente du token dans ${TOKEN_FILE}..."
timeout=120
counter=0
while [ ! -f "${TOKEN_FILE}" ]; do
  echo "[AGENT] Token non trouvé, attente... ($counter/$timeout secondes)"
  sleep 5
  counter=$((counter + 5))
  if [ $counter -ge $timeout ]; then
    echo "[AGENT] ERREUR: Timeout en attente du token"
    echo "[AGENT] Vérifiez que le serveur dravaonoS est bien démarré"
    exit 1
  fi
done

TOKEN=$(cat "${TOKEN_FILE}")
echo "[AGENT] Token récupéré!"

echo "[AGENT] Attente du serveur K3s sur https://${SERVER_IP}:6443..."
counter=0
until curl -k -s https://${SERVER_IP}:6443/healthz >/dev/null 2>&1; do
  echo "[AGENT] Serveur K3s non accessible, attente... ($counter/$timeout secondes)"
  sleep 5
  counter=$((counter + 5))
  if [ $counter -ge $timeout ]; then
    echo "[AGENT] ERREUR: Impossible de contacter le serveur K3s"
    exit 1
  fi
done

echo "[AGENT] Serveur K3s accessible, installation de l'agent..."
curl -sfL https://get.k3s.io | \
  K3S_URL="https://${SERVER_IP}:6443" \
  K3S_TOKEN="${TOKEN}" \
  INSTALL_K3S_EXEC="--node-ip=${AGENT_IP} --flannel-iface=eth1" \
  sh -

echo "[AGENT] Vérification du service K3s agent..."
sleep 5
systemctl status k3s-agent --no-pager || true

echo "[AGENT] Installation terminée!"
