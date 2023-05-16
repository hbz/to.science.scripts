#!/bin/bash
# dieses Skript stößt einen Lauf der Webgatherer-Sequenz "runGatherer" an.
# Dabei werden alle Websites daraufhin überprüft, ob sie jetzt neu einzusammeln (gathern) sind.
# Falls ja, wird ein Gather-Lauf angestoßen (Übergabe an Heritrix).
# zeitliche Einplaung als cronjob:
#0 20 * * * /opt/regal/regal-scripts/runGatherer.sh >> /opt/regal/logs/runGatherer.log
#              
# Änderungshistorie:
# Autor               | Datum      | Beschreibung
# --------------------+------------+-----------------------------------------
# Ingolf Kuss         | 27.05.2016 | Neuanlage auf edoweb-test
# Ingolf Kuss         | 15.01.2018 | Auslagerung von Systemvariablen
# --------------------+------------+-----------------------------------------

# Der Pfad, in dem dieses Skript steht
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# Einlesen der Umgebungsvariablen
cd $scriptdir
source variables.conf
passwd=$REGAL_PASSWORD
project=$INDEXNAME
regalApi=$BACKEND

if [ ! -d $REGAL_LOGS ]; then
    mkdir $REGAL_LOGS
fi

echo "Beginn runGatherer"
echo "Aktuelles Datum/Uhrzeit: "`date +"%d.%m.%Y %H:%M:%S"`
echo "Projekt: $project"
echo "REGAL_API: $regalApi"


#echo "REGAL_ADMIN=$REGAL_ADMIN"
#echo "REGAL_PASSWD=$passwd"
runGatherer=`curl -s -XPOST -u$REGAL_ADMIN:$passwd "https://$regalApi/utils/runGatherer"`
echo "Ergebnis: $runGatherer\n"; # Ausgabe in Log-Datei

echo "siehe Log-Datei $REGAL_APP/logs/webgatherer.log"
echo "Ende runGatherer am/um "`date +"%d.%m.%Y %H:%M:%S"`
