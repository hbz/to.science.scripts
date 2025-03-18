#!/bin/bash
# Diese Skript erledigt alternativ drei Aufgaben:
# 1. Kontrolle, ob Meldung an den Katalog und URN-Vergabe für kürzlich angelegte Objekte erfolgt ist.
#    (modus = control)
# 2. Nachregistrierung von URNs für Objekte, bei denen die automatische Registrierung fehlschlug.
#    (modus = register)
# 3. minimales Update auf Objekte, die noch nicht an der Katalogschnittstelle sind
#    (modus = katalog)
# Hintergrund: Alle Objekte sollten 4 Tage nach Neuanlage automatisch registriert werden.
#              Die Häkchen "URN an DNB melden" und "Veröffentlichen über OAI" im Reiter "Extras" werden dabei
#              automatisch gesetzt. Im Reiter Status steht "URN: registriert", nachdem die DNB die Meldung
#              an der OAI-Schnittstelle abgeholt hat.
# Diese Skript guckt bei Objekten, die älter als 4 Tage sind.
# zeitliche Einplaung als cronjobs:
#5 7 * * * /opt/regal/regal-scripts/register_urn.sh control  >> /opt/regal/cronjobs/log/control_urn_vergabe.log
#1 1 * * * /opt/regal/regal-scripts/register_urn.sh katalog >> /opt/regal/cronjobs/log/katalog_update.log
#1 0 * * * /opt/regal/regal-scripts/register_urn.sh register >> /opt/regal/cronjobs/log/register_urn.log
#              
# Änderungshistorie:
# Autor               | Datum      | Beschreibung
# --------------------+------------+--------------------------------------------------------------
# Ingolf Kuss         | 07.12.2015 | Neuanlage als ks.control_urn_vergabe.sh
# Ingolf Kuss         | 14.01.2016 | grep => jq
# Ingolf Kuss         | 22.01.2016 | Neuanlage als ks.register_urn.sh
# Ingolf Kuss         | 19.07.2016 | Neuer Modus "katalog"
# Ingolf Kuss         | 12.01.2018 | Auslagerung von Systemvariablen, Umbenennung nach register_urn.sh
# Ingolf Kuss         | 19.12.2019 | Verschiebung vom Verzeichnis cronjobs/ nach regal-scripts/
# Ingolf Kuss         | 16.06.2020 | Nachregistrierung der Objekte seit 19.12.2019
# Ingolf Kuss         | 03.02.2021 | Nachregistrierung der Objekte vom 15.12.2020 - 07.01.2021
# --------------------+------------+--------------------------------------------------------------

