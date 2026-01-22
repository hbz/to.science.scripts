#!/bin/bash
# Bestandsstatistik für Dateien, die ab dem 1.11.2023 angelegt wurden.
# (ältere Dateien sind auch über Elasticsearch abfragbar)
# Erstellung: Ingolf Kuss, 08.01.2026; kopiert aus ks.URN-Vergabe_Zeitschriftenhefte.sh

set -o nounset
source funktionen.sh
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf
datetime=`date +"%Y%m%d%H%M"`

usage() {
  cat <<EOF
  Erstellt Bestandsstatistik für Dateien.
  Dieses Skript erzeugt mehrere Listen im Verzeichnis $REGAL_LOGS:
  - get_pids.${datetime}.txt : alle aktiven Fedora-Objekte im Namensraum $INDEXNAME. Eine pid auf jeder Zeile.
  - Bestandsstatistik.${datetime}.keine_dateien.csv  : Objekte aus der Gesamtmenge, die keine Dateien sind.
  - Bestandsstatistik.${datetime}.dateien.csv  : alle Dateien (öffentlich und nicht-öffentlich) mit einigen Metadaten (u.a. publishScheme, creationDate).
  Optionen:
   - h               Hilfe (dieser Text)
EOF
  exit 0
  }

# Default-Werte

# Auswertung der Optionen und Kommandozeilenparameter
OPTIND=1         # Reset in case getopts has been used previously in the shell.
while getopts "h?" opt; do
    case "$opt" in
    h|\?) usage
        ;;
    esac
done
shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

# Beginn der Hauptverarbeitung
  echo `date`
  echo "BEGINN Erzeuge Bestandsstatistik für Dateien."
  echo "Zeitstempel: $datetime"

# Schritt 1. Erzeuge Liste aller fedora-Objekte 
#    (Hintergrund: Objekte mit "hasData" und Anlagedatum ab 1.11.2023 sind nicht im Elasticsearch-Index.
#     Das betrifft alle Dateien und generell alles, was eine gemanagten Datenstrom hat.)
#     PID-Liste wie in indexAll.sh erstellen:
  perl get_pids.pl -m 100000 -n $INDEXNAME -z active -o $REGAL_LOGS/get_pids.${datetime}.txt
  echo `date`
  echo "FERTIG Erzeuge Liste aller Fedora-Objekte $REGAL_LOGS/get_pids.${datetime}.txt ."
  # dieser Schritt lief am 08.01.2026 30 Minuten lang.

# Schritt 2. Hole für jedes Objekt die Metadaten aus der API (.json2)
#    und berücksichtige nur Dateien. Gruppiere diese nach dem Jahr ihrer Neuanlage.
#    Erstelle zwei Listen: 1. pid.csv für URN-Vergabe, 2. pids.andere für alle anderen.
#    Liste 1: Abhängige Dateien (contentType=file) ohne URN. Mit Anlagedatum.
#             es sind Zeitschriftenhefte, aber auch Dateiobjekte, die unterhalb von Monographien hängen.
  keineDateienCsv=$REGAL_LOGS/Bestandsstatistik.${datetime}.keine_dateien.csv
  alleDateienCsv=$REGAL_LOGS/Bestandsstatistik.${datetime}.dateien.csv
  echo "pid;contentType" > $keineDateienCsv
  echo "pid;publishScheme;dataFormat;hasParentPid;dateCreated" > $alleDateienCsv
  # DateienNachAnlagejahr=$REGAL_LOGS/Bestandsstatistik.${datetime}.dateien.$creationYear.csv
#    Dateien sind solche, die
#    1. contentType = "file" .
#    2. Sie sind je nach "publishScheme" öffentlich oder nicht.
#    3. Sie haben Daten im Format "hasData", z.B. = "application/pdf"
#    (4. Sie können eine parentPid haben oder nicht)
#    5. Sie haben ein Anlagedatum isDescribedBy { created } >= 2023-11-01
  for pid in `cat $REGAL_LOGS/get_pids.${datetime}.txt`; do
	  if [ -z "$pid" ]; then continue; fi
	  # echo "pid=$pid"
	  json2=`curl -s -XGET $BACKEND/resource/$pid.json2 -H"accept: application/json"`
	  # 1. ist es vom contentType "file" ?
	  contentType=`echo $json2 | jq '.contentType'`
	  contentType=$(stripOffQuotes "$contentType")
	  # echo "contentType=$contentType"
	  if [ "$contentType" != "file" ]; then
		 echo "$pid;$contentType" >> $keineDateienCsv
		 continue
	  fi
	  # 2. ist es vom publishScheme "public" ?
	  publishScheme=`echo $json2 | jq '.publishScheme'`
	  publishScheme=$(stripOffQuotes "$publishScheme")
	  # echo "publishScheme=$publishScheme"
	  # if [ "$publishScheme" != "public" ]; then
          #	 echo "$pid;$publishScheme" >> $DateienNonPublic
	  #	 continue
	  # fi
	  # 3. Datenformat
	  # wir unterlassen die Prüfung, ob es ein PDF ist und lassen alle Datenformate als "Datei" zu.
	  dataFormat=`echo $json2 | jq '.hasData.format'`
	  dataFormat=$(stripOffQuotes "$dataFormat")
	  # echo "dataFormat=$dataFormat"
	  # if [ "$dataFormat" != "application/pdf" ]; then continue; fi
	  # 4. hat es eine parentPid ?
	  hasParentPid=`echo $json2 | jq 'has("parentPid")'`
	  # echo "hasParentPid=$hasParentPid"
	  # if [ "$hasParentPid" != "true" ]; then continue; fi
	  # 5. Anlagedatum
	  created=`echo $json2 | jq '.isDescribedBy.created'`
	  created=$(stripOffQuotes "$created")
	  # echo "created=$created"
          dateCreated=${created:0:4}${created:5:2}${created:8:2}
	  # echo "dateCreated=$dateCreated"
	  # if [ $dateCreated -lt "20231101" ]; then continue; fi
	  echo "$pid;$publishScheme;$dataFormat;$hasParentPid;$dateCreated" >> $alleDateienCsv
  done
  echo `date`
  echo "ENDE Erzeuge Bestandsstatistik für Dateien."
  # dieser Schritt läuft vom 08.01. auf den 09.01.2026 15 Stunden und 28 Minuten.
