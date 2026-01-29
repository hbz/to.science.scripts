#!/bin/bash
# Öffnen des Vorhangs für Webpages
# Öffentliche Dokumente mit den Notationen 106 und 139 bleiben öffentlich, alles andere wird eingeschränkt.
# KS am 29.01.2026 neu erstellt
# für TOS-1347

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
scriptdir=`echo $scriptdir | sed 's/\/scripts/\/regal-scripts/'`
cd $scriptdir
source variables.conf
cd -

logfile="$REGAL_LOGS/ks.oeffne_vorhang_webpages-"`date +"%Y%m%d%H%M%S"`".log"
echo "\n" >> $logfile
echo "**********************" >> $logfile
echo "BEGINNE oeffne_vorhang_webpages" >> $logfile
echo `date` >> $logfile
echo "**********************" >> $logfile
echo "scriptdir=$scriptdir" >> $logfile
echo "FRONTEND=$FRONTEND" >> $logfile
echo "BACKEND=$BACKEND" >> $logfile
echo "ELASTICSEARCH=$ELASTICSEARCH" >> $logfile
echo "INDEXNAME=$INDEXNAME" >> $logfile


# Selektiere öffentliche Webpages
curl -s -XGET $ELASTICSEARCH/public_${INDEXNAME}2/webpage/_search -d'{ "query":{"match_all":{}},"fields":["/@id"],"size":"50000"}' | egrep -o "$INDEXNAME:[^\"]*" > $REGAL_LOGS/webpageIdsAll.txt
# Diese sollen öffentlich bleiben:
curl -s -XGET $ELASTICSEARCH/public_${INDEXNAME}2/webpage/_search -d'{"query": { "query_string": { "fields": ["subject.notation"], "query": "(139) OR (106)" }},"fields":["/@id"],"size":"50000"}' | egrep -o "$INDEXNAME:[^\"]*" | sort > $REGAL_LOGS/webpageIdsPublic.txt
# Diese haben beide Notationen gleichzeitig (und sollen öffentlich bleiben):
curl -s -XGET $ELASTICSEARCH/public_${INDEXNAME}2/webpage/_search -d'{"query": { "query_string": { "fields": ["subject.notation"], "query": "(139) AND (106)" }},"fields":["/@id"],"size":"50000"}' | egrep -o "$INDEXNAME:[^\"]*" | sort > $REGAL_LOGS/webpageIdsNotation106And139.txt
# Diese haben Notation 139 (andere Art der Auswahl, über Elasticsearch-Funktion "match")
curl -s -XGET $ELASTICSEARCH/public_${INDEXNAME}2/webpage/_search -d'{"query": { "match": { "subject.notation": { "query": "139" } } },"fields":["/@id"],"size":"50000"}' | egrep -o "$INDEXNAME:[^\"]*" | sort > $REGAL_LOGS/webpageIdsNotation139.txt
# Diese haben Notation 106
curl -s -XGET $ELASTICSEARCH/public_${INDEXNAME}2/webpage/_search -d'{"query": { "match": { "subject.notation": { "query": "106" } } },"fields":["/@id"],"size":"50000"}' | egrep -o "$INDEXNAME:[^\"]*" | sort > $REGAL_LOGS/webpageIdsNotation106.txt
# Suche umkehren: umgesetzt werden muss die Menge "weder 106 noch 136"; diese haben nicht 139
curl -s -XGET $ELASTICSEARCH/public_${INDEXNAME}2/webpage/_search -d'{"query": { "bool": { "must_not": [ {"term": {"subject.notation": "139"}} ] } },"fields":["/@id"],"size":"50000"}' | egrep -o "$INDEXNAME:[^\"]*" | sort > $REGAL_LOGS/webpageIdsRestrictedNot139.txt
# Diese haben nicht 106
curl -s -XGET $ELASTICSEARCH/public_${INDEXNAME}2/webpage/_search -d'{"query": { "bool": { "must_not": [ {"term": {"subject.notation": "106"}} ] } },"fields":["/@id"],"size":"50000"}' | egrep -o "$INDEXNAME:[^\"]*" | sort > $REGAL_LOGS/webpageIdsRestrictedNot106.txt
# diese habe keine der gewünschten Notationen und sollen auf "eingeschränkt" gesetzt werden:
curl -s -XGET $ELASTICSEARCH/public_${INDEXNAME}2/webpage/_search -d'{"query": { "bool": { "must_not": [ {"term": {"subject.notation": { "value": "139"}}}, {"term": {"subject.notation": { "value":"106"}}} ] } },"fields":["/@id"],"size":"50000"}' | egrep -o "$INDEXNAME:[^\"]*" | sort > $REGAL_LOGS/webpageIdsRestricted.txt

# zuerst auf testen, ob auch untergeordnete Objekte (version) umgesetzt werden ! JA

# Parallelisieren:
# cat $REGAL_LOGS/webpageIdsRestricted.txt | parallel --jobs 3 ./setAccessSchemePid.sh {} >>$logfile 2>&1

# Ohne Parallelisierung:
# for id in `cat $REGAL_LOGS/webpageIdsRestricted.txt | sort`; do

#   # Der Endpoint /all macht den Call auch auf untergeordnete Objekte :
#   http_url="$BACKEND/resource/$id/all"
#   echo `date` >> $logfile
#   echo "http_url=$http_url" >> $logfile
#   curl -XPATCH -u $REGAL_ADMIN:$REGAL_PASSWORD -H"content-type:application/json" -d'{"accessScheme":"restricted"}' $http_url >> $logfile

# done

echo "++++++++++++++++++++++" >> $logfile
echo "ENDE oeffne_vorhang" >> $logfile
echo `date` >> $logfile
echo "++++++++++++++++++++++" >> $logfile
exit 0;
# Das Umsetzen des AccessRight benötigt durchschnittlich 4 Sekunden pro Objekt (Webpage oder Webschnitt).
# Auf edoweb wären das 16,000 bis 17,000 * 4 = 65000 Sekunden = 18 Stunden.
# Die Laufzeit geht nach der Anzahl Knoten inkl. untergeordneter Objekte (also Unterordnungen = Versionen), nicht nur die Webpages.
# Die untergeordneten Objekte sind nicht im öffentlichen Index, also deren Anzahl hier nicht genau bekannt.
