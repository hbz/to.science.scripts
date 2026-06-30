#!/bin/bash
#  Dieses Skript migriert WebsiteVersions von einem Quellrechner zu einem Zielrechner.
#  Dabei kopiert es WARC-Archive von Quelle nach Ziel
#  und legt eine WebpageVersion für eine kopierte WARC-Datei auf dem Zielrechner an.
#  Als Konkordanz Quelle:Ziel wird eine Steuerdatei eingelesen.
#  Achtung ! Die URL in der aktuellen Conf (Webpage-Konfigurationsdatei) 
#    muss mit der URL zum Zeitpunkt des Einsammelns der WARC-Datei übereinstimmen.
#    Ansonsten kann die WARC-Datei evtl. von Wayback nicht gefunden werden.
#    Der Link unter "Zum Webschnitt" wird nämlich für die aktuelle URL erzeugt.
#    Ggfs. muss also vor Aufruf dieses Skripts die URL in der Conf and die URL
#    in der Quelle angepasst werden.
# 
#  @author Ingolf Kuss | 14.02.2025 | Neuanlage für Erstanlage der Webpages 
#                                     auf www.webarchiv.nrw (aion)

set -o nounset
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

usage() {
  cat <<EOF
  Dieses Skript migriert WebsiteVersions von einem Quellrechner zu einem Zielrechner.
  Dabei kopiert es WARC-Archive von Quelle nach Ziel
  und legt eine WebpageVersion für eine kopierte WARC-Datei auf dem Zielrechner an.
  Als Konkordanz Quelle:Ziel wird eine Steuerdatei eingelesen.
  Beispielaufrufe: ./ks.migrateWebsiteVersions.sh -f webpageMigration.MS.csv -r iphthime  >> ~/logs/ks.migrateWebisteVersions.MS.log
                   ./ks.migrateWebsiteVersions.sh -f webpageMigration.DUS.csv -r iphthime  >> ~/logs/ks.migrateWebisteVersions.DUS.log
                   ./ks.migrateWebsiteVersions.sh -f webpageMigration.BN.csv -r iphthime  >> ~/logs/ks.migrateWebisteVersions.BN.log

  Optionen:
   - d [dataDir]    Das lokal Datenhauptverzeichnis, unter dem die WARC-Dateien liegen. Standardwert: $localDataDir
   - f [filename]   Der Dateiname der Steuerdatei (Migrations-Datei). Diese wird im aktuellen Verzeichnis gesucht,
                    falls sie keine vollständige Pfadangabe (beginnend mit /) enthält.
                    Die Steuerdatei ist eine CSV-Datei mit den Tabellenspalten:
                    ^targetId;sourceId;timestamp;filename
                    Beispielwert: webpageMigration.csv, Standardwert: $filename
   - g              gesprächig (verbose), Standardwert: $verbose
   - h              Hilfe (dieser Text)
   - r [remoteServer] Der Name des entfernten Servers. Standartwert: $remoteServer
   - s              silent off (nicht still), Standardwert: $silent_off
   - t [remoteDir]  Das entferte Datenhauptverzeichnis, unter dem auf dem entfernten Server die WARC-Dateien liegen.
                    Standardwert: $remoteDataDir
   - v [versionPid] Die gewünschte erste Pid für die anzulegenden Webpage-Versionen (Webschnitte)
                    (numerisch, bis zu 7-stellig; ohne vorangestellten Namespace)
                    oder leer (versionPids werden vom System generiert).
                    Die versionPid wird von der gewünschten ersten Pid an hochgezählt.
                    Die Spalte versionPid in der Steuerdatei überschreibt allerdings - für diese Version - diesen Wert.
                    Standardwert: $firstVersionPid
EOF
  exit 0
  }

# Default-Werte
localDataDir=$ARCHIVE_HOME/wpull-data
filename=webpageMigration.csv
verbose=0
remoteServer=""
silent_off=0
remoteDataDir=$localDataDir
firstVersionPid=""

# Auswertung der Optionen und Kommandozeilenparameter
OPTIND=1         # Reset in case getopts has been used previously in the shell.
while getopts "d:f:gh?r:st:v:" opt; do
    case "$opt" in
    d)  localDataDir=$OPTARG
        ;;
    f)  filename=$OPTARG
        ;;
    g)  verbose=1
        ;;
    h|\?) usage
        ;;
    r)  remoteServer=$OPTARG
        ;;
    s)  silent_off=1
        ;;
    t)  remoteDataDir=$OPTARG
        ;;
    v)  firstVersionPid=$OPTARG
        ;;
    esac
done
shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

# Beginn der Hauptverarbeitung

echo "Migriere WebpageVersions von Quellrechner nach Zielrecher"
if [ -z "$remoteServer" ]; then
	echo "Bitte geben Sie den Namen eines entfernten Servers also Optionsargument für -r ein."
	exit 0
fi
echo "localDataDir: $localDataDir"
echo "filename: $filename"
echo "verbose: $verbose"
echo "remoteServer: $remoteServer"
echo "silent_off: $silent_off"
echo "remoteDataDir: $remoteDataDir"
echo "firstVersionPid: $firstVersionPid"
echo

curlopts=""
if [ $silent_off != 1 ]; then
  curlopts="$curlopts -s"
fi
if [ $verbose == 1 ]; then
  curlopts="$curlopts -g"
fi

# Liese Zeile für Zeile der Migrations-Datei
nextVersionPid=$firstVersionPid
while read zeile; do
	if [[ $zeile == ^* ]]; then
		# Kommentarzeile
		continue
	fi
	# Split lines at semicolon
        arr=($(echo $zeile | tr ";" "\n"))
	targetId=$(echo ${arr[0]})
	echo "targetId=$targetId"
	sourceId=$(echo ${arr[1]})
	echo "sourceId=$sourceId"
	timestamp=$(echo ${arr[2]})
	echo "timestamp=$timestamp"
	warcDatei=$(echo ${arr[3]})
	echo "warcDatei=$warcDatei"
	versionPid=""
        if [ ${#arr[@]} -gt 4 ]; then
                versionPid=$(echo ${arr[4]})
        fi
	echo "versionPid=$versionPid"
	# 1. Create local webpage dir
	mkdir -p $localDataDir/$targetId
	# 2. Copy warc folder from source server to local webpage dir
	scp -pr $USER@$remoteServer:$remoteDataDir/$sourceId/$timestamp $localDataDir/$targetId
	# 3. Create local webpage version
	if [ -n "$versionPid" ]; then
	  bash postWebpageVersion.sh $curlopts -p $targetId -t $timestamp -f $warcDatei -v $versionPid
	  if [ -z "$nextVersionPid" ]; then
        	nextVersionPid=$(($versionPid+1))
	  fi
	else
	  bash postWebpageVersion.sh $curlopts -p $targetId -t $timestamp -f $warcDatei -v $nextVersionPid
	  if [ -n "$nextVersionPid" ]; then
        	nextVersionPid=$(($nextVersionPid+1))
	  fi
	fi
done < $filename

echo "$0 terminating regularly."
cd -
exit 0 
