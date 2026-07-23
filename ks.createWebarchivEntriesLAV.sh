#!/bin/bash
# Autor: Ingolf Kuss, hbz
# Erstellungsdatum: 03.07.2026
# Beschreibung: Erstellt Webpages und Webschnitte für vom LAV gesammelte Archivdateien anhand einer CSV-Datei
# Änderungshistorie
# +------------------------------+----------------------------------------------------------------------------------------
# | Bearbeiter      | Datum      | Grund
# +------------------------------+----------------------------------------------------------------------------------------
# | Ingolf Kuss     | 03.07.2026 | Neuanlage
# +------------------------------+----------------------------------------------------------------------------------------
# Nummernkreise auf aion:    100 -  9.999 : Webpages des LAV (werden durch dieses Skript angelegt)
#                         10.000 - 39.999 : Webpages der drei LBs (durch das Skript ks.createWebarchivEntries.sh angelegt)
#                         40.000 -          Webschnitte (LBs und LAV) (z.Zt. bis 51.987, bevor dieses Skript läuft)
#                                             die vom LAV werden durch dieses Skript angelegt.
# "Nummernkreise" auf iphthime:
#                             10 -  3.181   Webschnitte und Webpages der LBs (bis 26.01.2026, 16:39 Uhr).
#                          4.000 - 14.000   Webpages des LAV (werden durch dieses Skript angelegt)
#                         20.967 -          Webschnitte und Webpages der LBs und des LAV (seit 26.01.2026, 18:15 Uhr; z.Zt. bis 21.695)
set -o nounset
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf
source funktionen.sh

usage() {
  cat <<EOF
  Erstellt Webpages und Webschnitte für vom LAV gesammelte Archivdateien anhand einer CSV-Datei
  Die CSV-Datei enthät: Titel;URL;Verzeichnis;Anzahl WARCs;Crawler;
  Beispielaufrufe:       ./ks.createWebarchivEntriesLAV.sh -f 2 -t 11 -b 4001 -i ../src/Webcrawls_LAV_NRW_2025_2026-06-30.csv  >> ../logs/ks.createWebarchivEntriesLAV.2-11.log 
                       -- legt 10 Webpages im Namensraum 4001 bis 4010 an, sowie Webschnitte für die dazugehörigen, mitgelieferten Webarchive
			./ks.createWebarchivEntriesLAV.sh -f 35 -t 35 -b 4028 -i ../src/Webcrawls_LAV_NRW_2025_2026-06-30.csv  >> ../logs/ks.createWebarchivEntriesLAV.35.log
                       -- legt eine Webpage mit PID 4028 an, sowie Webschnitte für die dazugehörigen, mitgelieferten Webarchive

  Optionen:
   - b [PID]         Beginn-PID; die erste PID im Nummernkreis für Webpages, die angelegt werden soll. Zählt dann hoch.
                         Standard: leer (=> PID wird zufällig vergeben). Webschnitt-PIDs werden zufällig vergeben.
   - f [von]         von; erste zu bearbeitende Zeile der CSV-Datei, Standard: $von
   - h               Hilfe (dieser Text)
   - i [Input-Datei] Webarchiv-Daten im CSV-Format, Dateiname. Default: $csv_datei
   - l [Bib-Kürzel]  Landesbibliotheks-Kürzel (hier nur LAV), Standardwert: $lb
   - s               silent off (nicht still), Standardwert: $silent_off
   - t [bis]         bis; letzte zu bearbeitende Zeile der CSV-Datei. Setze auf 0 oder -1 für "alle". Standard: $bis
   - v               verbose (gesprächig), Standardwert: $verbose
EOF
  exit 0
  }

function nextLine {
	printf "WARN: Archivdateien werden nicht verschoben und Webschnitt wird nicht angelegt.\n"
	cd $olddir
	if [ -n "$pid" ]; then
		pid=$(($pid+1))
	fi
}

# Default-Werte
beginnPid="4001"
von=2
csv_datei="/opt/toscience/src/Webcrawls_LAV_NRW_2025_2026-06-30.csv"
lb="LAV"
silent_off=0
bis=11
verbose=0

