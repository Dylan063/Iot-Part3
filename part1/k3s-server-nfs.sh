#!/bin/bash
set -e

SERVER_IP="192.168.56.110"
SHARED_DIR="/vagrant_shared"
TOKEN_FILE="${SHARED_DIR}/node-token"

echo "[SERVER] Mise à jour du système..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get install -y curl

echo "[SERVER] Installation de K3s server..."
curl -sfL https://get.k3s.io | \
  INSTALL_K3S_EXEC="server --node-ip=${SERVER_IP} --advertise-address=${SERVER_IP} --bind-address=${SERVER_IP} --flannel-iface=eth1 --tls-san=${SERVER_IP} --write-kubeconfig-mode=644" \
  sh -

echo "[SERVER] Attente du démarrage de K3s..."
sleep 15

echo "[SERVER] Attente du token..."
timeout=60
counter=0
while [ ! -f /var/lib/rancher/k3s/server/node-token ]; do
  sleep 2
  counter=$((counter + 2))
  if [ $counter -ge $timeout ]; then
    echo "[SERVER] ERREUR: Timeout en attente du token"
    exit 1
  fi
done

echo "[SERVER] Copie du token dans le dossier partagé..."
cp /var/lib/rancher/k3s/server/node-token "${TOKEN_FILE}"
chmod 644 "${TOKEN_FILE}"

echo "[SERVER] Token sauvegardé: ${TOKEN_FILE}"

echo "[SERVER] Configuration de kubectl..."
mkdir -p /home/vagrant/.kube
cp /etc/rancher/k3s/k3s.yaml /home/vagrant/.kube/config
chown -R vagrant:vagrant /home/vagrant/.kube
chmod 600 /home/vagrant/.kube/config

cat <<EOF > /etc/profile.d/k3s.sh
export KUBECONFIG=/etc/rancher/k3s/k3s.yaml
export PATH=\$PATH:/usr/local/bin
EOF

echo "[SERVER] Installation terminée!"
sleep 5
/usr/local/bin/kubectl get nodes || echo "[SERVER] Nodes pas encore prêts"
