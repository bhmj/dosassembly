#!/bin/bash

CONF_MASK=$1
NAMESPACE=$2

docker network connect ${NAMESPACE}_net nginx-proxy

for CONF in $CONF_MASK; do
  if [[ -f "$CONF" ]]; then
    export_vars=$(grep -oE '\$\{[A-Z0-9_]+\}' "$CONF" | sort -u | tr '\n' ' ')
    CONF_BASENAME=$(basename "$CONF")
    envsubst "$export_vars" < "$CONF" > /var/nginx-proxy/configs/${CONF_BASENAME}
  else
    echo "Skipping '$CONF' : not a regular file."
  fi
done

docker exec nginx-proxy nginx -s reload