# Auslesen der Optionen und Kommandozeilenparameter
OPTIND=1         # Reset in case getopts has been used previously in the shell.
while getopts "b:f:h?i:l:st:v" opt; do
    case "$opt" in
    b)  beginnPid=$OPTARG
        ;;
    f)  von=$OPTARG
        ;;
    h|\?) usage
        ;;
    i)  csv_datei=$OPTARG
        ;;
    l)  lb=$OPTARG
        ;;
    s)  silent_off=1
        ;;
    t)  bis=$OPTARG
        ;;
    v)  verbose=1
        ;;
    esac
done
shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

# weitere Verarbeitung der Kommandozeilenparameter
if [ ! -f $csv_datei ]; then
  echo "ERROR: ($csv_datei) ist keine reguläre Datei !"
  exit 0
fi
curlopts=""
if [ $silent_off != 1 ]; then
  curlopts="$curlopts -s"
fi
if [ $verbose == 1 ]; then
  curlopts="$curlopts -v"
fi

echo "BEGINN Skript $0."
echo "Lege LAV-Webpages und -Webschnitte an anhand von Datei: $csv_datei"
echo "BACKEND=$BACKEND"
if [ -n "$beginnPid" ]; then
  echo "erste Pid: $beginnPid"
fi
echo "erste Zeile: $von"
echo "letzte Zeile: $bis"
echo "Landesbibliotheks-Kürzel: $lb"

# get encoding format
encoding=$(encoding $csv_datei)
echo "encoding=$encoding"
# change encoding to utf8
export LC_CTYPE= LC_ALL="de_DE.UTF-8"
export LANG="de_DE"
echo "INFO: Erzeuge Datei $csv_datei.UTF-8"
iconv -f $encoding -t utf8 $csv_datei > $csv_datei.UTF-8
echo

