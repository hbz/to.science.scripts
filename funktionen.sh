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
