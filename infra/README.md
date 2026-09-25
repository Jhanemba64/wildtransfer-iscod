# Infrastructure WildTransfer

Tout ce qu'il faut pour recréer un serveur de production complet de zéro, dans le cloud AWS.

| Dossier | Rôle |
|---|---|
| `terraform/` | Crée le serveur sur AWS (instance EC2 chiffrée, clé SSH, groupe de sécurité, IP fixe) |
| `cloud-init/` | Premier démarrage : dépose les scripts et lance le provisioning |
| `scripts/provision.sh` | Installe Docker, nginx, certbot et sécurise le serveur (UFW, fail2ban, SSH par clé, TLS) |
| `config/` | Configurations nginx et fail2ban appliquées par `provision.sh` |
| `app/` | Stack de production (Docker Compose, images Docker Hub, volumes persistants) |
| `scripts/deploy.sh` | Déploie ou met à jour l'application sur le serveur |

## Mise en production en 4 commandes

```bash
# 1. Identifiants AWS (profil de l'AWS CLI)
export AWS_PROFILE=meditrack

# 2. Créer le serveur (il se provisionne tout seul au démarrage, ~5 min)
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # renseigner e-mail, IP admin (domaine optionnel)
terraform init && terraform apply

# 3. Sans domaine, l'application répond sur https://<ip>.sslip.io (sortie "url")

# 4. Déployer l'application (secrets dans infra/app/*.env, non versionnés)
cd ../..
IMAGE_TAG=iscod ./infra/scripts/deploy.sh ubuntu@<ipv4>
```

## État Terraform partagé (S3)

L'état (ce que Terraform a réellement créé) n'est ni sur un poste ni dans git : il est stocké dans le bucket
S3 `wildtransfer-tfstate-971598352115` (Paris), **versionné, chiffré et privé**, avec un verrou qui empêche
deux `terraform apply` simultanés (`use_lockfile`). Le bucket se crée une seule fois, avant le premier `init` :

```bash
B=wildtransfer-tfstate-971598352115
aws s3api create-bucket --bucket $B --region eu-west-3 --create-bucket-configuration LocationConstraint=eu-west-3
aws s3api put-bucket-versioning --bucket $B --versioning-configuration Status=Enabled
aws s3api put-public-access-block --bucket $B --public-access-block-configuration \
    BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
```

Le serveur existant peut aussi être (re)provisionné sans Terraform :

```bash
scp -r infra ubuntu@<serveur>:/tmp/infra
ssh ubuntu@<serveur> "sudo DOMAIN=wildtransfer.cloud ACME_EMAIL=moi@exemple.com /tmp/infra/scripts/provision.sh"
```

## Sécurité appliquée

- Pare-feu à deux niveaux : groupe de sécurité AWS et UFW (22, 80, 443 uniquement)
- Disque chiffré, IMDSv2 obligatoire (métadonnées de l'instance protégées)
- SSH par clé uniquement, root interdit par mot de passe
- fail2ban : SSH, flood HTTP (limit_req), mots de passe HTTP
- nginx : HTTPS Let's Encrypt, TLS 1.2 et 1.3, HSTS, version masquée, 10 requêtes/s par IP, `/adminer` bloqué
- Conteneurs liés à `127.0.0.1` uniquement, secrets hors du dépôt

## Validation automatique

Le workflow `.github/workflows/infra.yml` vérifie à chaque modification de `infra/` :
format et validité Terraform, ShellCheck sur les scripts, compose et configuration nginx valides.

## Images de l'application

Le workflow manuel `.github/workflows/images.yml` construit les 3 images depuis une branche et les publie
sous un tag dédié (ex. `iscod`). Le tag `latest` (ancienne production OVH) est refusé.

## Environnements

| Environnement | Adresse | Dossier serveur | Port interne | Secrets locaux |
|---|---|---|---|---|
| Production | https://wildtransfer.fr | `/opt/wildtransfer` | 7007 | `app/backend.env`, `app/storage-api.env` |
| Staging (test) | https://staging.wildtransfer.fr | `/opt/wildtransfer-staging` | 7008 | `app/backend.staging.env`, `app/storage-api.staging.env` |

Chaque environnement a sa propre base, ses propres fichiers (volumes Docker) et ses propres secrets.

```bash
APP_ENV=staging IMAGE_TAG=sha-1a2b3c4 ./infra/scripts/deploy.sh ubuntu@<serveur>
```

`deploy.sh` attend que tous les conteneurs soient sains ; sinon, il remet automatiquement la version précédente.

## Sauvegardes

Chaque nuit à 03h30 (`scripts/backup.sh`, installé par `provision.sh`) : dump de chaque base et archive des
fichiers de chaque environnement dans `/var/backups/wildtransfer` (14 jours), copie dans le bucket S3
`wildtransfer-backups-<compte>` (30 jours). Ce bucket n'accepte que des dépôts, et seulement depuis l'IP du
serveur : aucune clé AWS sur le serveur, et un serveur compromis ne peut ni lire ni effacer les sauvegardes.

```bash
# Restaurer la base de production depuis la dernière sauvegarde
F=$(sudo sh -c "ls -t /var/backups/wildtransfer/wildtransfer-db-*.sql.gz | head -1")
sudo gunzip -c "$F" | (cd /opt/wildtransfer && sudo docker compose exec -T db psql -q -U postgres)
```

## Déploiement continu et mise en production (GitHub Actions)

Une branche = un environnement :

| Branche | Rôle | Workflow déclenché |
|---|---|---|
| `dev` | Intégration | CI : tests unitaires, E2E (Chromium, Firefox, WebKit), infrastructure |
| `preprod` | Préproduction | `cd.yml` : tests → images taguées par commit (`sha-xxxxxxx`) → déploiement staging → test de fumée |
| `main` | Production | `release.yml` : version validée en préproduction → déploiement production → test de fumée → retour arrière automatique si échec |

Livrer : fusionner `dev` → `preprod`, vérifier le staging, puis fusionner `preprod` → `main`.
`release.yml` peut aussi être lancé à la main pour déployer une version précise (retour à une version antérieure).

Secrets GitHub : `DEPLOY_SSH_KEY` (clé dédiée au déploiement), `DEPLOY_KNOWN_HOSTS`, `DOCKERHUB_*`.
Variables : `DEPLOY_HOST`, `PROD_URL`, `STAGING_URL`.
