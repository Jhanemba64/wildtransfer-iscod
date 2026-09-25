#!/usr/bin/env bash
# Déploie ou met à jour l'application sur un serveur préparé par provision.sh.
# Usage (depuis la racine du dépôt) :
#   [APP_ENV=production|staging] [IMAGE_TAG=sha-1a2b3c4] ./infra/scripts/deploy.sh ubuntu@<serveur>
# Secrets : infra/app/backend.env et storage-api.env (prod) ou backend.staging.env et
# storage-api.staging.env (staging), non versionnés. Absents en local (CI) : ceux du serveur sont conservés.
# Si les conteneurs ne deviennent pas sains, la version précédente est redéployée automatiquement.
# Les variables sont volontairement développées côté client dans les commandes ssh.
# shellcheck disable=SC2029
set -euo pipefail

TARGET=${1:?usage : deploy.sh utilisateur@serveur}
APP_ENV=${APP_ENV:-production}
IMAGE_TAG=${IMAGE_TAG:-latest}
APP_DIR="$(cd "$(dirname "$0")/../app" && pwd)"

case "$APP_ENV" in
    production) REMOTE_DIR=/opt/wildtransfer;         APP_PORT=7007; SUFFIX="" ;;
    staging)    REMOTE_DIR=/opt/wildtransfer-staging; APP_PORT=7008; SUFFIX=".staging" ;;
    *) echo "APP_ENV inconnu : $APP_ENV (production ou staging)"; exit 1 ;;
esac

echo "==> [$APP_ENV] Envoi de la configuration vers $TARGET:$REMOTE_DIR"
ssh "$TARGET" "sudo mkdir -p $REMOTE_DIR && sudo chown \$USER $REMOTE_DIR"
scp -q "$APP_DIR/docker-compose.yml" "$APP_DIR/nginx.conf" "$TARGET:$REMOTE_DIR/"
for f in backend storage-api; do
    if [ -f "$APP_DIR/$f$SUFFIX.env" ]; then
        scp -q "$APP_DIR/$f$SUFFIX.env" "$TARGET:$REMOTE_DIR/$f.env"
    else
        ssh "$TARGET" "test -f $REMOTE_DIR/$f.env" \
            || { echo "Secrets manquants : infra/app/$f$SUFFIX.env (partir de $f.env.example)"; exit 1; }
    fi
done

PREVIOUS_TAG=$(ssh "$TARGET" "sed -n 's/^IMAGE_TAG=//p' $REMOTE_DIR/.env 2>/dev/null" || true)

up() {
    ssh "$TARGET" "cd $REMOTE_DIR && chmod 600 *.env \
        && printf 'IMAGE_TAG=%s\nAPP_PORT=%s\n' $1 $APP_PORT > .env \
        && sudo docker compose pull -q \
        && sudo docker compose up -d --remove-orphans --wait --wait-timeout 240"
}

echo "==> [$APP_ENV] Déploiement des images $IMAGE_TAG (version précédente : ${PREVIOUS_TAG:-aucune})"
if up "$IMAGE_TAG"; then
    ssh "$TARGET" "cd $REMOTE_DIR && sudo docker compose ps --format 'table {{.Service}}\t{{.Image}}\t{{.Status}}'"
    echo "==> [$APP_ENV] Déployé : $IMAGE_TAG"
else
    echo "==> [$APP_ENV] ÉCHEC : conteneurs non sains."
    if [ -n "$PREVIOUS_TAG" ] && [ "$PREVIOUS_TAG" != "$IMAGE_TAG" ]; then
        echo "==> [$APP_ENV] Retour arrière vers $PREVIOUS_TAG"
        up "$PREVIOUS_TAG"
    fi
    exit 1
fi
