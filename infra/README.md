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
sous un tag dédié (ex. `iscod`). Le tag `latest` est réservé à la production OVH et refusé.
