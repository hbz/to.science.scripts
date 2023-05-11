#! /bin/bash

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

#curl -s -XGET $ELASTICSEARCH/${INDEXNAME}2/_search -d'{"query":{"match_all":{}},"fields":["/@id"],"size":"50000"}'|egrep -o "$INDEXNAME:[^\"]*"|sort|uniq >$REGAL_LOGS/pids.txt
# CHG Kuss 28.01.2021: Erzeugen der PID-Liste auf Grund von Anfragen an Fedora REST-API (nicht Elasticsearch)
perl get_pids.pl -m 100000 -n $INDEXNAME -o $REGAL_LOGS/get_pids.txt

echo "index all"
cat $REGAL_LOGS/get_pids.txt | parallel --jobs 5 ./indexPid.sh {} https://$BACKEND >$REGAL_LOGS/index-`date +"%Y%m%d"`.log 2>&1

cd -
