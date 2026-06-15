#!/bin/bash
# Shell-Skript, das ein Browser-Profile "Create Browser to New"
# Das legt ein Browser-Profil für einen laufenden Browser an.
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

# Create Browser to New
#browserid="prf-2933b7fd27"
browserid=$1
name="Test-Profile"
description=""
#tags="[\"edoweb\"]"
tags=""
curl -XPOST -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json; Accept: application/json" -d'{"browserid":"'$browserid'","name":"'$name'","description":"'$description'","tags":['$tags']}' "http://$BTRIX_API_URL/orgs/$BTRIX_ORGID/profiles"
