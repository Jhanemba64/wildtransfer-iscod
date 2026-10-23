# WildTransfer

Application web de partage de fichiers : déposer des documents, images ou vidéos, les retrouver dans un
espace personnel et les partager par lien. Le projet couvre aussi toute la chaîne DevOps : tests automatiques,
déploiement continu sur Kubernetes, infrastructure AWS en code, sauvegardes et supervision.

| Environnement | Adresse |
|---|---|
| Production | https://wildtransfer.fr |
| Préproduction (staging) | https://staging.wildtransfer.fr |
| Supervision (Grafana) | https://monitoring.wildtransfer.fr |

*English version: [README.en.md](README.en.md)*

## Fonctionnalités

- **Compte** : inscription confirmée par e-mail, connexion, mot de passe oublié, profil.
- **Fichiers** : dépôt avec contrôle du type de fichier, espace personnel permanent, jauge de stockage.
- **Partage** : lien public temporaire, valable 30 minutes, sans compte nécessaire pour le destinataire.
- **Contacts** et **signalement** d'un fichier inapproprié.
- **Abonnement premium** payé par Stripe.
- **Administration** : gestion des utilisateurs, des fichiers et des signalements.
- Interface en **français et en anglais**.

## Architecture

```
Navigateur ──► passerelle nginx ──┬── /         ► frontend     (React, Vite)
                                  ├── /api      ► backend      (API GraphQL) ──► PostgreSQL
                                  └── /storage  ► storage-api  (fichiers)    ──► disque (uploads)
```

| Service | Technologies | Rôle |
|---|---|---|
| `frontend` | React 19, TypeScript, Vite, Tailwind CSS, shadcn/ui, Apollo Client, i18next | Interface utilisateur |
| `backend` | Node.js, TypeScript, Apollo Server, TypeGraphQL, TypeORM, Argon2, JWT, Stripe, Resend | Comptes, métadonnées des fichiers, abonnements, e-mails |
| `storage-api` | Node.js, Express, Multer | Envoi, stockage et téléchargement des fichiers ; liens temporaires |
| `db` | PostgreSQL | Données de l'application |
| passerelle | nginx | Point d'entrée unique, routage vers les trois services |

Les fichiers passent par une API REST séparée (`storage-api`) car GraphQL n'est pas adapté aux gros fichiers
binaires ; le backend ne stocke que leurs métadonnées.

## Organisation du dépôt

```
frontend/         interface React
backend/          API GraphQL
storage-api/      API de fichiers
playwright/       tests de bout en bout
infra/            infrastructure : Terraform (AWS), manifestes Kubernetes, scripts, supervision
.github/workflows intégration et déploiement continus
docker-compose.yml + nginx.conf   environnement de développement local
```

## Lancer le projet en local

**Prérequis** : Docker avec Docker Compose v2, et Node.js LTS pour lancer les tests.

Le projet se lance **avec Docker uniquement** : les services se trouvent entre eux par leur nom (`db`,
`backend`), ce que seul le réseau Docker fournit (voir `backend/src/db.ts` et `frontend/codegen.ts`).

### 1. Créer les fichiers d'environnement

```bash
cp backend/.env.example backend/.env
cp frontend/.env.example frontend/.env
cp storage-api/.env.exemple storage-api/.env
```

Puis renseigner les valeurs :

