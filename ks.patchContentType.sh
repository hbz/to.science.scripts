#!/bin/bash

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

pid=$1
contentType=$2

echo ""
echo "Patch ContentType of $pid to $contentType"

curl -s -u$ADMIN_USER:$ADMIN_PASSWORD -XPATCH -d'{"contentType":"'$contentType'"}' "$BACKEND/resource/$pid" -H "Content-Type: application/json"
cd -
