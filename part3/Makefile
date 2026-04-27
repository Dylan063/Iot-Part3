all: install setup

install:
	@echo "=== Installation des dépendances ==="
	bash scripts/install.sh

setup:
	@echo "=== Configuration du cluster et Argo CD ==="
	bash scripts/setup.sh

clean:
	@echo "=== Nettoyage ==="
	k3d cluster delete iot 2>/dev/null || true
	-kill $$(lsof -t -i:8080) 2>/dev/null || true
	-kill $$(lsof -t -i:8888) 2>/dev/null || true
	@echo "Nettoyage terminé"

re: clean all

status:
	@echo "=== Namespaces ==="
	kubectl get ns
	@echo ""
	@echo "=== Pods Argo CD ==="
	kubectl get pods -n argocd
	@echo ""
	@echo "=== Pods Dev ==="
	kubectl get pods -n dev
	@echo ""
	@echo "=== Applications Argo CD ==="
	kubectl get application -n argocd

app:
	@echo "=== Test de l'application ==="
	curl -s http://localhost:8888
	@echo ""

logs:
	@echo "=== Logs de l'application ==="
	kubectl logs -n dev -l app=dravaono-playground --tail=50

argocd-password:
	@echo "=== Mot de passe Argo CD ==="
	@kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
	@echo ""

help:
	@echo "Commandes disponibles:"
	@echo "  make install          - Installer Docker, kubectl, K3d, Argo CD CLI"
	@echo "  make setup            - Créer le cluster et déployer Argo CD"
	@echo "  make status           - Afficher le statut du cluster"
	@echo "  make app              - Tester l'application"
	@echo "  make logs             - Voir les logs de l'application"
	@echo "  make argocd-password  - Afficher le mot de passe Argo CD"
	@echo "  make clean            - Supprimer le cluster"
	@echo "  make re               - Nettoyer et tout réinstaller"

.PHONY: all install setup clean re status app logs argocd-password help