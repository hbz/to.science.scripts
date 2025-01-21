#!/bin/bash
# Legt eine Webpage anhand von URL, vorläufigem Titel und ggfs. Intervall an.
# Für TOS-1178 (UB Bonn 800 Webpages)
# Ingolf Kuss, hbz. Anlagedatum: 21.01.2025

source funktionen.sh
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

usage() {
  cat <<EOF
  Erstellt einen Webarchivierung Datensatz (Webpage)
  Beispielaufruf:        $0 Titel URL Intervall

  Optionen:
   - h               Hilfe (dieser Text)
   - s               silent off (nicht still), Standardwert: $silent_off
   - v               verbose (gesprächig), Standardwert: $verbose
EOF
  exit 0
  }

# Default-Werte
silent_off=1
verbose=0

# Auswertung der Optionen und Kommandozeilenparameter
OPTIND=1         # Reset in case getopts has been used previously in the shell.
while getopts "h?sv" opt; do
    case "$opt" in
    h|\?) usage
        ;;
    s)  silent_off=0
        ;;
    v)  verbose=1
        ;;
    esac
done
shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift
title=$1
url=$2
intervall=$3


# Beginn der Hauptverarbeitung
if [ ! -f $csv_datei ]; then
  echo "ERROR: ($csv_datei) ist keine reguläre Datei !"
  exit 0
fi
curlopts=""
if [ $silent_off != 1 ]; then
  curlopts="$curlopts -s"
fi
if [ $verbose == 1 ]; then
  curlopts="$curlopts -v"
fi


url_encoded=$(urlencode $url)
title_encoded=$(urlencode "$title")
intervall_encoded=$(urlencode "$intervall")
echo "curl $curlopts -XPOST \"$BACKEND/resource/$NAMESPACE/createWebpage?url=$url_encoded&title=$title_encoded&interval=$intervall_encoded\""
resultat=`curl $curlopts -u$ADMIN_USER:$PASSWORD -H"content-type:application/json" -XPOST -d"{\"contentType\":\"webpage\"}" "$BACKEND/resource/$NAMESPACE/createWebpage?url=$url_encoded&title=$title_encoded&interval=$intervall_encoded"`
echo $resultat
id=`echo $resultat | jq ".[\"@id\"]"`
id=$(stripOffQuotes "$id")
echo
echo "Webpage mit pid erzeugt: $id"
exit 0
