#!/usr/bin/env bash
# Déploie ou met à jour l'application sur le cluster Kubernetes (k3s) d'un serveur préparé par provision.sh.
# Usage (depuis la racine du dépôt) :
#   [APP_ENV=production|staging] [IMAGE_TAG=sha-1a2b3c4] ./infra/scripts/deploy.sh ubuntu@<serveur>
# Manifestes : infra/k8s (un namespace par environnement). Secrets : infra/app/backend.env et storage-api.env
# (prod) ou backend.staging.env et storage-api.staging.env (staging), non versionnés. Absents en local (CI) :
# ceux du serveur sont conservés.
# Kubernetes remplace les pods un par un (mise à jour progressive) ; si la nouvelle version ne devient pas
# saine, la version précédente est redéployée automatiquement.
# Les variables sont volontairement développées côté client dans les commandes ssh.
# shellcheck disable=SC2029
set -euo pipefail

TARGET=${1:?usage : deploy.sh utilisateur@serveur}
APP_ENV=${APP_ENV:-production}
IMAGE_TAG=${IMAGE_TAG:-latest}
INFRA_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$INFRA_DIR/app"
KUBECTL="sudo k3s kubectl"

case "$APP_ENV" in
    production) REMOTE_DIR=/opt/wildtransfer;         NAMESPACE=wildtransfer;         SUFFIX="" ;;
    staging)    REMOTE_DIR=/opt/wildtransfer-staging; NAMESPACE=wildtransfer-staging; SUFFIX=".staging" ;;
    *) echo "APP_ENV inconnu : $APP_ENV (production ou staging)"; exit 1 ;;
esac

echo "==> [$APP_ENV] Envoi des manifestes vers $TARGET:$REMOTE_DIR"
ssh "$TARGET" "sudo mkdir -p $REMOTE_DIR && sudo chown \$USER $REMOTE_DIR && rm -rf $REMOTE_DIR/k8s"
scp -q -r "$INFRA_DIR/k8s" "$TARGET:$REMOTE_DIR/"
for f in backend storage-api; do
    if [ -f "$APP_DIR/$f$SUFFIX.env" ]; then
        scp -q "$APP_DIR/$f$SUFFIX.env" "$TARGET:$REMOTE_DIR/$f.env"
    else
        ssh "$TARGET" "test -f $REMOTE_DIR/$f.env" \
            || { echo "Secrets manquants : infra/app/$f$SUFFIX.env (partir de $f.env.example)"; exit 1; }
    fi
done

PREVIOUS_TAG=$(ssh "$TARGET" "sed -n 's/^IMAGE_TAG=//p' $REMOTE_DIR/.env 2>/dev/null" || true)

# Assemblage du déploiement : manifestes de l'environnement + secrets + version des images
kustomization() {
    cat <<EOF
apiVersion: kustomize.config.k8s.io/v1beta1
kind: Kustomization
namespace: $NAMESPACE
resources:
  - k8s/overlays/$APP_ENV
secretGenerator:
  - name: backend-env
    envs: [backend.env]
  - name: storage-api-env
    envs: [storage-api.env]
images:
  - name: pierrick64/wildtransfer-backend
    newTag: $1
  - name: pierrick64/wildtransfer-frontend
    newTag: $1
  - name: pierrick64/wildtransfer-storage-api
    newTag: $1
EOF
}

deploy() {
    kustomization "$1" | ssh "$TARGET" "cat > $REMOTE_DIR/kustomization.yaml"
    ssh "$TARGET" "cd $REMOTE_DIR && chmod 600 *.env && printf 'IMAGE_TAG=%s\n' $1 > .env \
        && $KUBECTL apply -k . \
        && for r in statefulset/db deployment/backend deployment/storage-api deployment/frontend deployment/api-gateway; do \
               $KUBECTL -n $NAMESPACE rollout status \$r --timeout=240s || exit 1; \
           done"
}

echo "==> [$APP_ENV] Déploiement des images $IMAGE_TAG (version précédente : ${PREVIOUS_TAG:-aucune})"
if deploy "$IMAGE_TAG"; then
    ssh "$TARGET" "$KUBECTL -n $NAMESPACE get pods -o wide"
    echo "==> [$APP_ENV] Déployé : $IMAGE_TAG"
else
    echo "==> [$APP_ENV] ÉCHEC : la nouvelle version n'est pas devenue saine."
    if [ -n "$PREVIOUS_TAG" ] && [ "$PREVIOUS_TAG" != "$IMAGE_TAG" ]; then
        echo "==> [$APP_ENV] Retour arrière vers $PREVIOUS_TAG"
        deploy "$PREVIOUS_TAG"
    fi
    exit 1
fi
