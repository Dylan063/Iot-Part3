#!/bin/bash
set -e

SERVER_IP="192.168.56.110"

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
