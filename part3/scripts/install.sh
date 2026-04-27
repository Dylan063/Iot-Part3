#!/bin/bash
set -e

echo "=== Installation des dépendances Part 3 ==="

echo "[1/4] Installation de Docker..."
if command -v docker &> /dev/null; then
    echo "Docker déjà installé ($(docker --version))"
else
    sudo apt-get update -qq
    sudo apt-get install -y ca-certificates curl gnupg lsb-release apt-transport-https
    sudo install -m 0755 -d /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    sudo chmod a+r /etc/apt/keyrings/docker.gpg
    echo \
    "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
    sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update -qq
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    sudo usermod -aG docker $USER
    echo "✓ Docker installé"
fi

echo "[2/4] Installation de kubectl..."
if command -v kubectl &> /dev/null; then
    echo "kubectl déjà installé ($(kubectl version --client --short 2>/dev/null || kubectl version --client))"
else
    curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
    sudo install -o root -g root -m 0755 kubectl /usr/local/bin/kubectl
    rm -f kubectl
    echo "✓ kubectl installé"
fi

echo "[3/4] Installation de K3d..."
if command -v k3d &> /dev/null; then
    echo "K3d déjà installé ($(k3d --version | head -n1))"
else
    curl -s https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | bash
    echo "✓ K3d installé"
fi

ARGOCD_VERSION="v2.9.3"
echo "[4/4] Installation de Argo CD CLI ${ARGOCD_VERSION}..."
CURRENT_ARGOCD=$(argocd version --client --short 2>/dev/null || echo "")
if echo "$CURRENT_ARGOCD" | grep -q "${ARGOCD_VERSION}"; then
    echo "Argo CD CLI déjà installé ($CURRENT_ARGOCD)"
else
    echo "Installation de Argo CD CLI ${ARGOCD_VERSION} (doit correspondre au serveur)..."
    sudo rm -f /usr/local/bin/argocd
    curl -sSL -o argocd "https://github.com/argoproj/argo-cd/releases/download/${ARGOCD_VERSION}/argocd-linux-amd64"
    sudo install -m 555 argocd /usr/local/bin/argocd
    rm -f argocd
    echo "✓ Argo CD CLI ${ARGOCD_VERSION} installé"
fi

echo ""
echo "=== Installation terminée ==="
echo ""
echo "Versions installées:"
docker --version 2>/dev/null || echo "Docker: non disponible"
kubectl version --client --short 2>/dev/null || kubectl version --client 2>/dev/null || echo "kubectl: non disponible"
k3d --version 2>/dev/null | head -n1 || echo "K3d: non disponible"
argocd version --client --short 2>/dev/null || echo "Argo CD CLI: installé"

echo ""
if groups | grep -q docker; then
    echo "✓ Vous êtes déjà dans le groupe docker"
else
    echo "⚠ IMPORTANT: Vous devez vous déconnecter et reconnecter pour que Docker fonctionne"
    echo "   OU exécuter: newgrp docker"
fi