#!/bin/bash
#  Dieses Skript legt eine WebpageVersion für eine bestehende WARC-Datei an.
#  Es wird angenommen, dass diese WARC-Datei unterhalb des Verzechnisses
#  dataDir liegt.
#  Achtung ! Die URL in der aktuellen Conf (Webpage-Konfigurationsdatei) 
#    muss mit der URL zum Zeitpunkt des Einsammelns der WARC-Datei übereinstimmen.
#    Ansonsten kann die WARC-Datei evtl. von Wayback nicht gefunden werden.
#    Der Link unter "Zum Webschnitt" wird nämlich für die aktuelle URL erzeugt.
#    Ggfs. muss also vor Aufruf dieses Skripts die URL in der Conf vorübergehend
#    geändert werden, auf einen alten Stand.
# 
#  @author Ingolf Kuss | 23.05.2024 | Neuanlage für EDOZWO-1161
# 
#  @param pid die Pid der Webpage (Elternobjekt; muss schon existieren)
#  @param versionPid gewünschte Pid für die Version (7-stellig numerisch) oder
#           leer (Pid wird generiert)
#  @param dataDir Datenhauptverzeichnis, unter dem die WARC-Datei liegt. Z.B.
#           /opt/toscience/wpull-data
#  @param timestamp Der Zeitstempel des Crawl. Ist auch Name des
#           Unterverzeichnisses für den Crawl. Aus dem Datum wird der
#           Bezeichner (Label auf der UI) für den Webschnitt generiert.
#  @param filename Der Dateiname der Archivdatei (ohne Pfadangaben, aber mit
#           Dateiendung) (WARC-Archiv).
#  @return a new website version pointing to the posted crawl.

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

usage() {
  cat <<EOF
  Legt einen Toscience-Webpage-Version für eine bestehende WARC Datei an.
  Die Version wird an eine bestehende Webpage angehängt.
  Beispielaufruf:        ./postWebpageVersion.sh -p toscience:1234 -t 20240523165500 -f WEB-www.vgwaldfischbach-burgalben.de-20240523.warc.gz

  Optionen:
   - d [dataDir]    Das Datenhauptverzeichnis, unter dem die WARC-Datei liegt. Standardwert: $dataDir
   - f [filename]   Der Dateiname der Archivdatei (ohne Pfadangaben, aber mit Dateiendung) (WARC-Archiv)
                    Beispielwert: WEB-www.vgwaldfischbach-burgalben.de-20240523.warc.gz , Standardwert: $login_datei
   - g              gesprächig (verbose), Standardwert: $verbose
   - h              Hilfe (dieser Text)
   - p [PID]        Die PID (persistenter Identifikator) der Webpage (Elternobjekt), z.B. toscience:1234
   - s              silent off (nicht still), Standardwert: $silent_off
   - t [timestamp]  Der Zeitstempel des Crawl. Ist auch Name des Unterverzeichnisses für den Crawl. 
                    Aus dem Datum wird der Bezeichner (Label auf der UI) für den Webschnitt generiert.
                    Beispiel: timestamp = 20240523165500 => Label 2024-05-23. Standardwert: $timestamp
   - v [versionPid] Die gewünschte Pid für die Version (7-stellig numerisch) oder leer (Pid wird generiert), Standardwert: $versionPid
EOF
  exit 0
  }

# Default-Werte
dataDir=$ARCHIVE_HOME/wpull-data
filename=""
verbose=0
pid=""
silent_off=0
timestamp=""
versionPid=""

# Auswertung der Optionen und Kommandozeilenparameter
OPTIND=1         # Reset in case getopts has been used previously in the shell.
while getopts "d:f:gh?p:st:v:" opt; do
    case "$opt" in
    d)  dataDir=$OPTARG
        ;;
    f)  filename=$OPTARG
        ;;
    g)  verbose=1
        ;;
    h|\?) usage
        ;;
    p)  pid=$OPTARG
        ;;
    s)  silent_off=1
        ;;
    t)  timestamp=$OPTARG
        ;;
    v)  versionPid=$OPTARG
        ;;
    esac
done
shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

# Beginn der Hauptverarbeitung

echo "Lege einen Toscience-Webpage-Version für eine bestehende WARC Datei an."
echo "PID: $pid"
echo "versionPid: $versionPid"
echo "dataDir: $dataDir"
echo "timestamp: $timestamp"
echo "filename: $filename"
echo "verbose: $verbose"
echo "silent_off: $silent_off"

curlopts=""
if [ $silent_off != 1 ]; then
  curlopts="$curlopts -s"
fi
if [ $verbose == 1 ]; then
  curlopts="$curlopts -v"
fi

echo "curl -s -u$ADMIN_USER:$ADMIN_PASSWORD -XPOST -H \"Accept: application/json\" \"$BACKEND/resource/$pid/postVersion?versionPid=$versionPid&dataDir=$dataDir&timestamp=$timestamp&filename=$filename\""
curl -s -u$ADMIN_USER:$ADMIN_PASSWORD -XPOST -H "Accept: application/json" "$BACKEND/resource/$pid/postVersion?versionPid=$versionPid&dataDir=$dataDir&timestamp=$timestamp&filename=$filename"
echo

cd -
exit 0 
