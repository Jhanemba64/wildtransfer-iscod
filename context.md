# WildTransfer - Contexte du projet

## Présentation

Application web de partage de fichiers sécurisé, réalisée comme POC/MVP pour le projet de fin d'études (Wild Code School, Concepteur Développeur d'Applications 2024-2025).

**Principe :** Permettre aux utilisateurs de télécharger, partager et gérer leurs fichiers de manière sécurisée avec des options de partage temporaire (lien 30 min) ou permanent (contacts).

**3 rôles :** Visiteur, Utilisateur, Administrateur.

---

## Architecture

Architecture 3-tiers en microservices, orchestrée via Docker Compose avec Nginx en reverse proxy.

| Service | Stack | Port dev | Port Docker |
|---------|-------|----------|-------------|
| Frontend | React 19, TypeScript, Vite, Tailwind CSS 4, Apollo Client, shadcn/ui | 5173 | 7007 (nginx) |
| Backend | Node.js, Express, Apollo Server 4, Type-GraphQL, TypeORM | 4000 | 7007/api |
| Storage-API | Express, Multer (service séparé pour la gestion des fichiers) | 3000 | 7007/storage |
| Base de données | PostgreSQL | interne | interne |
| Reverse Proxy | Nginx | - | 7007 |
| DB UI | Adminer | 8080 | 7007/adminer |

---

## Entités / Schéma de base de données (TypeORM)

### User
- id (PK), email (unique, VARCHAR 150), password (hash Argon2, VARCHAR 150)
- profilePicture (nullable, VARCHAR 255), lastLoggedAt (timestamp)
- role (enum: USER | ADMIN, default USER)
- stripeCustomerId (nullable, VARCHAR 255), createdAt (timestamp)
- Relations : 1:M Resource, M:M Resource (partage), 1:1 Subscription, 1:M Report

### TempUser (buffer d'inscription)
- id (PK), email, password, randomCode (vérification email)

### Resource (fichiers)
- id (PK), user (FK → User, CASCADE)
- name (VARCHAR 150, unique), path (VARCHAR 100), url (VARCHAR 255, unique)
- visibility (enum: PRIVATE | PUBLIC, default PRIVATE)
- description (VARCHAR 320, 30-320 chars), size (BIGINT)
- usersWithAccess (M:M → User), reports (1:M → Report)
- expireAt (nullable DATE), createdAt (timestamp)

### Subscription
- id (PK), paidAt, endAt (timestamps)
- stripeSubscriptionId, stripePriceId (VARCHAR 255, nullable)
- status (enum: ACTIVE | CANCELLED | PAST_DUE | UNPAID, default ACTIVE)
- user (1:1 → User)

### Contact
- id (PK), sourceUser (FK → User), targetUser (FK → User)
- status (enum: PENDING | ACCEPTED | REFUSED, default PENDING)
- createdAt (timestamp)

### Report
- id (PK), user (FK → User), resource (FK → Resource, CASCADE)
- content (TEXT, nullable)
- reason (enum: CORRUPTED | DISPLAY | INAPPROPRIATE | HARASSMENT | SPAM | OTHER | NONE)
- createdAt (timestamp)

### SystemLog
- id (PK), type (enum: SUCCESS | ERROR | WARNING | INFO, default INFO)
- message (VARCHAR 255), details (TEXT, nullable)
- userId (VARCHAR 100, nullable), createdAt (timestamp)

---

## Stack technique détaillée

### Frontend
- **Framework :** React 19 + React Router DOM 7
- **Build :** Vite 6.1
- **Styling :** Tailwind CSS 4, Radix UI (13 primitives), shadcn/ui, Framer Motion
- **Data :** Apollo Client 3 (GraphQL), SWR
- **Forms :** React Hook Form + Zod (validation)
- **Paiement :** Stripe React
- **Upload :** react-dropzone (100MB max)
- **i18n :** i18next + react-i18next + détection langue navigateur
- **Notifications :** react-toastify
- **Icônes :** Lucide React
- **GraphQL Codegen :** Types TypeScript auto-générés depuis le schéma

### Backend
- **Serveur :** Apollo Server 4 + Express
- **GraphQL :** Type-GraphQL 2 (RC) avec décorateurs TypeScript
- **ORM :** TypeORM 0.3 + PostgreSQL (pg)
- **Auth :** JWT (cookies HTTP-only), Argon2 (hash passwords)
- **Sécurité :** express-rate-limit
- **Paiement :** Stripe (webhooks)
- **Email :** Resend + react-email (templates)
- **Cron :** node-cron (nettoyage fichiers expirés, quotidien 2h)
- **Validation :** class-validator
- **Seeds :** Faker.js (données de test)

### Storage-API
- **Serveur :** Express
- **Upload :** Multer (100MB max)
- **Auth :** JWT (vérification token)
- **Sécurité :** express-rate-limit
- **Stockage :** Fichiers dans /uploads (volume Docker persistant)
- **Endpoints publics :** GET /temp/:linkId, POST /upload-temp
- **Endpoints auth :** GET/POST/PUT/DELETE /files/:fileId

