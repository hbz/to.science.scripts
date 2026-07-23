#!/bin/bash
# Autor: I. Kuss, hbz
# eine Funktionssammlung für bash-Skipte

# allgemeiner Kram, Zeichenkettenverarbeitung

# Funktionsdefinitionen
function stripOffQuotes {
  local string=$1;
  local len=${#string};
  echo ${string:1:$len-2};
}

function encoding {
	# find encoding of a file
	file -i $1 | sed 's/=/ /g' |awk '{print $4}'
}

urlencode() {
    # urlencode <string>
    # Quelle: https://unix.stackexchange.com/questions/159253/decoding-url-encoding-percent-encoding
    local length="${#1}"
    for (( i = 0; i < length; i++ )); do
        local c="${1:i:1}"
        case $c in
            [a-zA-Z0-9.~_-]) printf "$c" ;;
            *) printf '%%%02X' "'$c" ;;
        esac
    done
}

urldecode() {
    # urldecode <string>

    local url_encoded="${1//+/ }"
    printf '%b' "${url_encoded//%/\\x}"
}

createFileObject() {
# Erzeugt ein neues Datei-Objekt
  local accessScheme=$1;

  # echo "accessScheme=$accessScheme"
  createMsg=`curl -s -u$ADMIN_USER:$ADMIN_PASSWORD  -H'content-type:application/json' -d"{\"contentType\":\"file\",\"publishScheme\":\"public\",\"accessScheme\":\"$accessScheme\"}" -XPOST "$BACKEND/resource/$NAMESPACE"`
  # echo "createMsg=$createMsg"
  code=`echo $createMsg | jq .code`
  if [ $code != 200 ]; then
    echo "New Resource of type file could not successfully be created! return code = $code. Aborting"
    exit 0
  fi
  text=`echo $createMsg | jq .text`
  text=$(stripOffQuotes "$text")
  # Text bei Leerzeichen umbrechen (split string at IFS)
  read -r -a textArray <<< "$text" 
  neue_id=""
  # Iterate over the array
  for x in "${textArray[@]}"; do
    neue_id=$x
    break # das erste Element ist die neue ID
  done
  echo "$neue_id"
}

uploadFile() {
# Lädt die Datei zu diesem Dateiobjekt hoch
  local tosIdFile=$1;
  local pdfFilename=$2;

  curl -s -u$ADMIN_USER:$ADMIN_PASSWORD -F"data=@$ARCHIVE_HOME/clarivateData/$pdfFilename;type=application/pdf" -XPUT "$BACKEND/resource/$tosIdFile/data"
}

appendFileToParent() {
# Hängt das Dateiobjekt in das Elternobjekt ein
  local tosIdParent=$1;
  local tosIdFile=$2;

  curl -s -u$ADMIN_USER:$ADMIN_PASSWORD -H"Content-Type: application/json" -XPATCH -d'{"parentPid":"'$tosIdParent'"}' "$BACKEND/resource/$tosIdFile"
  echo "$tosIdFile eingehängt in Parent Objekt $tosIdParent"
}

function seconds2HoursMinSec {
  # Diese Funktion konvertiert eine Integer-Angabe für Sekunden in eine Zeichenkette der Form %d h %d m %d s.
  # Quelle: https://blog.jkip.de/in-bash-sekunden-umrechnen-in-stunden-minuten-und-sekunden/
  local seconds=$1;
  local hours=$(( seconds / 3600 ))
  local minutes=$(( (seconds % 3600) / 60 ))
  seconds=$(( seconds % 60 ))
  if [[ $hours -gt 0 ]]; then printf "%dh " $hours; fi
  if [[ $minutes -gt 0 ]]; then printf "%dm " $minutes; fi
  if [[ $seconds -gt 0 ]]; then printf "%ds" $seconds; fi
}

function bytes2GibMibKib {
  # Diese Funktion konvertiert eine Integer-Angabe für Bytes in eine Zeichenkette der Form %d,%1d GiB (MiB oder KiB).
  # Also auf die führende Mengenangabe mit einer Stelle hinter dem Komma.
  local bytes=$1;
  local kib=$(( bytes / 1024 ))
  local mib=$(( kib / 1024 ))
  local gib=$(( mib / 1024 ))
  bytes=$(( bytes % 1024 ))
  kib=$(( kib % 1024 ))
  mib=$(( mib % 1024 ))
  if [[ $gib -gt 0 ]]; then printf "%d,%1d GiB" $gib $(( ( $mib * 100 / 1024 + 5 ) / 10 )); return; fi
  if [[ $mib -gt 0 ]]; then printf "%d,%1d MiB" $mib $(( ( $kib * 100 / 1024 + 5 ) / 10 )); return; fi
  if [[ $kib -gt 0 ]]; then printf "%d,%1d KiB" $kib $(( ( $bytes * 100 / 1024 + 5 ) / 10 )); return; fi
  printf "%d Bytes" $bytes;
}

