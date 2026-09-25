#!/usr/bin/env bash
# Prépare et sécurise un serveur Ubuntu (22.04 / 24.04) pour WildTransfer. Idempotent : peut être relancé.
# Lancé automatiquement par cloud-init sur un nouveau serveur, ou à la main (en root) :
#   DOMAIN=wildtransfer.cloud ACME_EMAIL=moi@exemple.com ./provision.sh
# Options : STAGING_DOMAIN (environnement de test sur le même serveur), ADMIN_IP (jamais banni),
#           BACKUP_S3_URL (copie des sauvegardes hors serveur).
set -euo pipefail

: "${DOMAIN:?DOMAIN requis}"
STAGING_DOMAIN=${STAGING_DOMAIN:-}
ACME_EMAIL=${ACME_EMAIL:-}
ADMIN_IP=${ADMIN_IP:-}
BACKUP_S3_URL=${BACKUP_S3_URL:-}
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONF_DIR="$(cd "$SCRIPT_DIR/../config" && pwd)"
export DEBIAN_FRONTEND=noninteractive

echo "==> Paquets système"
apt-get update -q
apt-get install -y -q ca-certificates curl nginx certbot python3-certbot-nginx \
    ufw fail2ban unattended-upgrades gettext-base

echo "==> Docker"
if ! command -v docker >/dev/null; then
    curl -fsSL https://get.docker.com | sh
fi
systemctl enable --now docker

echo "==> Mémoire d'échange (swap 2 Go)"
if ! swapon --show | grep -q /swapfile; then
    fallocate -l 2G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    grep -q '^/swapfile' /etc/fstab || echo '/swapfile none swap sw 0 0' >> /etc/fstab
fi

echo "==> Pare-feu UFW : SSH, HTTP, HTTPS uniquement"
ufw allow OpenSSH
ufw allow 80/tcp
ufw allow 443/tcp
ufw default deny incoming
ufw default allow outgoing
ufw --force enable

echo "==> SSH : authentification par clé uniquement"
cat > /etc/ssh/sshd_config.d/10-wildtransfer.conf <<'EOF'
PasswordAuthentication no
KbdInteractiveAuthentication no
PermitRootLogin prohibit-password
EOF
systemctl reload ssh

echo "==> fail2ban : bannissement automatique (SSH, flood, mots de passe)"
sed "s/@ADMIN_IP@/${ADMIN_IP}/" "$CONF_DIR/fail2ban/jail.local" > /etc/fail2ban/jail.local
systemctl enable fail2ban
systemctl restart fail2ban

echo "==> nginx : reverse proxy durci"
install -m 644 "$CONF_DIR/nginx/security.conf" /etc/nginx/conf.d/security.conf
sed -i 's/ssl_protocols .*/ssl_protocols TLSv1.2 TLSv1.3;/' /etc/nginx/nginx.conf
rm -f /etc/nginx/sites-enabled/default

# Un vhost par environnement : production (port 7007) et, si demandé, staging (port 7008)
site() {
    local name=$1 domain=$2 port=$3
    # '$DOMAIN $APP_PORT' est la liste des variables à substituer, pas une expansion
    # shellcheck disable=SC2016
    DOMAIN="$domain" APP_PORT="$port" envsubst '$DOMAIN $APP_PORT' \
        < "$CONF_DIR/nginx/wildtransfer.conf.template" > "/etc/nginx/sites-available/$name"
    ln -sf "../sites-available/$name" "/etc/nginx/sites-enabled/$name"
}
DOMAINS=("$DOMAIN")
site wildtransfer "$DOMAIN" 7007
if [ -n "$STAGING_DOMAIN" ]; then
    site wildtransfer-staging "$STAGING_DOMAIN" 7008
    DOMAINS+=("$STAGING_DOMAIN")
fi
nginx -t
systemctl reload nginx

echo "==> HTTPS Let's Encrypt"
if [ -n "$ACME_EMAIL" ]; then
    for d in "${DOMAINS[@]}"; do
        certbot --nginx -d "$d" -m "$ACME_EMAIL" --agree-tos --non-interactive --redirect \
            || echo "Certificat non obtenu pour $d (DNS pas encore propagé ?). Relancer : certbot --nginx -d $d"
    done
fi

echo "==> Sauvegardes quotidiennes (base + fichiers, 03h30)"
install -m 700 "$SCRIPT_DIR/backup.sh" /usr/local/bin/wildtransfer-backup
cat > /etc/cron.d/wildtransfer-backup <<EOF
BACKUP_S3_URL=$BACKUP_S3_URL
30 3 * * * root /usr/local/bin/wildtransfer-backup >> /var/log/wildtransfer-backup.log 2>&1
EOF

echo "==> Serveur prêt. Déployer l'application : ./infra/scripts/deploy.sh <utilisateur>@<serveur>"