# ********************************
# *** BEGINN Hauptverarbeitung ***
# ********************************
# Lies die Input-Datei Zeile für Zeile ein
n=0
pid=$beginnPid
while read zeile; do
	# Die gelieferte CSV-Datei Zeile für Zeile einlesen
        n=$(($n+1))
	if [ $n -lt $von ]; then
		continue
	fi
	if [ $bis -gt 0 ] && [ $n -gt $bis ]; then
		continue
	fi
	if [[ $zeile == ^* ]]; then
              	# Kommentarzeile
                continue
        fi
	printf "Zeile Nr. $n\n"
	# Split lines at semicolon
	## Mask spaces by <
	zeile_maskiert=$(echo $zeile | tr " " "<")
	arr=($(echo $zeile_maskiert | tr ";" "\n"))
        Titel=$(echo ${arr[0]} | tr "<" " ")
        URL=$(echo ${arr[1]} | tr "<" " ")
        Intervall="einmal jährlich"
        # subDomainKZ=$(echo ${arr[4]} | tr "<" " ")  # "X" falls mit Subdomains
        crawlSubdomains=true
	Verzeichnis=$(echo ${arr[2]} | tr "<" " ")
	anz_warcs=$(echo ${arr[3]} | tr "<" " ")
	crawler=$(echo ${arr[4]} | tr "<" " " | tr '[:upper:]' '[:lower:]')
	if [ "$crawler" = "browsertrix" ]; then crawler="btrix"; fi
	warcDate=""
        if [ ${#arr[@]} -gt 5 ]; then
		warcDate=$(echo ${arr[5]} | tr "<" " ")
        fi

	echo "Titel: $Titel"
	echo "URL: $URL"
	echo "Intervall: $Intervall"
	# if [ -n "$subDomainKZ" ]; then
	#	echo "subDomainKZ: $subDomainKZ"
	# fi
	echo "crawlSubdomains: $crawlSubdomains"
	echo "Verzeichnis: $Verzeichnis"
	echo "Anzahl WARCs: $anz_warcs"
	echo "Crawler: $crawler"
	if [ -n "$warcDate" ]; then
		echo "WARC-Date: $warcDate" # Format: "2025-11-28T02:18:52Z" = UTC
	fi
	if [ -n "$pid" ]; then
		echo "PID: $pid"
	fi


	# Jetzt eine Webpage anlegen
	Gatherconf="{\"name\":\"$NAMESPACE:$pid\",\"active\":false,\"robotsPolicy\":\"ignore\",\"maxCrawlSize\":0,\"urlsExcluded\":[\"(?i)(.(avi|wmv|mpe?g|mp3|mp4|mov|webm))$\",\"(?i)(suche|kalender|terminplaner).*$\"]"
	if [ "$crawler" = "heritrix" ]; then
		Gatherconf=$Gatherconf",\"crawlerSelection\":\"$crawler\",\"agentIdSelection\":\"LAV_Heritrix\",\"deepness\":12,\"waitSecBtRequests\":3,\"waitRetry\":120,\"tries\":10}"
	elif [ "$crawler" = "btrix" ]; then
		Gatherconf=$Gatherconf",\"crawlerSelection\":\"$crawler\",\"agentIdSelection\":\"LAV_Browsertrix\",\"deepness\":-1,\"waitSecBtRequests\":0,\"waitRetry\":120}"
	elif [ "$crawler" = "wget" ]; then
		Gatherconf=$Gatherconf",\"crawlerSelection\":\"$crawler\",\"agentIdSelection\":\"Wget\",\"deepness\":12,\"waitSecBtRequests\":4}"
	else
		Gatherconf=$Gatherconf"}"
	fi
	printf "INFO: Creating a Webpage für Verzeichnis %s\n" $Verzeichnis
	printf "INFO: Using Gatherconf %s\n" $Gatherconf
	# createdBy gelangt nach RELS-EXT:
	#   bei Create.overrideNodeMembers kommt es vom ToScienceObject in den Node (nur createdBy, nicht die Struktur isDescribedBy).
	#   von dort wird es beim Aufruf von FedoracFacade.updateNode => Utils.updateRelsExt nach RELS-EXT geschrieben.
	#   in den Metadatenstrom (toscience oder Metadata2) wird es aber auf diese Weise nicht geschrieben.
	#   Daher wird es auch nicht im Ansichts-Tab angezeigt.
	#   Für die Aufnahme in die Facetten ist aber die Übernahme von createdBy in den RELS-EXT-Datenstrom entscheidend.
	createdBy="lav-nrw"
	retcode=`./createWebpage.sh $curlopts "$Titel" "$URL" "$createdBy" "$Intervall" "$pid" "$crawlSubdomains" "$Gatherconf"`
	echo $retcode
	olddir=$PWD
	if [[ "$retcode" =~  ^.*ERROR.*$ ]]; then
		printf "ERROR: Webpage zum Titel \"%s\", URL \"%s\", pid %s konnte nicht  angelegt werden!\n" "$Titel" $URL $NAMESPACE:$pid
		nextLine
		continue
	fi
	printf "INFO: Eine Webpage zum Titel \"%s\", URL \"%s\", pid %s wurde angelegt.\n" "$Titel" $URL $NAMESPACE:$pid

	# Jetzt noch einen PUT/PATCH auf die Webpage hinterher schicken, damit im Ansichts-Tab "Publikationstype: Archivierte Webseite" angezeigt wird.
	# (PUT metadata)

	##  Lade Metadaten im Format toscience.json zu dem Objekt hoch  NEIN, das funktioniert noch nicht.
	## UserId für LAV holen / das ist der User namens "lav-nrw"
	## die userId gelangt in den toscience-Datenstrom
	# userId=$(ermittleErsteUserIdVonKennzeichen "LAV")
	# cat > "$REGAL_TMP/$NAMESPACE:$pid.json" <<ENDE
#{"rdftype":[{"prefLabel":"Archivierte Webseite","@id":"http://purl.org/lobid/lv#ArchivedWebPage"}],"@id":"$NAMESPACE:$pid","id":"$BACKEND/resource/$NAMESPACE:$pid","title":["$Titel"],"isDescribedBy":{"createdBy":"$userId"}}
#ENDE
	# echo "curl $curlopts --form \"data=@$REGAL_TMP/$NAMESPACE:$pid.json;type=application/json;charset=utf-8\" -XPUT \"$BACKEND/resource/$NAMESPACE:$pid/uploadUpdateMetadata\""
	# resultat=`curl $curlopts -u$ADMIN_USER:$ADMIN_PASSWORD --form "data=@$REGAL_TMP/$NAMESPACE:$pid.json;type=application/json;charset=utf-8" -XPUT "$BACKEND/resource/$NAMESPACE:$pid/uploadUpdateMetadata"`
	# echo $resultat
	# => im Datenstrom toscience ist der Content-Typ (rdftype) O.K., aber im Datenstrom metadata2 steht "ReserachData". Leider wird letzteres auch auf der UI angezeigt.
	# Die userId gelangt in den Datenstrom toscience (Struktur isDescribedBy -> createdBy) und wird im Ansichts-Tab als "Erstellt von" angezeigt.

	# Dieser PUT funktioniert zwar und er wird auch genauso durchgeführt, wenn man die Webpage über das Frontend anlegt.
	# Wir haben diesen PUT aber in die Methode Create.createWebpage eingebaut, damit man eine Webpage im Batch mit nur einem HTTP-Request anlegen kann.
	# text_body="<$NAMESPACE:$pid> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://purl.org/lobid/lv#ArchivedWebPage> .
# <$NAMESPACE:$pid> <http://purl.org/dc/terms/title> \"$Titel\" ."
	# echo "curl $curlopts -XPUT -H \"Content-Type: text/plain; charset=utf-8; Accept: application/json\" --data-binary \"$text_body\" \"$BACKEND/resource/$NAMESPACE:$pid/metadata2\""; echo
	# resultat=`curl $curlopts -XPUT -u$REGAL_ADMIN:$REGAL_PASSWORD -H "Content-Type: text/plain; charset=utf-8; Accept: application/json" --data-binary "$text_body" "$BACKEND/resource/$NAMESPACE:$pid/metadata2"`
	# echo $resultat
	echo


	# Jetzt die im angegebenem Verzeichnis mitgelieferten Archivdateien auswerten:
	# -  Zeitstempel extrahieren
	# -  Namen einer Archivdatei auswählen
	zeitstempel=""
	warcFilename=""
	if [ "$crawler" = "wget" ]; then
		# Crawl-Datum der Excel-Datei entnehmen
		zeitstempel=`date '+%Y%m%d%H%M%S' -d "$warcDate"` # Datumszeitstempel in lokaler Zeit
	fi
	lieferverzeichnis="/sftp/lav/$Verzeichnis"
	if [ ! -d "$lieferverzeichnis" ]; then
		printf "ERROR: Lieferverzeichnis %s nicht gefunden!\n" $lieferverzeichnis
		nextLine
		continue
	fi
	cd $lieferverzeichnis
	for archivdatei in *.warc.gz; do
		if [ ! -e "$archivdatei" ]; then break; fi
		if [[ "$archivdatei" =~ ^WEB-([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})[0-9]{3}-00000-.*\.warc\.gz$ ]] \
		|| [[ "$archivdatei" =~ ^.*([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})[0-9]{3}-00000\.warc\.gz$ ]] \
		|| [[ "$archivdatei" =~ ^.*-([0-9]{4})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})([0-9]{2})-[0-9a-f]{8}-[0-9a-f]{3}-[0-9]{17}-0\.warc\.gz$ ]]; then
			# Heritrix: Datumsstempel variiert => den kleinsten nehmen (Startdatum); das ist der von der Datei "-00000"; z.B. "WEB-20250225153259290-00000-61314~thinkcentre~8443.warc.gz" oder "tieraerztekammer-nordrhein-de-20250904111305942-00000.warc.gz"
			# Browsertrix: das 1. Datum zählt; z.B. "my-organization-zfu-de-manual-20251215115117-47f2ea43-240-20251215115125472-1.warc.gz"
			warcDate=`printf "%s-%s-%sT%s:%s:%sZ" ${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]} ${BASH_REMATCH[4]} ${BASH_REMATCH[5]} ${BASH_REMATCH[6]}` # Zeit in UTC
			zeitstempel=`date '+%Y%m%d%H%M%S' -d "$warcDate"` # Datumszeitstempel in lokaler Zeit
			warcFilename=$archivdatei
			break
		fi
		if [[ "$archivdatei" =~ ^.*-00000\.warc\.gz$ ]]; then
			# Wget
			warcFilename=$archivdatei
			break
		fi
	done
	if [ -z "${zeitstempel:-}" ]; then
		printf "ERROR: Zeitstempel für den Crawl im Verzeichnis %s kann nicht ermittelt werden!\n" $Verzeichnis
		nextLine
		continue
	fi
	if [ -z "${warcFilename:-}" ] || [ ! -e "$warcFilename" ]; then
		printf "ERROR: Archivdatei für den Crawl im Verzeichnis %s kann nicht ermittelt werden!\n" $Verzeichnis
		nextLine
		continue
	fi
	printf "INFO: Zeitstempel %s (lokaler Zeit) für diesen Crawl ermittelt.\n" $zeitstempel
	printf "INFO: Archivdatei %s für diesen Crawl ermittelt (es kann noch weitere geben).\n" $warcFilename

	
	# Die Archvidateien in ein Verzeichnis ~/lav-data/$NAMESPACE:$pid/$zeitstempel verschieben (auf einer mit Wayback geteilten Platte)
	crawlverz=$ARCHIVE_HOME/lav-data/$NAMESPACE:$pid/$zeitstempel
	if mkdir -p $crawlverz; then
		printf "INFO: Crawlverzeichnis %s angelegt.\n" $crawlverz
	else
		printf "ERROR: Crawlverzeichnis %s konnte nicht angelegt werden!\n" $crawlverz
		nextLine
		continue
	fi
	for archivdatei in *.warc.gz *.warc; do
		if [ ! -e "$archivdatei" ]; then continue; fi
		if [[ "$archivdatei" =~ ^.*\.warc\.gz$ ]]; then
			printf "INFO: Checking Rekompression Archivdatei $archivdatei.\n"
			warcio_chk_recompress $lieferverzeichnis $archivdatei
		fi
		if mv $archivdatei $crawlverz; then
			printf "INFO: Archivdatei %s in das Crawlverzeichnis %s verschoben.\n" $archivdatei $crawlverz
		else
			printf "ERROR: Archivdatei %s konnte nicht in das Crawlverzeichnis %s verschoben werden!\n" $archivdatei $crawlverz
		fi
	done
	# Das Ursprungsverzeichnis löschen (es sollte leer sein)
	cd ..
	if rmdir $Verzeichnis; then
		printf "INFO: Ursprungsverzeichnis /sftp/lav/%s wurde gelöscht.\n" $Verzeichnis
	else
		printf "ERROR: Ursprungsverzeichnis /sftp/lav/%s konnte nicht gelöscht werden!\n" $Verzeichnis
	fi
	
	
	# Und jetzt einen Webschnitt für dieses Crawl-Verzeichnis anlegen.
	warcFilenameBase=`echo $warcFilename | sed 's/\.warc\.gz$//'`
	json_body="{\"pid\":\"$NAMESPACE:$pid\",\"collection\":\"lav\",\"crawldir\":\"$zeitstempel\",\"warcFilenameBase\":\"$warcFilenameBase\"}"
	echo "curl $curlopts -XPOST -H \"Content-Type: application/json; charset=utf-8; Accept: application/json\" -d \"$json_body\" \"$BACKEND/webhooks/externalCrawlIngest\""
	resultat=`curl $curlopts -XPOST -u$REGAL_ADMIN:$REGAL_PASSWORD -H "Content-Type: application/json; charset=utf-8; Accept: application/json" -d "$json_body" "$BACKEND/webhooks/externalCrawlIngest"`
	echo $resultat
	id=`echo $resultat | jq ".[\"@id\"]"`
	if [ -z "${id:-}" ] || [ "$id" = "null" ]; then
		echo "ERROR: Fehler beim Anlegen des Webschnittes für pid $pid!"
		cd $olddir
		if [ -n "$pid" ]; then
			pid=$(($pid+1))
		fi
		continue
	fi
	id=$(stripOffQuotes "$id")
	echo
	printf "INFO: Ein Webschnitt zur pid %s, crawldir %s wurde mit PID %s angelegt.\n" $NAMESPACE:$pid $zeitstempel $id

	#   Es wird ein falscher Datenstrom toscienceJson angelegt (Title des Parent anstatt Label). 
	#   Das geschieht in Create.createWebpageVersion => createRessource => updateResource => overrideNodeMembers => linkWithParent => inheritTitle => Modify.addMetadataField => updateLobididy2AndEnrichMetadata
	#   => Behoben, in dem ich direkt danach, in Create.createWebpageVersion mit Modify().updateLobidify2AndEnrichMetadata mit "Label" patche (bei Create.createWebpage wird diese Methode auch aufgerufen, nur mit "Titel").

	# Jetzt noch einen PUT/PATCH auf die WebsiteVersion hinterher schicken, damit sie auch in den Metadaten den rdftype "WebpageVersion" erhält.
	# (PUT metadata)
	#  Lade Metadaten im Format toscience.json zu dem Objekt hoch
	#  ---> hier ist der rdf-Typ für Webschnitte noch unbekannt !
	# cat > "$REGAL_TMP/$id.json" <<ENDE
