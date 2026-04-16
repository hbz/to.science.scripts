#!/bin/bash
# Testet Btrix Crawl Finished Webhook Endpoint
# KS 16.04.2026
source funktionen.sh
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"                                                           cd $scriptdir
source variables.conf

#curl -XPOST -H "Content-Type: application/json; Accept: application/json" -d'{"orgId":"'$BTRIX_ORGID'","event":"crawlFinished"}' "$BACKEND/webhooks/btrixCrawlFinished"
curl -XPOST -u$REGAL_ADMIN:$REGAL_PASSWORD -H "Content-Type: application/json; Accept: application/json" -d'{"orgId":"'$BTRIX_ORGID'","event":"crawlFinished"}' "$BACKEND/webhooks/btrixCrawlFinished"
