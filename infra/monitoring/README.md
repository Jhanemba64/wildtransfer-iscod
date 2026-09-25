# Supervision WildTransfer

| Composant | Rôle |
|---|---|
| **Prometheus** | Collecte les métriques toutes les 30 s et évalue les règles d'alerte (`prometheus/`) |
| **blackbox-exporter** | Sonde les services comme un utilisateur : pages HTTPS et requête GraphQL réelle (`blackbox/`) |
| **node-exporter** | Ressources du serveur : processeur, mémoire, disque, réseau |
| **Alertmanager** | Envoie un e-mail à chaque alerte, puis à sa résolution (SMTP Resend) |
| **Grafana** | Tableau de bord « WildTransfer — Supervision », provisionné depuis `grafana/` |

Accès : https://monitoring.52-47-201-60.sslip.io (identifiant `admin`). Tout le reste écoute sur `127.0.0.1`.

## Statistiques de service (SLI) et objectifs (SLO)

| Indicateur (SLI) | Mesure | Objectif (SLO) |
|---|---|---|
| **Disponibilité** | Part des sondes réussies (`probe_success`), site et API | **≥ 99,5 % sur 30 jours** (≤ 3 h 36 d'indisponibilité par mois) |
| **Temps de réponse** | 95ᵉ centile de la durée des sondes (`probe_duration_seconds`) | **p95 < 1 s** sur 24 h |
| **Validité HTTPS** | Jours avant expiration du certificat | **> 14 jours** en permanence |
| **Santé du serveur** | Processeur, mémoire, disque | **< 90 %** processeur et mémoire, **< 85 %** disque |

Services sondés : site et API de la production AWS, site et API du staging, site de la production OVHcloud.

## Alertes (e-mail)

| Alerte | Condition |
|---|---|
| ServiceIndisponible | Une sonde échoue depuis 1 minute |
| ReponseLente | Réponse de plus de 2 s depuis 5 minutes |
| ObjectifDisponibiliteMenace | Disponibilité production < 99,5 % sur 24 h |
| CertificatExpireBientot | Certificat HTTPS valide moins de 14 jours |
| DisqueBientotPlein / MemoireSaturee / ProcesseurSature | Seuils ci-dessus dépassés pendant 10 minutes |

## Déploiement

```bash
cp infra/monitoring/monitoring.env.example infra/monitoring/monitoring.env   # renseigner les secrets
./infra/scripts/deploy-monitoring.sh ubuntu@<serveur>
```
