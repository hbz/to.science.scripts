#!/bin/bash
# Shell-Skript, dass Crawls in Browsertrix sucht.
# KS 22.04.2026
source funktionen.sh
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"                                                           cd $scriptdir
source variables.conf

# Hole ein "Bären-Token"
httpResponse=`curl -s -XPOST -H "Content-Type: application/x-www-form-urlencoded; Accept: application/json" --data 'username='$BTRIX_ADMIN_USERNAME'&password='$BTRIX_ADMIN_PASSWORD'&grant_type=password' "http://$BTRIX_API_URL/auth/jwt/login"`
# dann access_token auslesen
TOKEN=`echo $httpResponse | jq '.access_token'`
TOKEN=$(stripOffQuotes $TOKEN)
#echo "TOKEN=$TOKEN"

# List Crawls
# alle Crawls auflisten
curl -XGET -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" "http://$BTRIX_API_URL/orgs/$BTRIX_ORGID/crawls"
