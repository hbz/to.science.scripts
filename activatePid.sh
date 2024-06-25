#!/bin/bash

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

pid=$1

echo ""
echo "Activate $pid"
curl -s -u$ADMIN_USER:$ADMIN_PASSWORD -XPOST $BACKEND/resource/$pid/activate -H"accept: application/json" 

cd -
