#!/bin/bash
# Shell-Skript, dass Crawler-Config aus Browsertrix holt
# KS 24.09.2025
source funktionen.sh
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"                                                           cd $scriptdir
source variables.conf

# Hole ein "Bären-Token"
httpResponse=`curl -s -XPOST -H "Content-Type: application/x-www-form-urlencoded; Accept: application/json" --data 'username='$BTRIX_ADMIN_USERNAME'&password='$BTRIX_ADMIN_PASSWORD'&grant_type=password' "http://$BTRIX_API_URL/auth/jwt/login"`
# dann access_token auslesen
TOKEN=`echo $httpResponse | jq '.access_token'`
TOKEN=$(stripOffQuotes $TOKEN)
#echo "TOKEN=$TOKEN"

# Get Crawl Config Out
# Bergischer Verein für Familienkunde
cid=151175e6-d3d2-48a3-80a3-d39428804c45
# SPD Gütersloh
cid=a02b273c-e9f4-42bb-a51a-5cec80c4eed4
curl -XGET -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" "http://$BTRIX_API_URL/orgs/$BTRIX_ORGID/crawlconfigs/$cid"
