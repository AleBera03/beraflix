#!/bin/bash

set -euo pipefail
source .env
# cd "$(dirname "$0")"

mkdir -p $MEDIA_PATH/arr/data/torrents/{tv,movies,music,books}
mkdir -p $MEDIA_PATH/arr/data/media/{tv,movies,music,books}

get_env() {
  grep -E "^$1=" ".env" | tail -n1 | cut -d= -f2- || true
}

# write/update a variable from .env
set_env() {
  local key="$1" value="$2"
  if grep -qE "^${key}=" ".env"; then
    sed -i "s|^${key}=.*|${key}=${value}|" ".env"
  else
    echo "${key}=${value}" >> ".env"
  fi
}

key_from_config() {
  local file="$1"
  [ -f "$file" ] || return 0
  grep -oP '(?<=<ApiKey>)[^<]+' "$file" | head -n1 || true
}

ensure_key() {
  local name="$1"            
  local config_xml="$2"      # host past of config.xml
  local var="${name}_API_KEY"

  local existing
  existing="$(key_from_config "$config_xml")"
  if [ -n "$existing" ]; then
    set_env "$var" "$existing"
  else
    set_env "$var" "$(openssl rand -hex 16)"
  fi
}

ensure_key SONARR ./sonarr/config/config.xml
ensure_key RADARR ./radarr/config/config.xml

echo "Starting services ..."
docker compose up -d