---

## Routes frontend

| Route | Page | Accès |
|-------|------|-------|
| `/` | Home | Public |
| `/login` | Connexion | Public |
| `/sign` | Inscription | Public |
| `/files` | Gestion fichiers | Auth |
| `/upload` | Upload fichier | Public |
| `/contacts` | Gestion contacts | Auth |
| `/subscription` | Plans d'abonnement | Public |
| `/subscription/payment` | Paiement Stripe | Auth |
| `/subscription/success` | Confirmation paiement | Auth |
| `/profile` | Profil utilisateur | Auth |
| `/admin` | Dashboard admin | Admin |
| `/admin/users` | Gestion utilisateurs | Admin |
| `/admin/files` | Gestion fichiers (admin) | Admin |
| `/admin/reports` | Gestion signalements | Admin |
| `/forgot-password` | Mot de passe oublié | Public |
| `/reset-password` | Réinitialisation MDP | Public |
| `/about` | À propos | Public |
| `/how-it-works` | Comment ça marche | Public |

---

## GraphQL Resolvers

- **UserResolver** : register, login, logout, getMe, getUsers, updateProfile, deleteUser
- **ResourceResolver** : uploadFile, getResources, getResource, deleteResource, updateResource, shareResource, getSharedResources
- **ContactResolver** : addContact, getContacts, acceptContact, refuseContact, deleteContact
- **SubscriptionResolver** : getSubscription, getPlans
- **PaymentResolver** : createCheckoutSession, handleWebhook, cancelSubscription
- **ReportResolver** : createReport, getReports, deleteReport
- **SystemLogResolver** : getLogs, createLog

---

## Fonctionnalités clés

1. **Upload/Partage de fichiers** : upload via Storage-API, partage avec contacts ou lien temporaire 30min
2. **Authentification** : inscription avec vérification email (TempUser → User), login JWT, rôles USER/ADMIN
3. **Abonnement premium** : Stripe Checkout, stockage illimité (vs 90 jours gratuit), espace agrandi
4. **Système de contacts** : demandes (PENDING → ACCEPTED/REFUSED), partage fichiers avec contacts
5. **Modération** : signalements avec raisons, dashboard admin pour review
6. **Administration** : gestion utilisateurs, fichiers, signalements, logs système
7. **Nettoyage automatique** : suppression fichiers expirés (cron quotidien 2h)
8. **Internationalisation** : support multilingue via i18next

---

## Comptes de test (Docker)

- **Admin :** admin@example.com / Admin@123456
- **Premium :** premium@example.com / Premium@123456

---

## Commandes utiles

```bash
# Docker (recommandé)
docker-compose up --build          # Lancement complet sur port 7007

# Dev local (3 terminaux)
cd frontend && npm run dev         # Port 5173
cd backend && npm run dev          # Port 4000
cd storage-api && npm run dev      # Port 3000

# Tests
cd frontend && npm run test:run    # Tests unitaires frontend (Vitest)
cd backend && npm test             # Tests unitaires backend (Jest)
cd playwright && npm test          # Tests E2E (Playwright, 3 navigateurs)
```

---

## Structure des dossiers principaux

```
WildTransfer/
├── frontend/src/
│   ├── components/       # Composants réutilisables (File/, FileUploader/, Contact/, ui/, etc.)
│   ├── pages/            # Pages (Home, Files, Upload, Admin, Profile, etc.)
│   ├── graphql/          # Queries/Mutations GraphQL par domaine
│   ├── generated/        # Types TypeScript auto-générés (codegen)
│   ├── context/          # AuthContext, StripeContext
│   ├── hooks/            # useAuth, useCheckout, useMediaQuery, useTheme, etc.
│   ├── utils/            # Fonctions utilitaires
│   ├── App.tsx           # Configuration des routes
│   └── main.tsx          # Point d'entrée, config Apollo Client
├── backend/src/
│   ├── entities/         # Entités TypeORM (User, Resource, Subscription, etc.)
│   ├── resolvers/        # Resolvers GraphQL (Type-GraphQL)
│   ├── services/         # Services métier (Stripe, cleanup)
│   ├── middleware/       # Auth, rate limiting
│   ├── seeds/            # Scripts de seed BDD
│   ├── db.ts             # Config DataSource TypeORM
│   └── index.ts          # Setup Apollo Server
├── storage-api/src/
│   ├── controllers/      # Contrôleurs fichiers (auth + temp)
│   ├── routes/           # Routes Express
│   ├── middlewares/      # Auth, rate limiting
│   └── services/         # Cleanup service
├── playwright/           # Tests E2E
├── docker-compose.yml    # Config Docker dev
├── docker-compose.prod.yml # Config Docker prod
└── nginx.conf            # Config reverse proxy
```