# {"rdftype":[{"prefLabel":"Archivierte Webseite ==> Webschnitt","@id":"http://purl.org/lobid/lv#ArchivedWebPage => WebpageVersion"}],"@id":"$id","id":"$BACKEND/resource/$id","title":["$Label"],"isDescribedBy":{"createdBy":"$userId"}}
# ENDE
	# echo "curl $curlopts --form \"data=@$REGAL_TMP/$id.json;type=application/json;charset=utf-8\" -XPUT \"$BACKEND/resource/$id/uploadUpdateMetadata\""
	# resultat=`curl $curlopts -u$ADMIN_USER:$ADMIN_PASSWORD --form "data=@$REGAL_TMP/$id.json;type=application/json;charset=utf-8" -XPUT "$BACKEND/resource/$id/uploadUpdateMetadata"`
	# echo $resultat
	# => den Endpoint uploadUpdateMetadata noch nicht benutzen, solange Metadaten noch aus dem Datenstrom metadata2 zur Anzeige kommen.


	# Wenn man den Endpoint /metadata2 benutzen wollte, müsste der Zeitstempel noch nach Label konvertieren werden.
	# Label ist im Format YYYY-mm-dd HH:MM:SS, und von gleicher Zeitzone wie $zeitstempel (lokale Zeit):
	# Label=...aus $zeitstempel...
	# Wir machen den Patch aber nicht über einen zusätzlichen PUT an /metadata2, sondern direkt in createWebpageVersion -> updateLobdify2AndEnrichMetadata. 
	# Da aber der rdf-Typ für Webschnitte noch undefiniert ist, patchen wir dort nur den Label (als Titel).
	# text_body="<$id> <http://www.w3.org/1999/02/22-rdf-syntax-ns#type> <http://purl.org/lobid/lv#ArchivedWebPage ==> WebpageVersion> .
# <$id> <http://purl.org/dc/terms/title> \"$Label\" ."
	# echo "curl $curlopts -XPUT -H \"Content-Type: text/plain; charset=utf-8; Accept: application/json\" --data-binary \"$text_body\" \"$BACKEND/resource/$id/metadata2\""; echo
	# resultat=`curl $curlopts -XPUT -u$REGAL_ADMIN:$REGAL_PASSWORD -H "Content-Type: text/plain; charset=utf-8; Accept: application/json" --data-binary "$text_body" "$BACKEND/resource/$id/metadata2"`
	# echo $resultat
	# echo

	cd $olddir
	if [ -n "$pid" ]; then
		pid=$(($pid+1))
	fi
	echo
	
done < $csv_datei.UTF-8
echo
echo "Script $0 terminating regularly."
echo

exit 0
