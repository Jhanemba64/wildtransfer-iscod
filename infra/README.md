# Infrastructure WildTransfer

Tout ce qu'il faut pour recréer le serveur de production de zéro, dans le cloud OVHcloud.

| Dossier | Rôle |
|---|---|
| `terraform/` | Crée le serveur dans le cloud (instance, clé SSH, pare-feu cloud) |
| `cloud-init/` | Premier démarrage : dépose les scripts et lance le provisioning |
| `scripts/provision.sh` | Installe Docker, nginx, certbot et sécurise le serveur (UFW, fail2ban, SSH par clé, TLS) |
| `config/` | Configurations nginx et fail2ban appliquées par `provision.sh` |
| `app/` | Stack de production (Docker Compose, images Docker Hub) |
| `scripts/deploy.sh` | Déploie ou met à jour l'application sur le serveur |

## Mise en production en 4 commandes

```bash
# 1. Identifiants OVH Public Cloud (fichier openrc.sh de l'espace client)
source openrc.sh

# 2. Créer le serveur (il se provisionne tout seul au démarrage, ~5 min)
cd infra/terraform
cp terraform.tfvars.example terraform.tfvars   # renseigner domaine, e-mail, IP admin
terraform init && terraform apply

# 3. Pointer le DNS du domaine vers l'IP affichée (sortie "ipv4")

# 4. Déployer l'application (secrets dans infra/app/*.env, non versionnés)
cd ../..
./infra/scripts/deploy.sh ubuntu@<ipv4>
```

Le serveur existant peut aussi être (re)provisionné sans Terraform :

```bash
scp -r infra ubuntu@<serveur>:/tmp/infra
ssh ubuntu@<serveur> "sudo DOMAIN=wildtransfer.cloud ACME_EMAIL=moi@exemple.com /tmp/infra/scripts/provision.sh"
```

## Sécurité appliquée

- Pare-feu à deux niveaux : groupe de sécurité cloud et UFW (22, 80, 443 uniquement)
- SSH par clé uniquement, root interdit par mot de passe
- fail2ban : SSH, flood HTTP (limit_req), mots de passe HTTP
- nginx : HTTPS Let's Encrypt, TLS 1.2 et 1.3, HSTS, version masquée, 10 requêtes/s par IP, `/adminer` bloqué
- Conteneurs liés à `127.0.0.1` uniquement, secrets hors du dépôt

## Validation automatique

Le workflow `.github/workflows/infra.yml` vérifie à chaque modification de `infra/` :
format et validité Terraform, ShellCheck sur les scripts, compose et configuration nginx valides.
