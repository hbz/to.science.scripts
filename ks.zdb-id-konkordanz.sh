#!/bin/bash
# Diese Skript erstellt eine Konkordanz ZDB-ID <=> edoweb-ID
#              
# Änderungshistorie:
# Autor               | Datum      | Beschreibung
# --------------------+------------+----------------------------------------------------------------------
# Ingolf Kuss         | 15.12.2022 | Neuanlage für EDOZWO-1022 (Vorbereitungen zum "Öffnen des Vorhangs")
# --------------------+------------+----------------------------------------------------------------------

# Der Pfad, in dem dieses Skript steht
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf
  
# Umgebungsvariablen
regalApi=$BACKEND

if [ ! -d $REGAL_LOGS ]; then
    mkdir $REGAL_LOGS
fi
if [ ! -d $REGAL_TMP ]; then
    mkdir $REGAL_TMP
fi

# bash-Funktionen
function stripOffQuotes {
  local string=$1;
  local len=${#string};
  echo ${string:1:$len-2};
}

# Ergebnisliste in eine Datei schreiben
outdatei=`echo $0 | sed 's/^\.\///' | sed 's/\.sh$//'`".CSV"
echo "outdatei=$outdatei"
if [ -f $outdatei ]; then
 rm $outdatei
fi

#aktdate=`date +"%d.%m.%Y"`
#echo "Aktuelles Datum: $aktdate" >> $mailbodydatei

echo "Hole alle Zeitschriften"
resultset=`curl -s -XGET $ELASTICSEARCH/${INDEXNAME}2/journal/_search -d'{"query":{"match_all":{}},"fields":["zdbId"],"size":"10000"}'`
# echo "resultset="
# echo $resultset | jq "."
echo "edoweb-ID;ZDB-ID" > $outdatei
for hit in `echo $resultset | jq -c ".hits.hits[]"`
do
    # echo "hit=";
    # echo $hit | jq "."

    unset id;
    id=`echo $hit | jq "._id"`
    id=$(stripOffQuotes $id)
    # echo "id=$id";

    if [ -z "$id" ]; then
        continue;
    fi

    unset zdbid;
    for elem in `echo $hit | jq -c ".fields[\"zdbId\"][]"`
    do
        zdbid=$elem;
        zdbid=$(stripOffQuotes $zdbid)
        break;
    done
    # echo "zdbid=$zdbid";

    # Bearbeitung dieser id,cdate
    echo "$id;$zdbid" >> $outdatei

    id="";
    zdbif="";
done

if [ -s $outdatei ]; then
  # outdatei ist nicht leer
  outdateisort=$REGAL_TMP/$outdatei.$$
  sort $outdatei > $outdateisort
  rm $outdatei
  cat $outdateisort >> $outdatei
  rm $outdateisort
fi

cd -
