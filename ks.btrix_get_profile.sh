#!/bin/bash
# Shell-Skript, das Browser Profile via ID liest.
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
PROFILE_ID=$1
curl -XGET -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" "http://$BTRIX_API_URL/orgs/$BTRIX_ORGID/profiles/$PROFILE_ID"

