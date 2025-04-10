#!/bin/bash
# Dieses Skript löscht eine Anzahl Objekte anhand einer PID-Liste.
# Änderungshistorie
# +------------------------------+----------------------------------------------------------------------------------------
# | Bearbeiter      | Datum      | Grund
# +------------------------------+----------------------------------------------------------------------------------------
# | Ingolf Kuss     | 07.04.2025 | Neuanlage
# +------------------------------+----------------------------------------------------------------------------------------
set -o nounset

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

usage() {
  cat <<EOF
  Dieses Skript löscht eine Anzahl Objekte anhand einer PID-Liste.
  Die PID-Liste ist eine lesbare Datei, die pro Zeile eine PID enthält.
  Format einer PID: $NAMESPACE:<Number>
  Das Skript protokolliert in die Datei $REGAL_LOGS/delete_pids.log. Meldungen werden dort angehängt.

  Beispielaufruf :    ./delete_pids.sh -p -f delete_pids.txt

  Optionen:
   - h               Hilfe (dieser Text)
   - f [PID-Liste]   Übergabe einer PID-Liste = einer lesbaren Datei
   - p               Purge. Falls gesetzt, werden die Objekte der PID-Liste vollständig gelöscht.
EOF
  exit 0
  }

# Default-Werte
filename=""
purge=0

# Auswertung der Optionen und Kommandozeilenparameter
OPTIND=1         # Reset in case getopts has been used previously in the shell.
while getopts "f:h?p" opt; do
    case "$opt" in
    f)  filename=$OPTARG
        ;;
    h|\?) usage
        ;;
    p)  purge=1
        ;;
    esac
done
shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

if [ -z $filename ]; then
  usage
fi
if [ ! -f $filename ]; then
  echo "ERROR: Optionsargument -f \"$filename\" ist keine lesabare Datei! Bitte eine PID-Liste übergeben. Format der PIDs: $NAMESPACE:<Number>"
  exit 0
fi

echo "Hänge Logmeldungen an $REGAL_LOGS/delete_pids.log an."
echo "Beginn lösche PIDs "`date` >> $REGAL_LOGS/delete_pids.log
for i in `cat $filename`
do
  echo "Lösche $i" >> $REGAL_LOGS/delete_pids.log 2>&1
  URL="localhost:9000/resource/$i"
  if [ $purge -eq 1 ]; then
    URL=$URL"?purge=true"
  fi
  curl -XDELETE -u$ADMIN_USER:$ADMIN_PASSWORD $URL >> $REGAL_LOGS/delete_pids.log 2>&1
done
echo "ENDE lösche PIDs "`date` >> $REGAL_LOGS/delete_pids.log
exit 0
