#!/bin/bash
# Eine Funktionssammlung für einen Browsertrix-Webclient für bash-Skripte
# Autor        | Datum      | Ticket      | Änderungsgrund
# -------------+------------+-----------------------------------------------------------
# Ingolf Kuss  | 05.05.2026 | TOSDEV-23   | Neuerstellung

source funktionen.sh
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

# Funktionsdefinitionen

function btrix_getBearerToken {
  # Hole ein Träger-Token
  local httpResponse=`curl -s -XPOST -H "Content-Type: application/x-www-form-urlencoded; Accept: application/json" --data 'username='$BTRIX_ADMIN_USERNAME'&password='$BTRIX_ADMIN_PASSWORD'&grant_type=password' "http://$BTRIX_API_URL/auth/jwt/login"`
  # Dann access_token auslesen
  local TOKEN=`echo $httpResponse | jq '.access_token'`
  TOKEN=$(stripOffQuotes $TOKEN)
  echo $TOKEN
}

function btrix_getCrawlOut {
  # Get Crawl Out
  # holt einen bestimmten Crawl
  # z.B. CRAWL_ID="manual-20260421165905-ab0d70dd-922"
  local CRAWL_ID=$1
  curl -XGET -s -H "Authorization: Bearer $TOKEN" -H "Accept: application/json" "http://$BTRIX_API_URL/orgs/$BTRIX_ORGID/crawls/$CRAWL_ID/replay.json"
}
