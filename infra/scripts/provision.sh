#!/usr/bin/env bash
# Prépare et sécurise un serveur Ubuntu (22.04 / 24.04) pour WildTransfer. Idempotent : peut être relancé.
# Lancé automatiquement par cloud-init sur un nouveau serveur, ou à la main (en root) :
#   DOMAIN=wildtransfer.cloud ACME_EMAIL=moi@exemple.com [ADMIN_IP=1.2.3.4] ./provision.sh
set -euo pipefail

: "${DOMAIN:?DOMAIN requis}"
ACME_EMAIL=${ACME_EMAIL:-}
ADMIN_IP=${ADMIN_IP:-}
CONF_DIR="$(cd "$(dirname "$0")/../config" && pwd)"
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
DOMAIN="$DOMAIN" envsubst '$DOMAIN' < "$CONF_DIR/nginx/wildtransfer.conf.template" \
    > /etc/nginx/sites-available/wildtransfer
ln -sf ../sites-available/wildtransfer /etc/nginx/sites-enabled/wildtransfer
rm -f /etc/nginx/sites-enabled/default
nginx -t
systemctl reload nginx

echo "==> HTTPS Let's Encrypt"
if [ -n "$ACME_EMAIL" ]; then
    certbot --nginx -d "$DOMAIN" -m "$ACME_EMAIL" --agree-tos --non-interactive --redirect \
        || echo "Certificat non obtenu (DNS pas encore propagé ?). Relancer : certbot --nginx -d $DOMAIN"
fi

echo "==> Serveur prêt. Déployer l'application : ./infra/scripts/deploy.sh <utilisateur>@<serveur>"
