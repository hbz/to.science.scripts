#!/bin/bash
# Dieses Skript erzeugt anhand einer CSV-Datei fehlende File-Objekte (PDFs) zu vorhandenen Monographien.
# Für den initialen Ladevorgang von "luload".
# Autor: Ingolf Kuss (hbz), Neuanlage 30.10.2025

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf
source funktionen.sh

usage() {
  cat <<EOF
  Dieses Skript erzeugt anhand einer CSV-Datei fehlende File-Objekte (PDFs) zu vorhandenen Monographien.
  Beispielaufruf: $0 -f /opt/toscience/clarivateData/Objekte_HSL_aus\ Alephino_Übergabe_mit\ NZ-MMS-ID_mit_toscienceID.csv
  Optionen:
   - f [Dateiname]   voller Pfad zu einer CSV-Datei
   - o [Dateiname]   Dateiname Output CSV (voller Pfad). Defaults to  <Input CSV Datei>(.csv -> withFileObjects.csv)
   - h               Hilfe (dieser Text)
EOF
  exit 0
  }

convertAccessScheme () {
  local accessScheme=$1
  case $accessScheme in
  "Angemeldete Benutzer")
    echo "private"
    ;;

  Öffentlich)
    echo "public"
    ;;

  Verstecken)
    echo "single"
    ;;

  *)
    echo "private"
    ;;
  esac
}

# Default-Werte
datei=/opt/toscience/clarivateData/Objekte_HSL_aus\ Alephino_Übergabe_mit\ NZ-MMS-ID_mit_toscienceID.csv
outdatei=${datei//.csv$/.withFileObjects.csv}

# Auswertung der Optionen und Kommandozeilenparameter
OPTIND=1         # Reset in case getopts has been used previously in the shell.
while getopts "f:h?o:" opt; do
    case "$opt" in
    f)  datei=$OPTARG
	outdatei=${datei//\.csv/.withFileObjects.csv}
        ;;
    o)  outdatei=$OPTARG
        ;;
    h|\?) usage
        ;;
    esac
done
shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

# Prüfungen
echo "CSV-Datei: $datei"
if [ ! -f "$datei" ]; then
  echo "Bitte übergeben Sie dem Skript über den Schalter -f eine lesbare CSV-Datei."
  usage
fi
echo "Output CSV-Datei: $outdatei"

#### Beginn Hauptverarbeitung ####
echo "Starting script: Create file objects."
# lies CSV-Datei Zeile für Zeile
lineno=0
while read zeile; do 
  unset tosIdMono tosIdPdf pdfPath pdfFile accessScheme
  count=`expr ${count} + 1`
  if [ $count -eq 1 ]; then
	  # Überschriftszeile
	  echo $zeile > "$outdatei"
	  continue
  fi
  tosIdMono=`echo $zeile | cut -d ";" -f4`
  if [ -z "$tosIdMono" ]; then
  	  # Leerzeile oder Monografie noch nicht angelegt
	  echo $zeile >> "$outdatei"
	  continue
  fi
  tosIdPdf=`echo $zeile | cut -d ";" -f7`
  if [ -n "$tosIdPdf" ]; then
  	  # PDF existiert schon in tos, nichts zu tun
	  echo $zeile >> "$outdatei"
	  continue
  fi
  pdfPath=`echo $zeile | cut -d ";" -f8`
  pdfFile=`basename $pdfPath`
  accessScheme=`echo $zeile | cut -d ";" -f9`
  echo "$count: tosIdMono=$tosIdMono pdfFile=$pdfFile accessScheme="$(convertAccessScheme "$accessScheme")
  tosIdPdf=$(createFileObject $(convertAccessScheme "$accessScheme"))
  echo "tosIdPdf=$tosIdPdf created!"
  uploadFile $tosIdPdf $pdfFile
  echo " uploaded to $tosIdPdf."
  appendFileToParent $tosIdMono $tosIdPdf
  # Zurückschreiben der Werte in eine neue CSV-Datei
  unset mmsIdIZ mmdIdNZ titelIdAlephino objectIdAlephino datenpool titelAlephino titelAlma
  mmsIdIZ=`echo $zeile | cut -d ";" -f2`
  mmsIdNZ=`echo $zeile | cut -d ";" -f3`
  titelIdAlephino=`echo $zeile | cut -d ";" -f5`
  objectIdAlephino=`echo $zeile | cut -d ";" -f6`
  datenpool=`echo $zeile | cut -d ";" -f10`
  titelAlephino=`echo $zeile | cut -d ";" -f11`
  titelAlma=`echo $zeile | cut -d ";" -f12`
  echo "x;$mmsIdIZ;$mmsIdNZ;$tosIdMono;$titelIdAlephino;$objectIdAlephino;$tosIdPdf;$pdfPath;$accessScheme;$datenpool;$titelAlephino;$titelAlma" >> "$outdatei" 
done < "$datei"

cd -
exit 0

# Kind anhängen
# curl -u$ADMIN_USER:$ADMIN_PASSWORD -XPATCH -d'{"parentPid":"'$tosIdMono'"}' "$BACKEND/resource/$tosIdPdf" -H"Content-Type: application/json"
