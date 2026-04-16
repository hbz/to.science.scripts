#!/bin/bash
# Shell-Skript, dass Event Webhooks Urls setzt
# KS 16.04.2026
source funktionen.sh
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"                                                           cd $scriptdir
source variables.conf

# Hole ein Träger-Token
httpResponse=`curl -s -XPOST -H "Content-Type: application/x-www-form-urlencoded; Accept: application/json" --data 'username='$BTRIX_ADMIN_USERNAME'&password='$BTRIX_ADMIN_PASSWORD'&grant_type=password' "http://$BTRIX_API_URL/auth/jwt/login"`
# dann access_token auslesen
TOKEN=`echo $httpResponse | jq '.access_token'`
TOKEN=$(stripOffQuotes $TOKEN)
echo "TOKEN=$TOKEN"
# Update Event Webhook Urls
crawlFinishedUrl="$BACKEND/webhooks/btrixCrawlFinished"
curl -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json; Accept: application/json" -d'{"crawlFinished":"'$crawlFinishedUrl'"}' "http://$BTRIX_API_URL/orgs/$BTRIX_ORGID/event-webhook-urls"
