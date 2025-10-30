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

func2() {
  echo "Starting func2"
  }
