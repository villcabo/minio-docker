#!/usr/bin/env bash
# Initialize MinIO data directories from .env (or defaults).
# Idempotent: safe to run multiple times.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Load .env if present (without overriding already-exported shell vars).
if [[ -f .env ]]; then
  set -a
  # shellcheck disable=SC1091
  source .env
  set +a
fi

DATA_PATH="${MINIO_DATA_PATH:-/srv/minio}"
# uid/gid of the `minio-user` inside the official image.
MINIO_UID="${MINIO_UID:-1000}"
MINIO_GID="${MINIO_GID:-1000}"

echo "==> MinIO init"
echo "    data path : $DATA_PATH"
echo "    owner     : ${MINIO_UID}:${MINIO_GID}"

# Use sudo only if we lack write permission on the parent dir.
SUDO=""
parent="$(dirname "$DATA_PATH")"
if [[ ! -w "$parent" ]] && [[ "$(id -u)" -ne 0 ]]; then
  SUDO="sudo"
  echo "    using sudo (no write permission on $parent)"
fi

for i in 1 2 3 4; do
  dir="${DATA_PATH}/data${i}"
  $SUDO mkdir -p "$dir"
  $SUDO chown "${MINIO_UID}:${MINIO_GID}" "$dir"
  echo "    ok: $dir"
done

# Warn if the 4 drives live on the same filesystem
# (for real prod they should be on distinct physical disks).
fs_count=$(df -P "${DATA_PATH}"/data{1..4} 2>/dev/null | awk 'NR>1 {print $1}' | sort -u | wc -l)
if [[ "$fs_count" -eq 1 ]]; then
  echo "    warning: all 4 drives are on the same filesystem — no physical-disk fault tolerance"
fi

echo "==> done"
