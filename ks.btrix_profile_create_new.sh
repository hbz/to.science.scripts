#!/bin/bash
# Shell-Skript, das ein Browser-Profile "Create New"
# Das legt einen neuen Browser zu einem Browser-Profile an.
# KS 15.06.2026
source funktionen.sh
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"                                                           cd $scriptdir
source variables.conf

# Hole ein "Bären-Token"
httpResponse=`curl -s -XPOST -H "Content-Type: application/x-www-form-urlencoded; Accept: application/json" --data 'username='$BTRIX_ADMIN_USERNAME'&password='$BTRIX_ADMIN_PASSWORD'&grant_type=password' "http://$BTRIX_API_URL/auth/jwt/login"`
# dann access_token auslesen
TOKEN=`echo $httpResponse | jq '.access_token'`
TOKEN=$(stripOffQuotes $TOKEN)
#echo "TOKEN=$TOKEN"

# Get Browser Profile
profileId=$1
url="https://www.hbz-nrw.de"
proxyId=""
curl -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json; Accept: application/json" -d'{"url":"'$url'","profileId":"'$profileId'","crawlerChannel":"default","proxyId":"'$proxyId'"}' "http://$BTRIX_API_URL/orgs/$BTRIX_ORGID/profiles/browser"
