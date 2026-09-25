# WildTransfer — DevOps project (ISCOD)

WildTransfer is a secure file-sharing web application (React, GraphQL, Node.js, PostgreSQL).
This repository shows how it is **built, tested, deployed, secured and monitored** end to end,
as part of the ISCOD DevOps training.

**Live:** production https://52-47-201-60.sslip.io · staging https://staging.52-47-201-60.sslip.io

## Architecture

```
GitHub ──► GitHub Actions ──► Docker Hub ──► AWS EC2 (Paris)
 push       tests, build,       versioned      ├── production  (5 containers)
            deploy              images         ├── staging     (5 containers)
                                               └── monitoring  (Prometheus, Grafana, Alertmanager)
```

## What is automated

| Area | How |
|---|---|
| **Infrastructure as code** | Terraform creates the EC2 instance, security group, Elastic IP and S3 buckets; remote state in S3 with locking |
| **Server provisioning** | cloud-init runs `provision.sh`: Docker, UFW firewall, fail2ban, key-only SSH, hardened nginx, Let's Encrypt HTTPS |
| **Continuous deployment** | Every push: unit tests → Docker images tagged with the commit → automatic staging deployment → smoke test |
| **Production release** | One-click GitHub Actions workflow promotes the version validated in staging, with automatic rollback |
| **Testing** | Jest and Vitest unit tests; Playwright end-to-end tests on Chromium, Firefox and WebKit |
| **Data** | Persistent Docker volumes, nightly database and file backups, off-site copy to a write-only S3 bucket, tested restore |
| **Monitoring** | Prometheus + blackbox probes + Grafana dashboard; SLO of 99.5 % availability over 30 days; email alerts via Alertmanager |

## Security highlights

- Two firewall layers (AWS security group + UFW); only ports 22, 80 and 443 are open
- fail2ban bans brute-force and flooding IPs; nginx rate limiting (10 req/s per IP)
- TLS 1.2/1.3 only, HSTS, hidden server versions, encrypted disk, IMDSv2 enforced
- No secrets in the repository; deployment uses a dedicated SSH key stored in GitHub secrets
- The backup bucket accepts uploads only, only from the server IP: a compromised server cannot read or delete backups

## Repository layout

| Path | Content |
|---|---|
| `frontend/`, `backend/`, `storage-api/` | Application code |
| `infra/terraform/` | AWS infrastructure (Terraform) |
| `infra/scripts/` | Provisioning, deployment, backup and smoke-test scripts |
| `infra/app/` | Production / staging Docker Compose stack |
| `infra/monitoring/` | Monitoring stack and SLI/SLO definitions |
| `.github/workflows/` | CI, continuous deployment (`cd.yml`) and release (`release.yml`) pipelines |

## Run locally

```bash
docker compose up --build   # http://localhost:7007
```

Author: Pierrick Onchalo — ISCOD, DevOps training (2026).
