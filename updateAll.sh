#! /bin/bash

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf


curl -s -XGET $ELASTICSEARCH/${INDEXNAME}2/journal,monograph,webpage/_search -d'{"query":{"match_all":{}},"fields":["/@id"],"size":"50000"}'|egrep -o "$INDEXNAME:[^\"]*">$REGAL_LOGS/titleObjects.txt
for i in `cat $REGAL_LOGS/titleObjects.txt`;do ht=`curl -s $ELASTICSEARCH//${INDEXNAME}2/_all/$i | egrep -o "hbzId\":[\[\"]{1,2}[^\"]*"|egrep  -o "[A-Z]{2}[0-9]{9}"`; if [ ${#ht} -eq 11 ] ; then echo $i , $ht; else echo $i , XXXXXXXXXXX; fi ;done |sort > $REGAL_LOGS/pid-catalog-conc-`date +"%Y%m%d"`.csv


log="$REGAL_LOGS/lobidify-`date +"%Y%m%d"`.log"
echo "lobidify & enrich"
echo "Find logfile in $log"

cat $REGAL_LOGS/titleObjects.txt | parallel --jobs 2 ./updatePid.sh {} $BACKEND > $log 2>&1
cp $log /tmp/updateMetadata
echo >> $log
echo "Summary" >> $log
numOfUpdatePids=`grep  "Enrichment.*succeeded!" /tmp/updateMetadata | grep -v "Not updated"|grep -o "edoweb:[^\ ]*"|sort|uniq|wc -l`
echo "Updated Pids $numOfUpdatePids" >> $log
grep  "Enrichment.*succeeded!" /tmp/updateMetadata | grep -v "Not updated"|grep -o "edoweb:[^\ ]*"|sort|uniq >> $log
cd -
