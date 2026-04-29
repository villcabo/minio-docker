# MinIO — Docker Compose (prod)

**Languages:** **English** · [Español](./README.es.md)

Production-ready MinIO stack on a single host: SNMD with 4 drives (erasure
coding EC:2), healthcheck, rotated logging, and resource limits.

## Clone

```bash
# Default: clones into ./minio-docker
git clone https://github.com/villcabo/minio-docker.git

# Custom name: pass the target directory as a second argument
git clone https://github.com/villcabo/minio-docker.git minio-docker-custom
```

## Prerequisites

- Docker ≥ 24 and Compose v2 (`docker compose version`).
- Linux with cgroups v2 (so `deploy.resources` applies).
- NTP synchronized on the host.
- `sudo` available if `MINIO_DATA_PATH` lives outside your `$HOME`
  (default `/srv/minio`).

## Deploy

```bash
# 1. Configure variables
cp .env.example .env
$EDITOR .env   # set MINIO_ROOT_USER and MINIO_ROOT_PASSWORD (≥ 20 chars)

# 2. Create the 4 data directories with the right owner
./scripts/init.sh

# 3. Create the shared external network (one-time)
#    Change the name here and in MINIO_ROUTER_NETWORK in .env if you want a custom one.
docker network create --driver bridge --opt com.docker.network.driver.mtu=1500 minio_router

# 4. Start
docker compose up -d

# 5. Verify
docker compose ps           # minio must be `healthy`
docker compose logs -f minio
```

### Connecting other stacks (Loki, apps, etc.)

MinIO joins two networks:

- `minio_net` — internal, only for this compose project.
- `minio_router` — **external**, shared across stacks. Other compose projects
  attach to it and reach MinIO via its service DNS name `minio:9000`, with no
  port exposure on the host.

Example snippet for a consumer stack (e.g. Loki):

```yaml
services:
  loki:
    # ...
    networks:
      - default
      - minio_router
    environment:
      S3_ENDPOINT: http://minio:9000

networks:
  minio_router:
    external: true
```

Console: `http://<host>:9001`
S3 API:  `http://<host>:9000`

> Default port bindings are `127.0.0.1` (loopback only). To expose on LAN,
> set `MINIO_API_PORT=0.0.0.0:9000` and `MINIO_CONSOLE_PORT=0.0.0.0:9001`
> in your `.env`.

## Operations

| Action | Command |
| --- | --- |
| Status | `docker compose ps` |
| Live logs | `docker compose logs -f minio` |
| Restart | `docker compose restart minio` |
| Upgrade | `docker compose pull && docker compose up -d` |
| Stop | `docker compose down` (keeps data) |
| Wipe everything (incl. data!) | `docker compose down && sudo rm -rf $MINIO_DATA_PATH` |
| Sync `.env` with new keys from `.env.example` | `./scripts/env-sync.sh` |

### `mc` tips

Run any `mc` command as a one-shot container attached to the stack network.
Define this alias once in your shell and reuse it:

```bash
alias mc='docker run --rm -i --network minio_minio_net \
  -e MC_HOST_local="http://${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}@minio:9000" \
  minio/mc'
```

> If you set `MINIO_NAME_SUFFIX` (e.g. `loki`), the network is
> `<project>_minio_net` (default `minio_minio_net`) and the host inside the
> container is `minio` (or `minio-<suffix>` if you renamed it).

Most useful commands:

```bash
# Cluster health and capacity
mc admin info local

# Create / list buckets
mc mb local/my-bucket
mc ls local
mc ls --recursive local/my-bucket

# Service account for an app (don't use root creds in apps)
mc admin user svcacct add local "$MINIO_ROOT_USER"
# → returns Access Key + Secret Key for the app

# Public read-only on a bucket (only when you really need it)
mc anonymous set download local/my-bucket

# Backup / sync to another target (S3, MinIO, local FS)
mc mirror --overwrite --remove local/my-bucket /path/to/backup
```

## Layout

```
.
├── docker-compose.yml   # stack
├── .env.example         # variables (copy to .env)
├── scripts/
│   ├── init.sh          # creates /srv/minio/data{1..4} with correct ownership
│   └── env-sync.sh      # safely merges new vars from .env.example into .env
├── README.md            # English docs (default)
└── README.es.md         # Spanish docs
```

## Security notes

- **Do not expose 9000/9001 to the internet without TLS.** For public prod add
  a reverse proxy (Caddy/Traefik/nginx) terminating TLS and set
  `MINIO_SERVER_URL` + `MINIO_BROWSER_REDIRECT_URL` to the public URLs.
- `.env` must not be committed to git (covered by `.gitignore`).
- Root password ≥ 20 characters. For applications use service account
  credentials (`mc admin user svcacct add`), not the root ones.

## 👨‍💻 Author

<div align="center">
  <img src="https://github.com/villcabo.png" width="100" height="100" style="border-radius: 50%;" alt="villcabo">
  <br/>
  <strong>Bismarck Villca</strong>
  <br/>
  <br/>
  <a href="https://github.com/villcabo">
    <img src="https://img.shields.io/badge/GitHub-villcabo-blue?style=for-the-badge&logo=github" alt="GitHub Profile">
  </a>
  <br/>
  <a href="https://linkedin.com/in/villcabo">
    <img src="https://img.shields.io/badge/LinkedIn-villcabo-0A66C2?style=for-the-badge&logo=linkedin" alt="LinkedIn Profile">
  </a>
  <br/>
  <a href="https://facebook.com/villcabo">
    <img src="https://img.shields.io/badge/Facebook-villcabo-1877F2?style=for-the-badge&logo=facebook" alt="Facebook Profile">
  </a>
  <br/>
  <a href="https://x.com/villcabo">
    <img src="https://img.shields.io/badge/X-@villcabo-000000?style=for-the-badge&logo=x" alt="X Profile">
  </a>
  <br/>
</div>

---

⭐ **If this project helped you, please consider giving it a star!** ⭐