| Fichier | Variable | Valeur |
|---|---|---|
| `backend/.env` | `NODE_ENV` | `development` |
| | `JWT_SECRET_KEY` | Une longue chaîne aléatoire, **identique** dans `storage-api/.env` |
| | `RESEND_API_KEY`, `RESEND_EMAIL_DOMAIN` | Clé et domaine [Resend](https://resend.com) pour les e-mails de confirmation |
| | `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` | Clés Stripe de test (abonnement premium) |
| | `APP_URL` (facultatif) | Adresse utilisée dans les liens des e-mails |
| `storage-api/.env` | `JWT_SECRET_KEY` | La même valeur que dans le backend |
| | `PORT` | `3000` |
| `frontend/.env` | `VITE_ENVIRONMENT` | `DEV` (obligatoire : sans lui, l'interface refuse de démarrer) |
| | `VITE_STRIPE_PUBLISHABLE_KEY` | Clé publique Stripe de test |

Ces fichiers ne sont jamais versionnés.

### 2. Démarrer

```bash
docker compose up --build
```

Au premier démarrage, le backend crée les tables et des comptes de test. L'application est prête quand
http://localhost:7007 répond.

| Accès | Adresse |
|---|---|
| Application | http://localhost:7007 |
| API GraphQL (Apollo Sandbox) | http://localhost:7007/api |
| Adminer (base de données) | http://localhost:7007/adminer · système PostgreSQL, serveur `db`, utilisateur `postgres`, mot de passe `example`, base `postgres` |
| API de fichiers (accès direct) | http://localhost:3000 |

**Comptes de test** : `admin@example.com` / `Admin@123456` (administrateur) et `premium@example.com` /
`Premium@123456` (abonné premium).

Le code des trois services est monté dans les conteneurs : l'interface se recharge toute seule à chaque
modification ; pour le backend et l'API de fichiers, un redémarrage du service suffit, sans reconstruire l'image.

```bash
docker compose logs -f backend   # suivre les journaux d'un service
docker compose restart backend   # prendre en compte une modification du backend
docker compose down              # arrêter
docker compose down -v           # arrêter et repartir d'une base vide
```

## Tests

### Tests unitaires

```bash
cd frontend && npm ci && npm run test:run   # Vitest
cd backend && npm ci && npm test            # Jest
```

| Service | Fichiers de test |
|---|---|
| frontend | `src/utils/fileUtils.test.ts` (type et taille de fichier), `src/utils/globalUtils.test.ts` (classes CSS, décodage JWT), `src/components/header/Header.test.tsx` (en-tête) |
| backend | `src/utils/storageUtils.test.ts` (calcul du stockage) |

Analyse du code : `npm run lint` dans `frontend/` et `backend/`.

### Tests de bout en bout (Playwright)

L'application doit tourner (`docker compose up`) : les tests visent http://localhost:7007, sur Chromium,
Firefox et WebKit.

```bash
cd playwright
npm ci
npx playwright install      # première fois : télécharge les navigateurs
npm test                    # les 3 navigateurs (ou test:chromium, test:firefox, test:webkit)
npm run test:ui             # mode interactif
npx playwright show-report  # rapport HTML
```

Scénarios couverts : `01-signup` (inscription, validation de l'e-mail et du mot de passe) et `02-login`
(connexion, redirection).

## Infrastructure et DevOps

### Vue d'ensemble

```
GitHub ──► GitHub Actions ──► Docker Hub ──► serveur AWS EC2, Paris (créé par Terraform)
 push      tests, images,     images         │
           déploiement        versionnées    ├── Kubernetes (k3s)
                                             │     ├── namespace wildtransfer          production
                                             │     └── namespace wildtransfer-staging  préproduction
                                             ├── nginx de l'hôte : HTTPS, limite de débit, fail2ban
                                             ├── supervision : Prometheus, Grafana, Alertmanager
                                             └── sauvegarde nocturne ──► bucket S3 hors du serveur
```

### Ce qui est automatisé

| Domaine | Comment | Où |
|---|---|---|
| **Infrastructure en code** | **Terraform** crée l'instance EC2 (disque chiffré, IMDSv2), le groupe de sécurité, l'IP fixe et les buckets S3 ; son état est stocké dans S3, chiffré et verrouillé | `infra/terraform/` |
| **Préparation du serveur** | Au premier démarrage, **cloud-init** lance `provision.sh` : installation de k3s, pare-feu UFW, SSH par clé uniquement, fail2ban, nginx durci, certificats Let's Encrypt, sauvegarde nocturne. Le serveur est en ligne en HTTPS en quelques minutes, sans intervention | `infra/cloud-init/`, `infra/scripts/provision.sh` |
| **Orchestration** | **Kubernetes (k3s)** : mêmes manifestes pour la production et le staging (Kustomize), sondes de santé, limites mémoire, mises à jour progressives sans coupure, base de données joignable uniquement par l'API (NetworkPolicy), secrets chiffrés | `infra/k8s/` |
| **Déploiement** | `deploy.sh` génère les secrets, fixe la version des images, applique les manifestes et remet automatiquement la version précédente si la nouvelle n'est pas saine | `infra/scripts/deploy.sh` |
| **CI/CD** | GitHub Actions : tests, images taguées avec le commit, staging puis production (détail ci-dessous) | `.github/workflows/` |
| **Données** | Volumes persistants ; chaque nuit, dump de la base et archive des fichiers, copiés dans un bucket S3 qui n'accepte que des dépôts depuis le serveur ; restauration testée | `infra/scripts/backup.sh`, `infra/terraform/backups.tf` |
| **Supervision** | Prometheus, sondes externes (blackbox), Grafana et Alertmanager ; objectif de 99,5 % de disponibilité sur 30 jours, alertes par e-mail | `infra/monitoring/` |
| **Validation de l'infrastructure** | En CI : format et validité Terraform, ShellCheck, manifestes Kubernetes validés (kubeconform), configuration nginx, règles Prometheus | `.github/workflows/infra.yml` |

### Commandes principales

```bash
# Créer (ou mettre à jour) l'infrastructure AWS
cd infra/terraform && terraform init && terraform plan && terraform apply

# Déployer une version sur le staging ou la production
APP_ENV=staging IMAGE_TAG=sha-1a2b3c4 ./infra/scripts/deploy.sh ubuntu@<serveur>

# État du cluster
ssh ubuntu@<serveur> sudo k3s kubectl get pods -A
```

Le détail (variables Terraform, secrets, environnements, sauvegardes, restauration) est dans
[`infra/README.md`](infra/README.md) ; la supervision dans [`infra/monitoring/README.md`](infra/monitoring/README.md).

## Intégration et déploiement continus

Une branche correspond à un environnement :

| Branche | Ce qui se passe (GitHub Actions) |
|---|---|
| `dev` | Tests unitaires, analyse du code, tests de bout en bout sur 3 navigateurs, validation de l'infrastructure |
| `preprod` | Tests, construction des 3 images Docker taguées avec le commit (`sha-xxxxxxx`), déploiement sur le staging, test de fumée |
| `main` | Mise en production de l'image déjà validée en staging, test de fumée, retour arrière automatique en cas d'échec |

Livrer une version : fusionner `dev` dans `preprod`, vérifier le staging, puis fusionner `preprod` dans `main`.
Une version précise peut aussi être mise en production (ou remise en place) depuis l'onglet *Actions*,
workflow « Mise en production ».

## Sécurité

- Mots de passe hachés avec **Argon2**, authentification par **JWT**, validation des entrées (class-validator, Zod).
- API de fichiers : liste blanche des types de fichiers, limites de débit (dépôts, liens temporaires,
  suppressions, requêtes), noms de fichiers aléatoires.
- Infrastructure : deux pare-feu (groupe de sécurité AWS et UFW, seuls 22, 80 et 443 ouverts), SSH par clé,
  fail2ban, TLS 1.2/1.3 avec HSTS, disque chiffré, mises à jour de sécurité automatiques, API Kubernetes non
  exposée, secrets hors du dépôt et chiffrés dans Kubernetes (détails dans [`infra/README.md`](infra/README.md)).
