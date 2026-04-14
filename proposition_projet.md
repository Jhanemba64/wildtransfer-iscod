# Proposition de projet — WildTransfer

## 1. C'est quoi ?

**WildTransfer** est une application web de partage de fichiers simple d'usage, sécurisé avec un design épuré, reprenant les principe de Wetransfer. Ce projet s'inscrit dans le cadre de la formation Devops à Iscod.

---

## 2. En quoi consiste le projet ?

Une application permettant de **télécharger, partager et gérer des fichiers** de manière sécurisée :

- **Partage par contact** (permanent) ou **par lien temporaire** (30 minutes)
- **3 rôles** : visiteur, utilisateur connecté, administrateur
- **Modération** : signalements, dashboard admin

---

## 3. Stack technique envisagée

| Couche | Technologies |
|--------|-------------|
| **Frontend** | React, TypeScript, Vite, Tailwind CSS, Apollo Client |
| **Backend** | Node.js, Express, Apollo Server (GraphQL), Type-GraphQL, TypeORM |
| **Base de données** | PostgreSQL |
| **Infrastructure** | Docker Compose, Nginx, GitHub Actions (CI/CD) |

---

## 4. Planning


### Phase 1 — Conception
- Spécifications fonctionnelles et user stories
- Modèle de données (MCD/MLD)
- Maquettes UI/UX (Figma)
- Choix de la stack technique

### Phase 2 — Socle technique
- Initialisation des projets (frontend, backend, storage-api)
- Mise en place Docker, base de données, API GraphQL
- Communication entre les 3 services validée

### Phase 3 — Fonctionnalités core
- Authentification (inscription, login, JWT)
- Upload, gestion et partage de fichiers
- Système de contacts

### Phase 4 — Fonctionnalités avancées
- Dashboard administrateur et modérations
- (FR/EN)

### Phase 5 — Tests et qualité
- Tests unitaires
- Tests E2E
- CI/CD (GitHub Actions)
- Audit sécurité

### Phase 6 — Déploiement
- Mise en production (Docker)
- Documentation technique
- Préparation soutenance
