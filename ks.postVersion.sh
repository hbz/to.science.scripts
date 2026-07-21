#!/bin/bash
# Dieses kleine Skript erzeugt einen Webschnitt (Type Version) für eine bestehende Archivdatei und hängt ihn an einen Parent (Type Webpage) an.
# Autor: Ingolf Kuss
# Erstellungsdatum: 21.07.2026

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

# Standardoptionen
pid=""
versionPid=""
collection="lav"
crawldir=""
warcFilenameBase=""

usage() {
  cat <<EOF
  Dieses kleine Skript erzeugt einen Webschnitt (Type Version) für eine bestehende Archivdatei und hängt ihn an einen Parent (Type Webpage) an.
  Beispielaufruf: $0 -p "nwweb:100" -c "lav" -t "20250620121217" -w "ag-gummersbach-nrw-de-20250620101217044-00000"
  Optionen:
   - c [collection]  die Collection, in der der Webschnitt lebt (gem. outDir und [wayback-]collection in application.conf)
                     z.B. wpull, heritrix, btrix, lav
   - h               Hilfe (dieser Text)
   - p [pid]         die PID der Webpage (Elternobjekt; muss schon existieren)
   - t [timestamp]   Crawldir = ein minutengenauer Zeistempel = der Name des "Crawldir" unter halb von "pid" in outDir
   - v [versionPid]  *** Option wird noch nicht unterstützt *** die PID, die der Webschnitt bekommen soll (leer = zufällig vergeben); Standardwert: $versionPid
   - w [warcFilenameBase]  der Basisname der ersten Archivdatei für diesen Crawl = ein Dateiname ohne Pfad und ohne Endung ;
                           z.B. "ag-gummersbach-nrw-de-20250620101217044-00000"
EOF
  exit 0
  }

# Auswertung der Optionen und Kommandozeilenparameter
OPTIND=1         # Reset in case getopts has been used previously in the shell.
while getopts "c:h?p:t:v:w:" opt; do
    case "$opt" in
    c)  collection=$OPTARG
        ;;
    h|\?) usage
        ;;
    p)  pid=$OPTARG
        ;;
    t)  crawldir=$OPTARG
        ;;
    v)  versionPid=$OPTARG
        ;;
    w)  warcFilenameBase=$OPTARG
        ;;
    esac
done
shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

# bisherige Implementation ; unterstützt keine Collections (in Wayback)
# dataDir="/opt/toscience/wpull-data"
# timestamp="20250904115137"
# filename="warcs/WEB-20250904115143635-00000-2159~localhost~8443.warc.gz"
# curl -XPOST -u$ADMIN_USER:$ADMIN_PASSWORD "$BACKEND/resource/$pid/postVersion?versionPid=$versionPid&dataDir=$dataDir&timestamp=$timestamp&filename=$filename" -H "UserId=gatherposter" -H "Content-Type: text/plain; charset=utf-8";

# Neu seit 21.07.2026 (für LAV-Ingests; unterstützt Collections)
curl -XPOST -u$REGAL_ADMIN:$REGAL_PASSWORD -H "Content-Type: application/json; charset=utf-8; Accept: application/json" -d "{\"pid\":\"$pid\",\"collection\":\"$collection\",\"crawldir\":\"$crawldir\",\"warcFilenameBase\":\"$warcFilenameBase\"}" "$BACKEND/webhooks/externalCrawlIngest"
