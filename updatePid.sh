#!/bin/bash

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

pid=$1
server=$2
date=$3

echo ""
echo "lobidify $pid"
curl -s -u$REGAL_ADMIN:$REGAL_PASSWORD -XPOST $server/utils/updateMetadata/$pid?date=$date -H"accept: application/json" 

cd -
