#!/usr/bin/env bash
# Déploie ou met à jour l'application sur un serveur préparé par provision.sh.
# Usage (depuis la racine du dépôt) : ./infra/scripts/deploy.sh ubuntu@<serveur>
# Pré-requis : infra/app/backend.env et infra/app/storage-api.env (copiés des *.env.example, non versionnés).
set -euo pipefail

TARGET=${1:?usage : deploy.sh utilisateur@serveur}
APP_DIR="$(cd "$(dirname "$0")/../app" && pwd)"
REMOTE_DIR=/opt/wildtransfer

for f in backend.env storage-api.env; do
    [ -f "$APP_DIR/$f" ] || { echo "Manquant : infra/app/$f (partir de $f.example)"; exit 1; }
done

echo "==> Envoi de la configuration vers $TARGET:$REMOTE_DIR"
ssh "$TARGET" "sudo mkdir -p $REMOTE_DIR && sudo chown \$USER $REMOTE_DIR"
scp "$APP_DIR/docker-compose.yml" "$APP_DIR/nginx.conf" \
    "$APP_DIR/backend.env" "$APP_DIR/storage-api.env" "$TARGET:$REMOTE_DIR/"

echo "==> Téléchargement des images et démarrage"
ssh "$TARGET" "cd $REMOTE_DIR && chmod 600 *.env && sudo docker compose pull -q && sudo docker compose up -d --remove-orphans && sudo docker compose ps"

echo "==> Déployé. Vérification : curl -I https://<domaine>/"
