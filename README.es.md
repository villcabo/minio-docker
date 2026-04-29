# MinIO — Docker Compose (prod)

**Idiomas:** [English](./README.md) · **Español**

Stack de MinIO listo para producción sobre un solo host: SNMD con 4 drives
(erasure coding EC:2), healthcheck, logging rotado y límites de recursos.

## Clonar

```bash
# Default: clona en ./minio-docker
git clone https://github.com/villcabo/minio-docker.git

# Nombre custom: pasá el directorio destino como segundo argumento
git clone https://github.com/villcabo/minio-docker.git mi-nombre-custom
```

## Prerequisitos

- Docker ≥ 24 y Compose v2 (`docker compose version`).
- Linux con cgroups v2 (para que `deploy.resources` aplique).
- NTP sincronizado en el host.
- `sudo` disponible si `MINIO_DATA_PATH` está fuera de tu `$HOME`
  (default `/srv/minio`).

## Despliegue

```bash
# 1. Configurar variables
cp .env.example .env
$EDITOR .env   # setear MINIO_ROOT_USER y MINIO_ROOT_PASSWORD (≥ 20 chars)

# 2. Crear los 4 directorios de datos con el owner correcto
./scripts/init.sh

# 3. Crear la red externa compartida (una sola vez)
#    Si querés otro nombre, cambialo acá y en MINIO_ROUTER_NETWORK en .env.
docker network create --driver bridge --opt com.docker.network.driver.mtu=1500 minio_router

# 4. Levantar
docker compose up -d

# 5. Verificar
docker compose ps           # minio debe estar `healthy`
docker compose logs -f minio
```

### Conectar otros stacks (Loki, apps, etc.)

MinIO se une a dos redes:

- `minio_net` — interna, solo para este proyecto compose.
- `minio_router` — **externa**, compartida entre stacks. Otros proyectos
  compose se atan a ella y llegan a MinIO por su nombre DNS `minio:9000`,
  sin exponer puertos en el host.

Snippet de ejemplo para un stack consumidor (ej. Loki):

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
API S3:  `http://<host>:9000`

> Por defecto los puertos están en `127.0.0.1` (solo loopback). Para exponer
> en LAN, setear `MINIO_API_PORT=0.0.0.0:9000` y
> `MINIO_CONSOLE_PORT=0.0.0.0:9001` en tu `.env`.

## Operación

| Acción | Comando |
| --- | --- |
| Estado | `docker compose ps` |
| Logs en vivo | `docker compose logs -f minio` |
| Reiniciar | `docker compose restart minio` |
| Upgrade | `docker compose pull && docker compose up -d` |
| Detener | `docker compose down` (no borra datos) |
| Borrar todo (¡incluye datos!) | `docker compose down && sudo rm -rf $MINIO_DATA_PATH` |
| Sincronizar `.env` con nuevas keys del `.env.example` | `./scripts/env-sync.sh` |

### Tips de `mc`

Corré cualquier comando `mc` como contenedor one-shot atachado a la red del
stack. Definí este alias una vez en tu shell y reutilizalo:

```bash
alias mc='docker run --rm -i --network minio_minio_net \
  -e MC_HOST_local="http://${MINIO_ROOT_USER}:${MINIO_ROOT_PASSWORD}@minio:9000" \
  minio/mc'
```

> Si seteás `MINIO_NAME_SUFFIX` (ej. `loki`), la red es
> `<project>_minio_net` (default `minio_minio_net`) y el host dentro del
> contenedor es `minio` (o `minio-<suffix>` si lo renombraste).

Comandos más útiles:

```bash
# Salud y capacidad del cluster
mc admin info local

# Crear / listar buckets
mc mb local/mi-bucket
mc ls local
mc ls --recursive local/mi-bucket

# Service account para una app (no uses creds root en apps)
mc admin user svcacct add local "$MINIO_ROOT_USER"
# → retorna Access Key + Secret Key para la app

# Lectura pública en un bucket (solo si realmente lo necesitás)
mc anonymous set download local/mi-bucket

# Backup / sync a otro target (S3, MinIO, FS local)
mc mirror --overwrite --remove local/mi-bucket /ruta/al/backup
```

## Estructura

```
.
├── docker-compose.yml   # stack
├── .env.example         # variables (copiar a .env)
├── scripts/
│   ├── init.sh          # crea /srv/minio/data{1..4} con el owner correcto
│   └── env-sync.sh      # mergea nuevas variables del .env.example al .env
├── README.md            # documentación en inglés (default)
└── README.es.md         # documentación en español
```

## Notas de seguridad

- **No expongas 9000/9001 a internet sin TLS.** Para prod público sumá un
  reverse proxy (Caddy/Traefik/nginx) que termine TLS y configurá
  `MINIO_SERVER_URL` + `MINIO_BROWSER_REDIRECT_URL` con las URLs públicas.
- `.env` no debe commitearse a git (cubierto por `.gitignore`).
- Password root ≥ 20 caracteres. Para aplicaciones usá credenciales de
  service account (`mc admin user svcacct add`), no las root.

## 👨‍💻 Autor

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

⭐ **Si este proyecto te ayudó, ¡considerá darle una estrellita!** ⭐
