#!/bin/bash
# Ruft Wpull Crawl Finished Webhook Endpoint auf.
# Verarbeitet alle gefundenen, von wpull fertiggestellen, Archvidateien.
# KS 11.05.2026
source funktionen.sh
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

WPULL_DATA_FINISHED=$ARCHIVE_HOME/wpull-data-finished
cd $WPULL_DATA_FINISHED
#echo "`date` BEGINN Verarbeitung fertiggestellte wpull-Archivdateien im Verzeichnis $WPULL_DATA_FINISHED."
anz_verarbeitet=0
# Schleifen über pid-Dir und crawldir.
# wpull verschiebt eine WARC-Datei und eine CDX-Datei in das "finished"-Verzeichnis. Verarbeite diese weiter im Webhook (Aufruf des Webhook).
for pid in $NAMESPACE:[0-9]*; do
  if [ ! -d "$pid" ]; then continue; fi
  echo "`date` Verarbeite wpull-finished Verzeichnis pid=$pid"
  cd $pid
  for crawldir in [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*; do
    if [ ! -d "$crawldir" ]; then
      echo "kein Crawldir gefunden ($crawldir)!"
      echo "Leeres PID-Verzeichnis $pid wird gelöscht."
      cd $WPULL_DATA_FINISHED
      rmdir $pid 
      break
    fi
    echo "crawldir=$crawldir"
    for archive in $crawldir/*.warc.gz; do
      if [ ! -f "$archive" ]; then
        echo "keine Archivdatei gefunden ($archive)! Läuft der Crawl noch ?"
        continue
      fi
      warcFilename=`basename $archive`
      echo "Verarbeite wpull-Archivdatei $warcFilename"
      warcFilenameBase=`echo $warcFilename | sed 's/\.warc\.gz$//'`
      #echo "warcFilenameBase=$warcFilenameBase"
      curl -XPOST -u$REGAL_ADMIN:$REGAL_PASSWORD -H "Content-Type: application/json; Accept: application/json" -d'{"pid":"'$pid'","crawldir":"'$crawldir'","warcFilenameBase":"'$warcFilenameBase'"}' "$BACKEND/webhooks/wpullCrawlFinished"
      anz_verarbeitet=$(($anz_verarbeitet+1))
    done 
  done
  cd $WPULL_DATA_FINISHED
done
# echo "$anz_verarbeitet wpull-Archivdateien wurden verarbeitet."
# echo "`date` ENDE Verarbeitung wpull-Archivdateien."
cd $scriptdir
