# PRD — MinIO Production Stack (Docker Compose)

## 1. Goal

Deploy MinIO in **production** mode on Docker Compose on a single host, with
data durability via erasure coding, basic observability, parameterized config
through `.env`, and explicit resource reservations/limits.

## 2. Scope

- **In-scope**
  - 1 MinIO service with 4 drives (SNMD, erasure coding EC:2 → tolerates loss
    of up to 2 drives without data loss).
  - Native healthcheck (`/minio/health/live`).
  - Console UI on its own port.
  - Parameterized environment (`.env` overrides `.env.example`).
  - Restart policy, rotated logging, bounded resources (reservation + limit).
  - Optional one-shot `mc` service to bootstrap buckets/policies/users on the
    first start.
- **Out-of-scope (follow-ups)**
  - Multi-node HA (MNMD) → requires 4+ hosts and is out of compose's reach.
  - Reverse proxy with TLS (nginx/traefik/caddy) → recommended next layer.
    MinIO can serve TLS directly if you mount certs, but the canonical prod
    pattern is to terminate TLS at the proxy.
  - Backup / cross-site replication (`mc mirror` / site replication).

## 3. Architecture decisions

| Decision | Choice | Why |
| --- | --- | --- |
| Topology | SNMD, 4 drives | Minimum for EC on a single host. If the host dies, the service dies — but data survives individual disk failures. |
| Drives | 4 host bind mounts (`/srv/minio/data{1..4}`) | Bind > named volume in prod: easier backup, LVM/ZFS snapshots, migration. Should ideally live on separate disks. |
| Network | Dedicated bridge (`minio_net`) with configurable MTU | Isolated from default. MTU defaults to 1500, lower it for VPN/overlay. |
| Ports | API `9000`, Console `9001`, bound to loopback by default | Safe-by-default; opt-in to LAN exposure via `.env`. |
| Healthcheck | `curl` to `/minio/health/live` | Native, no extra deps (curl ships in the image). |
| Logging | `json-file` with rotation (10 MB × 3) | Avoids filling disk. |
| Restart | `unless-stopped` | Doesn't restart if operator stopped it on purpose. |
| Resources | Reservation 1 CPU / 1 GiB · Limit 2 CPU / 2 GiB | Sensible baseline for a small/medium workload. Tunable via `.env`. |
| Credentials | `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD` required in `.env` | Compose ships **no** defaults — fail fast if missing. |
| Bootstrap | `mc-init` service (`restart: "no"`) gated by `depends_on: healthy` | Idempotent initial bucket creation. |

## 4. Host requirements

- Docker ≥ 24, Compose v2.
- Linux kernel with cgroups v2 (so `deploy.resources` applies under plain
  Compose without Swarm).
- NTP-synchronized clock — MinIO is sensitive to skew.
- XFS filesystem recommended for the drives (ext4 also works). For real prod,
  the 4 drives should not share a single filesystem; this stack assumes that
  for a pragmatic single-host deployment.

## 5. Environment variables (summary)

See `.env.example` for the full list. Critical ones:

- `MINIO_ROOT_USER`, `MINIO_ROOT_PASSWORD` — no default, required.
- `MINIO_SERVER_URL` — public API URL (needed when behind a reverse proxy/TLS).
- `MINIO_BROWSER_REDIRECT_URL` — public Console URL.
- `MINIO_REGION` — logical region (default `us-east-1`).
- `MINIO_PROMETHEUS_AUTH_TYPE=public` — token-less scraping.
- `NETWORK_MTU` — bridge MTU (default 1500).

## 6. Operations

- **Up**: `docker compose up -d`
- **Logs**: `docker compose logs -f minio`
- **Status**: `docker compose ps` (must be `healthy`)
- **Backup**: snapshot of `/srv/minio/data{1..4}` while stopped, or
  `mc mirror` to another target.
- **Upgrade**: bump tag, `docker compose pull && docker compose up -d`. MinIO
  supports rolling upgrades; on SNMD there is brief downtime.

## 7. Risks and mitigations

| Risk | Mitigation |
| --- | --- |
| Host loss | Replication to another site (out-of-scope, follow-up). |
| Weak credentials | `.env` out of git, password ≥ 20 chars. |
| Disk full | Prometheus monitoring + alerts, lifecycle policies. |
| Clock skew | NTP on the host. |
| Public exposure without TLS | Reverse proxy with TLS (follow-up). Never expose 9000/9001 to the internet without TLS. |

## 8. Acceptance criteria

1. `docker compose up -d` reaches `healthy` in < 30 s.
2. Console reachable on `http://<host>:9001` with the credentials from `.env`.
3. `mc alias set` + `mc admin info` from another container works.
4. Killing one drive (deleting one `data{N}`) does not cause data loss after
   restart — EC reconstructs.
5. `docker stats` shows the container within the configured CPU/mem limits.
