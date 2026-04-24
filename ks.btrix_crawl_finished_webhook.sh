#!/bin/bash
# Testet Btrix Crawl Finished Webhook Endpoint
# KS 16.04.2026
source funktionen.sh
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

filename=/data-webarchive26/browsertrix-minio-storage-pvc-pvc-28df4b51-913d-4233-98ee-c4512fe37853/minio/btrix-data/fed230e9-f151-46c1-998f-584ed5ee2630/20260423082449947-17b46cdc-aca-0.wacz
curl -XPOST -u$REGAL_ADMIN:$REGAL_PASSWORD -H "Content-Type: application/json; Accept: application/json" -d'{"filename":"'$filename'"}' "$BACKEND/webhooks/btrixCrawlFinished"
