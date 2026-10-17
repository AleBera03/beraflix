#!/bin/bash

trap 'exit 0' SIGTERM

QB_URL="http://127.0.0.1:8080"
COOKIE_FILE="/tmp/qb_cookie.txt"
PORT_FILE="/pia-shared/port.dat"

USERNAME="$1"
PASSWORD="$2"

# seconds
POLL_INTERVAL=30
RETRY_INTERVAL=60
BANNED_INTERVAL=600

OLDPORT=0

rm -f "$COOKIE_FILE"

# true when the API answers without a login
qb_session_ok() {
  local version
  version=$(curl -s -b "$COOKIE_FILE" --header "Referer: $QB_URL" \
    "$QB_URL/api/v2/app/version") || return 1

  case "$version" in
    v*) return 0 ;;
    *)  return 1 ;;
  esac
}

qb_login() {
  local response
  response=$(curl -s -c "$COOKIE_FILE" --header "Referer: $QB_URL" \
    --data-urlencode "username=$USERNAME" \
    --data-urlencode "password=$PASSWORD" \
    "$QB_URL/api/v2/auth/login")

  if qb_session_ok; then
    return 0
  fi

  echo "Login failed: ${response:-<empty response>}"

  case "$response" in
    *banned*) return 2 ;;
    *)        return 1 ;;
  esac
}

qb_ensure_session() {
  qb_session_ok && return 0
  qb_login
}

qb_set_port() {
  local code
  code=$(curl -s -o /dev/null -w '%{http_code}' -X POST \
    "$QB_URL/api/v2/app/setPreferences" \
    --header "Referer: $QB_URL" \
    --data-urlencode "json={\"listen_port\": $1}" \
    -b "$COOKIE_FILE")

  if [[ "$code" == "200" ]]; then
    return 0
  fi

  echo "setPreferences failed (HTTP $code)"
  return 1
}

# wait for successful login
while true
do
  qb_ensure_session
  case $? in
    0) echo "Successful login!"; break ;;
    2) WAIT=$BANNED_INTERVAL ;;
    *) WAIT=$RETRY_INTERVAL ;;
  esac

  sleep "$WAIT" &
  wait $!
done

while true
do
  PORT=""

  if [[ -r "$PORT_FILE" ]]; then
    PORT=$(cat "$PORT_FILE")
  else
    echo "DEBUG: File $PORT_FILE not readable"
  fi

  # guard against an empty or half-written port file
  if [[ "$PORT" =~ ^[0-9]+$ ]] && [[ "$PORT" -gt 0 ]] && [[ "$PORT" -le 65535 ]]; then
    echo "DEBUG: Readed port: $PORT"

    # if port has changed, modify via webui listen port
    if [[ "$OLDPORT" -ne "$PORT" ]]; then
      echo "Setting Qbittorent port settings ($PORT) via WebUI..."

      if qb_ensure_session && qb_set_port "$PORT"; then
        echo "Listen port set to $PORT"
        OLDPORT=$PORT
      else
        # leave OLDPORT untouched so the next cycle retries
        echo "Could not set listen port, retrying in ${POLL_INTERVAL}s"
      fi
    fi
  elif [[ -n "$PORT" ]]; then
    echo "DEBUG: Invalid port value in $PORT_FILE: '$PORT'"
  fi

  sleep "$POLL_INTERVAL" &
  wait $!
done