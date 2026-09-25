#!/usr/bin/env bash
# Test de fumée après déploiement : le site et l'API GraphQL doivent répondre 200.
# Usage : ./infra/scripts/smoke-test.sh https://wildtransfer.fr
set -euo pipefail

URL=${1:?usage : smoke-test.sh https://<domaine>}

for i in $(seq 1 10); do
    site=$(curl -s -o /dev/null -w '%{http_code}' "$URL/" || true)
    api=$(curl -s -o /dev/null -w '%{http_code}' -H 'content-type: application/json' \
        --data '{"query":"{ __typename }"}' "$URL/api" || true)
    echo "Essai $i : site $site, API $api"
    if [ "$site" = 200 ] && [ "$api" = 200 ]; then
        echo "OK : $URL répond correctement"
        exit 0
    fi
    sleep 6
done

echo "ÉCHEC : $URL ne répond pas correctement"
exit 1
