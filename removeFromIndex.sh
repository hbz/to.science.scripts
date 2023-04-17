#!/bin/bash
# Dieses Skript entfernt PIDs anhand einer Liste aus dem Elasticsearch-Index
# Autor: Kuss
# Datum: 29.11.2021
# Grund: EDOZWO-1070

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

list=$1
if [ -z "$list" ] || [ ! -f $list ]; then
  echo "Parameter 1, ($list) ist keine gültige Datei!"
  echo "Aufruf: $0 <PID-Liste>"
  cd -
  exit 0
fi

echo "Entferne PIDs aus dem Elasticsearch-Index anhand von PID-Liste ($list)."
for pid in `cat $list`; do
  echo "Entferne PID: $pid"
  curl -s -u$REGAL_ADMIN:$REGAL_PASSWORD -XDELETE $BACKEND/utils/removeFromIndex/$pid -H"accept: application/json" >>$REGAL_LOGS/removeFromIndex-`date +"%Y%m%d"`.log 2>&1
done

cd -
exit 0
