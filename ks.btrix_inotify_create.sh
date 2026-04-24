#!/bin/bash
# Überwachungsprogramm für neue Browsertrix-Crawls.
# Dieses Skript muss immer laufen, um alle beendeten Browsertrix-Crawls nach toscience zu integrieren.
# Erstellung: Ingolf Kuss, 22.04.2025. Quelle: https://wiki.ubuntuusers.de/inotify/

set -o nounset
source funktionen.sh
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf
datetime=`date +"%Y%m%d%H%M"`

usage() {
  cat <<EOF
  Überwachungsprogramm für neue Browsertrix-Crawls.
  Das Skript startet einen Verarbeitungsprozess, sobald Browsertrix einen Crawl erfolgreich beendet hat.
  Dieses Skript muss immer laufen, um alle beendeten Browsertrix-Crawls nach toscience zu integrieren.
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
# ****************************
echo `date`
echo "BEGINN Start watching Browsertrix Crawl Completion."

# Diese Schleife gibt jedes mal einen Text aus, wenn eine Datei im angegebenen Verzeichnis erstellt wurde. 
# Hier wird inotifywait nie beendet. Die Ausgabe wird in der Schleife eingelesen und weiter benutzt.

inotifywait -mq -e create --format %w%f "/data-webarchive26/browsertrix-minio-storage-pvc-pvc-28df4b51-913d-4233-98ee-c4512fe37853/minio/btrix-data/fed230e9-f151-46c1-998f-584ed5ee2630" | while read FILE
do
    echo "Die Datei $FILE wurde gerade erstellt."
    # z.B. Die Datei /data-webarchive26/browsertrix-minio-storage-pvc-pvc-28df4b51-913d-4233-98ee-c4512fe37853/minio/btrix-data/fed230e9-f151-46c1-998f-584ed5ee2630/zabel wurde gerade erstellt.
done

exit 0
