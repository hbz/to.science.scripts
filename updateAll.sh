#!/bin/bash

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
numOfUpdatePids=`grep  "Enrichment.*succeeded!" /tmp/updateMetadata | grep -v "Not updated"|grep -o "$INDEXNAME:[^\ ]*"|sort|uniq|wc -l`
echo "Updated Pids $numOfUpdatePids" >> $log
grep  "Enrichment.*succeeded!" /tmp/updateMetadata | grep -v "Not updated"|grep -o "$INDEXNAME:[^\ ]*"|sort|uniq >> $log
cd -

# ****************************
# E-Mail verschicken mit Summe
# ****************************
mailbodydatei=$REGAL_TMP/mail_updateAll.$$.out.txt
echo "******************************************" > $mailbodydatei
echo "$PROJECT wöchentlicher Update All Report" >> $mailbodydatei
echo "******************************************" >> $mailbodydatei
aktdate=`date +"%d.%m.%Y %H:%M:%S"`
echo "Aktuelles Datum und Uhrzeit: $aktdate" >> $mailbodydatei
echo "Bericht für den Server: $SERVER" >> $mailbodydatei
echo "" >> $mailbodydatei
echo "Aktualisiere alle Titelobjekte (Monographien, Zeitschriften, Websites), die seit der letzen Änderung in Lobid modifiziert wurden." >> $mailbodydatei
echo "Anzahl tatsächliche aktualisierter Titelobjekte, lobidifiziert & angereichert:" >> $mailbodydatei
echo "    $numOfUpdatePids" >> $mailbodydatei
echo "Im Einzelnen:" >> $mailbodydatei
grep  "Enrichment.*succeeded!" /tmp/updateMetadata | grep -v "Not updated"|grep -o "$NAMESPACE:[^\ ]*"|sort|uniq >> $mailbodydatei

subject="$PROJECT wöchentlicher Update All Report"
recipients=$EMAIL_RECIPIENT_ADMIN_USERS
mailx -s "$subject" "$recipients" < $mailbodydatei
# rm $mailbodydatei
