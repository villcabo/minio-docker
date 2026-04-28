# MinIO — Docker Compose (prod)

Production-ready MinIO stack on a single host: SNMD with 4 drives (erasure
coding EC:2), healthcheck, rotated logging, resource limits, and optional
bucket bootstrap.

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
./init.sh

# 3. Create the shared external network (one-time)
#    Name must match MINIO_ROUTER_NETWORK in .env (default: minio_router).
docker network create \
  --driver bridge \
  --opt com.docker.network.driver.mtu=1500 \
  "${MINIO_ROUTER_NETWORK:-minio_router}"

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

### `mc` client from the host

```bash
docker run --rm -it --network minio_minio_net minio/mc \
  alias set local http://minio:9000 "$MINIO_ROOT_USER" "$MINIO_ROOT_PASSWORD"
```

## Layout

```
.
├── docker-compose.yml   # stack
├── .env.example         # variables (copy to .env)
├── init.sh              # creates /srv/minio/data{1..4} with correct ownership
└── README.md
```

## Author

**Bismarck Villca** — [@villcabo](https://github.com/villcabo)

## Security notes

- **Do not expose 9000/9001 to the internet without TLS.** For public prod add
  a reverse proxy (Caddy/Traefik/nginx) terminating TLS and set
  `MINIO_SERVER_URL` + `MINIO_BROWSER_REDIRECT_URL` to the public URLs.
- `.env` must not be committed to git (covered by `.gitignore`).
- Root password ≥ 20 characters. For applications use service account
  credentials (`mc admin user svcacct add`), not the root ones.
