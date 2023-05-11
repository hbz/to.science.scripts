#! /bin/bash


scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

pid=$1
server=$2

echo ""
echo "index $pid"
curl -s -u$REGAL_ADMIN:$REGAL_PASSWORD -XPOST $server/utils/index/$pid -H"accept: application/json"
