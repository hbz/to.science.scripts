#!/bin/bash
# Ruft Browsertrix Crawl Finished Webhook Endpoint auf.
# Verarbeitet alle gefundenen, von Browsertrix fertiggestellen, Archvidateien.
# KS 16.04.2026
source funktionen.sh
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

CRAWLDIR=/data-webarchive26/browsertrix-minio-storage-pvc-pvc-28df4b51-913d-4233-98ee-c4512fe37853/minio/btrix-data/$BTRIX_ORGID
cd $CRAWLDIR
for file in *.wacz; do
 if [ -e "$file" ]; then
  echo "`date` Verarbeite Browsertrix Archivdatei $file"
  filename=$CRAWLDIR/$file
  curl -XPOST -u$REGAL_ADMIN:$REGAL_PASSWORD -H "Content-Type: application/json; Accept: application/json" -d'{"filename":"'$filename'"}' "$BACKEND/webhooks/btrixCrawlFinished"
  continue
 fi  
 ## This is all we needed to know, so we can break after the first iteration
 break
done
cd $scriptdir