# Der Pfad, in dem dieses Skript steht
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf
# Parameter
modus="control";
if [ $# -gt 0 ]; then
  if [ "$1" = "r" ] || [ "$1" = "register" ]; then
    modus="register";
  elif [ "$1" = "k" ] || [ "$1" = "katalog" ]; then
    modus="katalog";
  fi
fi
  
# Umgebungsvariablen
# der Pfad, in dem dieses Skript steht:
home_dir=$scriptdir
server=$SERVER
passwd=$REGAL_PASSWORD
project=${INDEXNAME}2
regalApi=$BACKEND
urn_api=$OAI_PMH
oai_id="oai:api.$server:"

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

# alle neulich erzeugten Objekte durchgehen
# Objekte, die vor drei (war: sieben) bis 21 Tagen angelegt wurden
# >>> Änderung KS20200616
# ab 19./20.12.2019 ist was schief gelaufen.
# lt. Hr. Dirx wurden bis 30.04.2020 keine URNs registriert.
# KS: Fehler in Skript. Elasticsearch-Index edoweb anstatt edoweb2 benutzt. Am 30.04. behoben.
#     Weiterer Fehler im Zusammenspiel dieses Skriptes mit "variables.conf". https://-Prefix erschien doppelt vor regalApi. Am 15.06. behoben.
# nun soll zunächst der 14-Tages-Zeitraum 19.12.19-01.01.20 bearbeitet werden. Dieses am 16.06.
# dann der Zeitraum 26.12.-08.01. - am 17.06. - und so fort.
# Der 27. bearbeitete Zeitraum ist 18.6.-01.07. und dieser wird am 12.07. bearbeitet.
# Dann kann man wieder auf Normalbetrieb gehen. 
# Die erste Normalverarbeitung ist der Zeitraum 23.06.-10.07. und dieser wird am 13.07. verarbeitet.
# Rechenregel: Startdatum = 12.12.2019 + (Tage seit 15.06.)*7
# <<< ENDE Änderung KS20200616
# >>> Kommentar KS20210203
# Die Nachregistrierung lief vom 19.12.20 - 26.01.2021 nicht. Absichtliche Aussetzung wg. EDOZWO-1044 u. EDOZWO-1033.
# Die Objekte mit Anlagedatum 15.12.20 - 06.01.21 müssen nachregistriert werden.
# Am 04.02. wird erstmals ein 14-Tages-Zeitraum nachregistriert, nämlich der vom 15.12.-28.12.20.
# Dann verschiebt sich jeden Tag das Startdatum um 7 Tage nach vorne.
# Am 07.02. wird der Zeitraum vom 05.01.-18.01. nachregistriert.
# Am 08.02. erfolgt erstmals wieder eine Normalverarbeitung, nämlich der Zeitraum 19.1.-05.02.21.
# >>> ENDE Kommentar KS20210203
# Ergebnisliste in eine Datei schreiben; auch eine E-Mail verschicken.
outdatei=$REGAL_TMP/${modus}_urn.$$.out.txt
if [ -f $outdatei ]; then
 rm $outdatei
fi
# E-Mail Inhalt anlegen
mailbodydatei=$REGAL_TMP/mail_$modus.$$.out.txt
if [ -f $mailbodydatei ]; then
 rm $mailbodydatei
fi

if [ "$modus" = "control" ]; then
  echo "Kontrolle von Katalogmeldung und von URN-Vergabe" >> $mailbodydatei
elif [ "$modus" = "register" ]; then
  echo "Folgende Objekte wurden nachregistriert:" >> $mailbodydatei
elif [ "$modus" = "katalog" ]; then
  echo "Nicht erfolgte Katalogmeldungen => minimaler Update" >> $mailbodydatei
fi

aktdate=`date +"%d.%m.%Y"`
echo "Aktuelles Datum: $aktdate" >> $mailbodydatei
echo "home-Verzeichnis: $home_dir" >> $mailbodydatei
echo "Projekt: $project" >> $mailbodydatei
echo "Server: $server" >> $mailbodydatei
typeset -i sekundenseit1970
# typeset -i sekundenseit1970_am_202007130000
typeset -i sekundenseit1970_am_202102080000
# typeset -i sekundenseit1970_am_20191212
typeset -i sekundenseit1970_am_20201208
typeset -i vonsekunden
typeset -i bissekunden
sekundenseit1970=`date +"%s"`

sekundenseit1970_am_202102080000=`date -d"2021-02-08 00:00:00" +"%s"`
if [ $sekundenseit1970 -lt $sekundenseit1970_am_202102080000 ]; then
  # Nachregistrierung der Objekte vom 15.12.2020 bis 06.01.2021
  sekundenseit1970_am_20201208=`date -d"2020-12-08 00:01:00" +"%s"`
  tage_seit_20210203=$(( (`date +"%s"` - `date -d"2021-02-03 00:01:00" +"%s"`) / 86400 ))
  vonsekunden=$(( $sekundenseit1970_am_20201208 + ($tage_seit_20210203 * 7)*86400 ))
  bissekunden=$(( $vonsekunden + 14*86400 ))
# sekundenseit1970_am_202007130000=`date -d"2020-07-13 00:00:00" +"%s"`
# if [ $sekundenseit1970 -lt $sekundenseit1970_am_202007130000 ]; then
#   # Nachregistrierung der Objekte vom 19.12.2019 bis 01.07.2020
#   sekundenseit1970_am_20191212=`date -d"2019-12-12 00:01:00" +"%s"`
#   tage_seit_20200615=$(( (`date +"%s"` - `date -d"2020-06-15 00:01:00" +"%s"`) / 86400 ))
#   vonsekunden=$(( $sekundenseit1970_am_20191212 + ($tage_seit_20200615*7)*86400 ))
#   bissekunden=$(( $vonsekunden + 14*86400 ))
else
  # Normalbetrieb: Nachregistrierung von Objekten, die vor sieben Tagen bis vor 21 Tagen angelegt wurden.
  vonsekunden=$sekundenseit1970-1814400; # - 3 Wochen
  bissekunden=$sekundenseit1970-259200;  # - 3 Tage  (war: 604800 für 1 Woche)
fi

vondatum_hr=`date -d @$vonsekunden +"%Y-%m-%d"`
bisdatum_hr=`date -d @$bissekunden +"%Y-%m-%d"`
echo "Objekte mit Anlagedatum von $vondatum_hr bis $bisdatum_hr:" >> $mailbodydatei
resultset=`curl -s -XGET $ELASTICSEARCH/$project/journal,monograph,file,webpage,version/_search -d'{"query":{"range" : {"isDescribedBy.created":{"from":"'$vondatum_hr'","to":"'$bisdatum_hr'"}} },"fields":["isDescribedBy.created","publishScheme"],"size":"50000"}'`
#echo "resultset="
#echo $resultset | jq "."
for hit in `echo $resultset | jq -c ".hits.hits[]"`
do
    #echo "hit=";
    #echo $hit | jq "."

    unset id;
    id=`echo $hit | jq "._id"`
    id=$(stripOffQuotes $id)
    #echo "id=$id";

    unset contentType;
    contentType=`echo $hit | jq "._type"`
    contentType=$(stripOffQuotes $contentType)
    #echo "type=$contentType";

    unset cdate;
    for elem in `echo $hit | jq -c ".fields[\"isDescribedBy.created\"][]"`
    do
        cdate=${elem:1:19};
        break;
    done
    #echo "cdate=$cdate";

    unset publishScheme;
    publishScheme=`echo $hit | jq -c ".fields[\"publishScheme\"][]"`
    publishScheme=$(stripOffQuotes $publishScheme)

    if [ -z "$id" ]; then
        continue;
    fi
    if [ -z "$cdate" ]; then
        continue;
    fi

    # Bearbeitung dieser id,cdate
    echo "$aktdate: bearbeite id=$id, Anlagedatum $cdate, Zugriffsrecht Metadaten: $publishScheme"; # Ausgabe in log-Datei
    url=http://$server/resource/$id
    # Ist das Objekt an der OAI-Schnittstelle "da" ?
    # 1. ist das Objekt an den Katalog gemeldet worden ?
    cat="?";
    if [ "$contentType" = "file" ] || [ "$contentType" = "issue" ] || [ "$contentType" = "volume" ] || [ "$contentType" = "version" ] || [ "$publishScheme" = "private" ]; then
      cat="X" # Status nicht anwendbar, da Objekt nicht im Katalog verzeichnet wird.
    else
      curlout_kat=$REGAL_TMP/curlout.$$.kat.xml
      curl -s -o $curlout_kat "$urn_api/?verb=GetRecord&metadataPrefix=mabxml-1&identifier=$oai_id$id"
      istda_kat=$(grep -c "<identifier>$oai_id$id</identifier>" $curlout_kat);
      if [ $istda_kat -gt 0 ]
      then
        cat="J"
      else
        istnichtda_kat=$(grep -c "<error code=\"idDoesNotExist\">" $curlout_kat);
        if [ $istnichtda_kat ]
        then
         cat="N"
        fi
      fi
      rm $curlout_kat
    fi

    # 2. ist das Objekt an die DNB gemeldet worden (für URN-Vergabe) ?
    if [ "$modus" != "katalog" ]; then
      dnb="?"
      curlout_dnb=$REGAL_TMP/curlout.$$.dnb.xml
      curl -s -o $curlout_dnb "$urn_api/?verb=GetRecord&metadataPrefix=epicur&identifier=$oai_id$id"
      istda_dnb=$(grep -c "<identifier>$oai_id$id</identifier>" $curlout_dnb);
      if [ $istda_dnb -gt 0 ]
      then
        dnb="J"
      else
        istnichtda_dnb=$(grep -c "<error code=\"idDoesNotExist\">" $curlout_dnb);
        if [ $istnichtda_dnb ]
        then
          dnb="N"
        fi
      fi
      rm $curlout_dnb
    fi
    
    if [ "$modus" = "register" ] && [ "$dnb" != "J" ]; then
      # Nachregistrierung des Objektes für URN-Vergabe
      addURN=`curl -s -XPOST -u$REGAL_ADMIN:$passwd "$regalApi/utils/addUrn?id=${id:7}&namespace=$INDEXNAME&snid=hbz:929:02"`
      echo "$aktdate: $addURN\n"; # Ausgabe in log-Datei
      addURNresponse=${addURN:0:80}
      echo -e "$url\t$cdate\t$cat\t$dnb\t$contentType\t\t$addURNresponse" >> $outdatei
    fi

    if [ "$modus" = "control" ]; then
      echo -e "$url\t$cdate\t$cat\t$dnb\t$contentType" >> $outdatei
    fi

    if [ "$modus" = "katalog" ] && [ "$cat" = "N" ]; then
      # Ausgabe und Weiterbehandlung nur im Fehlerfalle
      # minimalen Update auf das Objekt machen, z.B. über erneutes Setzen der Zugriffrechte
      # dadurch wird das Objekt dann an der Katalogschnittstelle gemeldet
      update=`curl -s -H "Content-Type: application/json" -XPATCH -u$REGAL_ADMIN:$passwd -d'{"@id":"'$id'"}' "$regalApi/resource/$id"`
      aktdatetime=`date +"%d.%m.%Y %H:%M:%S"`
      echo "$aktdatetime: $update\n"; # Ausgabe in log-Datei
      updateResponse=${update:0:80}
      echo -e "$url\t$cdate\t$cat\t$contentType\t\t$updateResponse" >> $outdatei
    fi

    id="";
    cdate="";
done

if [ "$modus" = "control" ]; then
  echo -e "URL\t\t\t\t\t\tAnlagedatum\t\tKatalog\tDNB\tcontentType" >> $mailbodydatei
elif [ "$modus" = "register" ]; then
  echo -e "URL\t\t\t\t\t\tAnlagedatum\t\tKatalog\tDNB\tcontentType\t\"addUrn\"-Response (abbrev. to max 80 chars)" >> $mailbodydatei
elif [ "$modus" = "katalog" ]; then
  echo -e "URL\t\t\t\t\t\tAnlagedatum\t\tKatalog\tcontentType\t\"update\"-Response (abbrev. to max 80 chars)" >> $mailbodydatei
fi
if [ -s $outdatei ]; then
  # outdatei ist nicht leer
  outdateisort=$REGAL_TMP/ctrl_urn.$$.out.sort.txt
  sort $outdatei > $outdateisort
  rm $outdatei
  cat $outdateisort >> $mailbodydatei
  rm $outdateisort

  # Versenden des Ergebnisses der Pruefung als E-Mail
  if [ "$modus" = "control" ]; then
    recipients=$EMAIL_RECIPIENT_PROJECT_ADMIN;
  else
    # recipients=$EMAIL_RECIPIENT_ADMIN_USERS; # nie an LBZ verschicken
    recipients=$EMAIL_RECIPIENT_PROJECT_ADMIN;
  fi
  subject=" ";
  if [ "$modus" = "control" ]; then
    subject="$project : URN-Vergabe Kontroll-Report";
  elif [ "$modus" = "register" ]; then
    subject="$project : URN-Nachregistrierung";
  elif [ "$modus" = "katalog" ]; then
    subject="$project : WARN: NICHT an KATALOG gemeldete Objekte !!";
  fi
  OLDIFS=$IFS
  IFS=" "
  read -ra array <<< "$recipients"
  for recipient in "${array[@]}"
  do
    mailx -s "$subject" $recipient < $mailbodydatei
  done
  IFS=$OLDIFS
  # rm $mailbodydatei
fi

cd -
