#!/bin/bash
# Behandlung abgebrochener wpull Crawls
# Brauchbare WARC-Dateien und CDX-Dateien werden in das "~/wpull-data-finished"-Verzeichnis verschoben,
#   sofern der Crawl nicht mehr läuft.
# Von dort werden die Dateien weiter über den Webhook "wpull_crawl_finished" verarbeitet.
# KS 16.06.2026
source funktionen.sh
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

WPULL_DATA_CRAWLDIR=$ARCHIVE_HOME/wpull-data-crawldir
WPULL_DATA_FINISHED=$ARCHIVE_HOME/wpull-data-finished
cd $WPULL_DATA_CRAWLDIR
echo "`date` BEGINN Verarbeitung abgebrochene wpull-Archivdateien im Verzeichnis $WPULL_DATA_CRAWLDIR"
anz_verarbeitet=0
# Schleifen über pid-Dir und crawldir.
# Brauchbare WARC-Dateien und CDX-Dateien werden in das "~/wpull-data-finished"-Verzeichnis verschoben,
#   sofern der Crawl nicht mehr läuft.
# Von dort werden die Dateien weiter über den Webhook "wpull_crawl_finished" verarbeitet.
for pid in $NAMESPACE:[0-9]*; do
  if [ ! -d "$pid" ]; then continue; fi
  echo "`date` Verarbeite wpull-data-crawldir Verzeichnis pid=$pid"
  cd $pid
  for crawldir in [0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]*; do
    if [ ! -d "$crawldir" ]; then
      echo "kein Crawldir gefunden ($crawldir)!"
      echo "Leeres PID-Verzeichnis $pid wird gelöscht."
      cd $WPULL_DATA_CRAWLDIR
      rmdir $pid 
      break
    fi
    echo "crawldir=$crawldir"
    cd $crawldir
    for archive in *.warc.gz; do
      if [ ! -f "$archive" ]; then
        echo "Keine Archivdatei *.warc.gz gefunden ($archive)! Gibt es einen abgebrochenen Crawl-Versuch *.warc.gz.attemptN ? Keine Aktionen."
        continue
      fi
      echo "Verarbeite wpull-Archivdatei $archive"
      if [ "`ps -eaf | grep wpull | grep $pid | head -n 1 | cut -d \" \" -f1`" != "" ]; then
	      echo "Crawl läuft noch. Keine Verarbeitung."
      	      cd $WPULL_DATA_CRAWLDIR/$pid
	      break
      fi
      echo "Archivdatei und CDX-Datei werden nach $WPULL_DATA_FINISHED/$pid/$crawldir verschoben."
      if  [ ! -d "$WPULL_DATA_FINISHED/$pid" ]; then
	      mkdir $WPULL_DATA_FINISHED/$pid
      fi
      if  [ ! -d "$WPULL_DATA_FINISHED/$pid/$crawldir" ]; then
	      mkdir $WPULL_DATA_FINISHED/$pid/$crawldir
      fi
      mv $archive $WPULL_DATA_FINISHED/$pid/$crawldir/
      mv *.cdx $WPULL_DATA_FINISHED/$pid/$crawldir/
      anz_verarbeitet=$(($anz_verarbeitet+1))
    done 
    cd $WPULL_DATA_CRAWLDIR/$pid
  done
  cd $WPULL_DATA_CRAWLDIR
done
echo "$anz_verarbeitet wpull-Archivdateien wurden verarbeitet (nach $WPULL_DATA_FINISHED verschoben)."
echo "`date` ENDE Verarbeitung abgebrochender wpull-Archivdateien."
cd $scriptdir
