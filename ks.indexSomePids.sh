#! /bin/bash
# Indexiert einige PIDs - gemäß Liste - nach
# Beispielaufruf $0 $REGAL_LOGS/verschwundeneTitel_20250324.txt 7074865
# - erstes Argument: eine Liste. Auf jeder Zeile steht eine PID im Format "edoweb:NNNNNNN"
# - zweites Argument [optional] : die kleinste PID, die indexiert werden soll. Größere PIDs werden übersprungen.

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

Liste=$1
if [ ! -f $Liste ]; then
  echo "ERROR: Argument 1: \"$Liste\" ist keine lesabare Datei!"
  exit 0
fi
firstPid=0
if [ $# -gt 1 ]; then
  firstPid=$2
fi

zeitstempel=`date +"%Y%m%d:%H%M%S"`
echo "Schreibe Log nach $REGAL_LOGS/index-$zeitstempel.log"
for pid in `cat $Liste`; do
  if [ "${pid:7:7}" -gt "$firstPid" ]; then
    # echo $pid
    ./indexPid.sh $pid $BACKEND >>$REGAL_LOGS/index-$zeitstempel.log
  fi
done
