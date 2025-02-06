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

func2() {
  echo "Starting func2"
  }
