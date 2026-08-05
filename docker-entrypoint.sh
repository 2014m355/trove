#!/usr/bin/env bash
set -euo pipefail

PUID="${PUID:-1000}"
PGID="${PGID:-1000}"

# docker compose passes unset variables through as an empty string, and
# huggingface_hub takes an empty HF_ENDPOINT literally and builds broken URLs.
for var in HF_ENDPOINT HF_TOKEN UI_PASSWORD HF_HOME; do
  if [ -z "${!var:-}" ]; then
    unset "$var" || true
  fi
done
export HF_HOME="${HF_HOME:-/data/.hf-home}"

# Match the container user to the host so files in the mounted volumes end up
# owned by the right user.
if [ "$(id -u)" = "0" ]; then
  current_gid="$(getent group hf | cut -d: -f3)"
  current_uid="$(id -u hf)"

  if [ "$PGID" != "$current_gid" ]; then
    groupmod -o -g "$PGID" hf
  fi
  if [ "$PUID" != "$current_uid" ]; then
    usermod -o -u "$PUID" hf
  fi

  mkdir -p "${DATA_DIR:-/data}/models" \
           "${DATA_DIR:-/data}/datasets" \
           "${DATA_DIR:-/data}/spaces" \
           "${HF_HOME:-/data/.hf-home}" \
           "${CONFIG_DIR:-/config}"

  # Only touch the top level: a recursive chown over several TB of models would
  # stall every start for minutes.
  chown "$PUID:$PGID" "${DATA_DIR:-/data}" "${CONFIG_DIR:-/config}" \
                      "${DATA_DIR:-/data}/models" "${DATA_DIR:-/data}/datasets" \
                      "${DATA_DIR:-/data}/spaces" "${HF_HOME:-/data/.hf-home}" 2>/dev/null || true
  chown -R "$PUID:$PGID" "${CONFIG_DIR:-/config}" 2>/dev/null || true

  exec gosu "$PUID:$PGID" "$@"
fi

exec "$@"
