#!/bin/bash

trap 'exit 0' SIGTERM

OLDPORT=0
PORT=0
COOKIE_FILE="/tmp/qb_cookie.txt"

if [[ -e $COOKIE_FILE ]]; then
  rm -f $COOKIE_FILE
fi

# wait for successfull login
EXIT_CODE=1
while true
do
  # save cookie for next calls
  curl -s -c $COOKIE_FILE \
    --header 'Referer: http://127.0.0.1:8080' \
    --data-urlencode "username=$1" \
    --data-urlencode "password=$2" \
    http://127.0.0.1:8080/api/v2/auth/login
  EXIT_CODE=$?

  if [[ $EXIT_CODE -eq 0 ]]; then
    echo "Successful login!"
    break
  else
    sleep 5
  fi
done


while true
do

  if [[ -r "/pia-shared/port.dat" ]]; then
    PORT=$(cat /pia-shared/port.dat)
    echo "DEBUG: Readed port: $PORT"
  else
    echo "DEBUG: File /pia-shared/port.dat not readable"
  fi

  # if port has changed, modify via webui listen port
  if [[ $OLDPORT -ne $PORT ]]; then
    echo "Setting Qbittorent port settings ($PORT) via WebUI..."
    curl -s -X POST "http://127.0.0.1:8080/api/v2/app/setPreferences" \
        --header 'Referer: http://127.0.0.1:8080' \
        --data-urlencode 'json={"listen_port": '$PORT'}' \
        -b $COOKIE_FILE
    OLDPORT=$PORT
  fi

  TIME_SLEEP=30

  sleep $TIME_SLEEP &
  wait $!
done