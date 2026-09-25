#!/usr/bin/env bash
# Déploie ou met à jour la supervision (Prometheus, Grafana, Alertmanager, sondes) sur le serveur.
# Usage (depuis la racine du dépôt) : ./infra/scripts/deploy-monitoring.sh ubuntu@<serveur>
# Secrets : infra/monitoring/monitoring.env (non versionné, partir de monitoring.env.example).
# REMOTE_DIR est volontairement développé côté client dans les commandes ssh.
# shellcheck disable=SC2029
set -euo pipefail

TARGET=${1:?usage : deploy-monitoring.sh utilisateur@serveur}
MON_DIR="$(cd "$(dirname "$0")/../monitoring" && pwd)"
REMOTE_DIR=/opt/wildtransfer-monitoring

[ -f "$MON_DIR/monitoring.env" ] || { echo "Manquant : infra/monitoring/monitoring.env (partir de monitoring.env.example)"; exit 1; }
set -a
# Fichier de secrets local, absent du dépôt
# shellcheck disable=SC1091
. "$MON_DIR/monitoring.env"
set +a
: "${GRAFANA_ADMIN_PASSWORD:?}" "${GRAFANA_URL:?}" "${ALERT_EMAIL:?}" "${SMTP_PASSWORD:?}"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
# Remplissage du modèle (perl : sûr quels que soient les caractères du mot de passe)
# shellcheck disable=SC2016
perl -pe 's/\$SMTP_PASSWORD/$ENV{SMTP_PASSWORD}/g; s/\$ALERT_EMAIL/$ENV{ALERT_EMAIL}/g' \
    "$MON_DIR/alertmanager/alertmanager.yml.template" > "$TMP/alertmanager.yml"
printf 'GF_SECURITY_ADMIN_PASSWORD=%s\nGF_SERVER_ROOT_URL=%s\n' "$GRAFANA_ADMIN_PASSWORD" "$GRAFANA_URL" > "$TMP/grafana.env"

echo "==> Envoi de la configuration vers $TARGET:$REMOTE_DIR"
ssh "$TARGET" "sudo mkdir -p $REMOTE_DIR && sudo chown -R \$USER $REMOTE_DIR && mkdir -p $REMOTE_DIR/alertmanager"
scp -q -r "$MON_DIR/docker-compose.yml" "$MON_DIR/prometheus" "$MON_DIR/blackbox" "$MON_DIR/grafana" "$TARGET:$REMOTE_DIR/"
scp -q "$TMP/alertmanager.yml" "$TARGET:$REMOTE_DIR/alertmanager/alertmanager.yml"
scp -q "$TMP/grafana.env" "$TARGET:$REMOTE_DIR/grafana.env"

echo "==> Démarrage de la supervision"
# Alertmanager tourne sous l'utilisateur nobody (65534) : seul lui lit le fichier contenant le mot de passe SMTP
ssh "$TARGET" "cd $REMOTE_DIR && chmod 600 grafana.env alertmanager/alertmanager.yml \
    && sudo chown 65534:65534 alertmanager/alertmanager.yml \
    && sudo docker compose pull -q && sudo docker compose up -d --force-recreate --wait --wait-timeout 180 \
    && sudo docker compose ps --format 'table {{.Service}}\t{{.Image}}\t{{.Status}}'"

echo "==> Supervision déployée : $GRAFANA_URL"
