#!/usr/bin/env bash
# Sauvegarde quotidienne de WildTransfer : base de données + fichiers uploadés, pour chaque environnement
# déployé (production, staging). Rétention locale 14 jours. Installé par provision.sh (cron 03h30).
# Si BACKUP_S3_URL est défini, chaque sauvegarde est aussi copiée hors du serveur dans S3
# (bucket en écriture seule, réservé à l'IP du serveur : aucune clé AWS sur le serveur).
set -euo pipefail

DEST=/var/backups/wildtransfer
BACKUP_S3_URL=${BACKUP_S3_URL:-}
D=$(date +%F_%H%M)
umask 077
mkdir -p "$DEST"

for dir in /opt/wildtransfer /opt/wildtransfer-staging; do
    [ -f "$dir/docker-compose.yml" ] || continue
    env=$(basename "$dir")
    (cd "$dir" && docker compose exec -T db pg_dump -U postgres --clean --if-exists postgres) \
        | gzip > "$DEST/$env-db-$D.sql.gz"
    docker run --rm -v "${env}_uploads:/data:ro" alpine tar czf - -C /data . > "$DEST/$env-uploads-$D.tar.gz"
    # Un dump valide commence par l'en-tête pg_dump
    gzip -dc "$DEST/$env-db-$D.sql.gz" | head -c 4096 | grep -q 'PostgreSQL database dump'
done

find "$DEST" -name '*.gz' -mtime +14 -delete

if [ -n "$BACKUP_S3_URL" ]; then
    for f in "$DEST"/*"-$D".*; do
        curl -fsS --retry 3 -X PUT -T "$f" "$BACKUP_S3_URL/$(hostname)/$(basename "$f")"
    done
fi

echo "$(date -Is) sauvegarde OK ($(du -sh "$DEST" | cut -f1) en local)"
