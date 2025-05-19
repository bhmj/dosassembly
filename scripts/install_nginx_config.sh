#!/bin/bash
CONF=$1
TARGET_NAME=$2
docker network connect ${TARGET_NAME}_net nginx-proxy
export_vars=$(grep -oE '\$\{[A-Z0-9_]+\}' $CONF | sort -u | tr '\n' ' ')
envsubst "$export_vars" < $CONF > /var/nginx-proxy/configs/${TARGET_NAME}.conf
docker exec nginx-proxy nginx -s reload