function formatDiscUsage {
  # Diese Funktion gibt die Angabe zur Speicherbelegung in menschenlesbarer Form aus.
  # Ähnlich wie bytes2GibMibKib, jeodch werden Speicherplatzangaben üblicherweise in Kilobyte angegeben, nicht in Bytes.
  # Führende Mengenangabe mit einer Stelle hinter dem Komma.
  local kilobyte=$1;
  local mib=$(( kilobyte / 1024 ))
  local gib=$(( mib / 1024 ))
  local tib=$(( gib / 1024 ))
  kilobyte=$(( kilobyte % 1024 ))
  mib=$(( mib % 1024 ))
  gib=$(( gib % 1024 ))
  if [[ $tib -gt 0 ]]; then printf "%d,%1d TiB" $tib $(( ( $gib * 100 / 1024 + 5 ) / 10 )); return; fi
  if [[ $gib -gt 0 ]]; then printf "%d,%1d GiB" $gib $(( ( $mib * 100 / 1024 + 5 ) / 10 )); return; fi
  if [[ $mib -gt 0 ]]; then printf "%d,%1d MiB" $mib $(( ( $kilobyte * 100 / 1024 + 5 ) / 10 )); return; fi
  printf "%d KiB" $kilobyte;
}

function calcDownloadSpeed {
  # Diese Funktion berechnet die Download-Geschwindigkeit und gibt sie als menschenlesbare Zeichenkette aus.
  local bytes=$1;
  local seconds=$2;
  local speed=`echo "scale=1; ( $bytes * 10 / $seconds + 0.5 ) / 10" | bc`
  local unit="B/s"
  if (( $(echo "$speed > 1024" | bc -l) )); then
    speed=`echo "scale=1; ( $speed * 10 / 1024 + 0.5 ) / 10" | bc`
    unit="KiB/s"
  fi
  if (( $(echo "$speed > 1024" | bc -l) )); then
    speed=`echo "scale=1; ( $speed * 10 / 1024 + 0.5 ) / 10" | bc`
    unit="MiB/s"
  fi
  if (( $(echo "$speed > 1024" | bc -l) )); then
    speed=`echo "scale=1; ( $speed * 10 / 1024 + 0.5 ) / 10" | bc`
    unit="GiB/s"
  fi
  echo "$speed $unit";
}

function warcio_chk_recompress {
  # Diese Funktion rekomprimiert eine gezippte WARC-Datei, falls notwendig.
  # Das ist für einige vom LAV gelieferte Archive leider notwendig.
  # Sonst kann von "wb-manager add" folgende Fehlermeldung kommen:
  # "ERROR: non-chunked gzip file detected, gzip block continues
  #    beyond single record.
  #
  #    This file is probably not a multi-member gzip but a single gzip file.
  #
  #    To allow seek, a gzipped WARC must have each record compressed into
  #    a single gzip member and concatenated together.
  #
  #    This file is likely still valid and can be fixed by running:
  #
  #    warcio recompress <path/to/file> <path/to/new_file>"
  #
  # Autor: Ingolf Kuss, Anlagedatum: 10.07.2026 für LAV-Importe (TOS-1372, TOS-1369)
  # Beispielaufruf: warcio_chk_recompress /sftp/lav/cvua-westfalen-de $archivdatei[.warc.gz] 

  local lieferverzeichnis=$1
  local archivdatei=$2
  local olddir=$PWD
  cd $lieferverzeichnis
  if ! $PYTHON_HOME/bin/warcio check $archivdatei >> /dev/null; then
    printf "INFO: Rekomprimiere Archivdatei $archivdatei.\n"
    $PYTHON_HOME/bin/warcio recompress $archivdatei "recompressed-$archivdatei"
    mv "recompressed-$archivdatei" $archivdatei 
  fi
  cd $olddir
}

function ermittleErsteUserIdVonKennzeichen {
  local kennzeichen=$1
  local userId=""
  OLDIFS=$IFS
  IFS="."
  read -ra array <<< "$USERIDS"
  for PROVIDER_USERS in "${array[@]}"
  do
    KENNZEICH=`echo $PROVIDER_USERS | sed 's/^\([^\:]*\):\(.*\)$/\1/'`
    USERLISTE=`echo   $PROVIDER_USERS | sed 's/^\([^\:]*\):\(.*\)$/\2/'`
    if [ "$KENNZEICH" != "$kennzeichen" ]; then
      continue
    fi
    # Parse Userliste
    IFS=","
    read -ra array <<< "$USERLISTE"
    for USERID in "${array[@]}"
    do
      userId=$USERID
      break
    done
    if [ "$userId" != "" ]; then
      break
    fi
    IFS="."
  done
  IFS=$OLDIFS
  echo $userId;
}
