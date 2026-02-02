# Diese Skript setzt das Zugriffsrecht Daten (accessScheme) eines Objektes auf "eingeschränkt".
# Identifikation des Objektes über PID als Übergabeparameter
#!/bin/bash

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf
echo ""
cd -

pid=$1

echo `date`
echo "set access scheme $pid to restricted"

# Der Endpoint /all macht den Call auch auf untergeordnete Objekte :
http_url="$BACKEND/resource/$pid/all"
curl -s -XPATCH -u $REGAL_ADMIN:$REGAL_PASSWORD -H"content-type:application/json" -d'{"accessScheme":"restricted"}' $http_url
