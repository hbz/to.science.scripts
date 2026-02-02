#!/bin/bash
# Autor: Dr. Ingolf Kuss, hbz
# Erstellungsdatum: 17.01.2025
# Beschreibung: Erstellt Webarchivierungs-Datensätze (Webpages) anhand einer CSV-Datei
# Für TOS-1178 und TOS-1177 : Webarchivierung NRW ULBs, 800er-Listen
# Änderungshistorie
# +------------------------------+----------------------------------------------------------------------------------------
# | Bearbeiter      | Datum      | Grund
# +------------------------------+----------------------------------------------------------------------------------------
# | Ingolf Kuss     | 17.01.2025 | Neuanlage
# | Ingolf Kuss     | 10.02.2025 | Parameter PID (von - bis) hinzugefügt
# | Ingolf Kuss     | 16.01.2026 | Verwendung für die zweite Lieferung von 800er-Listen, TOS-1337 - TOS-1339
# +------------------------------+----------------------------------------------------------------------------------------
set -o nounset
source funktionen.sh

usage() {
  cat <<EOF
  Erstellt Webarchivierungs-Datensätze (Webpages) anhand einer CSV-Datei
  Die CSV-Datei enthät: TITEL;ERSCHEINUNGSORT;URL;INTERVALL(optional)
  Beispielaufrufe:       ./ks.createWebarchivEntries.sh -l MS -f 4 -t 203 -b 10001 -i ../src/ULB_MS_Website-Archivierung_800_2024-1.CSV  > ../logs/ks.createWebarchivEntries.ULB_MS_4-203.log 
                           -- legt 197 Webpages im Namensraum 10001 bis 10197 an
                         ./ks.createWebarchivEntries.sh -l MS -f 204 -t 818 -b 10198 -i ../src/ULB_MS_Website-Archivierung_800_2024-1.CSV  > ../logs/ks.createWebarchivEntries.ULB_MS_204-818.log 
                         ./ks.createWebarchivEntries.sh -l DUS -f 3 -t 202 -b 20001 -i ../src/ULBDUS_Webarchivierung_800.CSV > ../logs/ks.createWebarchivEntries.ULB_DUS_3-202.log
                         ./ks.createWebarchivEntries.sh -l DUS -f 203 -t 802 -b 20201 -i ../src/ULBDUS_Webarchivierung_800.CSV > ../logs/ks.createWebarchivEntries.ULB_DUS_203-802.log
                         ./ks.createWebarchivEntries.sh -l BN -f 3 -t 202 -b 30001 -i ../src/ULB_BN_Website-Archivierung_800_20241212.CSV > ../logs/ks.createWebarchivEntries.ULB_BN_3-202.log
                         ./ks.createWebarchivEntries.sh -l BN -f 203 -t 802 -b 30201 -i ../src/ULB_BN_Website-Archivierung_800_20241212.CSV > ../logs/ks.createWebarchivEntries.ULB_BN_203-802.log

  Optionen:
   - b [PID]         Beginn-PID; erste PID, die angelegt werden soll. Zählt dann hoch. Standard: leer (=> PID wird zufällig vergeben)
   - f [von]         von; erste zu bearbeitende Zeile der CSV-Datei, Standard: $von
   - h               Hilfe (dieser Text)
   - i [Input-Datei] Webarchiv-Daten im CSV-Format, Dateiname. Default: $csv_datei
   - l [Bib-Kürzel]  Landesbibliotheks-Kürzel (MS, BN, DUS), Standardwert: $lb
   - s               silent off (nicht still), Standardwert: $silent_off
   - t [bis]         bis; letzte zu bearbeitende Zeile der CSV-Datei. Setze auf 0 oder -1 für "alle". Standard: $bis
   - v               verbose (gesprächig), Standardwert: $verbose
EOF
  exit 0
  }

# Default-Werte
beginnPid=""
von=4
csv_datei="/opt/toscience/src/ULB_BN_Website-Archivierung_800_20241212.CSV"
lb="BN"
silent_off=0
bis=6
verbose=0
cd ~/bin
source variables.conf

# Auswertung der Optionen und Kommandozeilenparameter
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

# Beginn der Hauptverarbeitung
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


echo "BACKEND=$BACKEND"
echo "Lege Webpages an anhand von Datei: $csv_datei"
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

# Lies die Input-Datei Zeile für Zeile ein
n=0
pid=$beginnPid
while read zeile; do
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
	#	# Düsseldorf lieferte Bibliothekskürzel und Site-Name getrennt in den ersten beiden Spalten
	#	Titel=$(echo ${arr[0]} | tr "<" " ")": "$(echo ${arr[1]} | tr "<" " ")
	#	URL=$(echo ${arr[3]} | tr "<" " ")
	#	Intervall=$(echo ${arr[4]} | tr "<" " ")
        Titel=$(echo ${arr[0]} | tr "<" " ")
        URL=$(echo ${arr[2]} | tr "<" " ")
        Intervall=$(echo ${arr[3]} | tr "<" " ")
        # subDomainKZ=$(echo ${arr[4]} | tr "<" " ")  # "X" falls mit Subdomains
        if [ "$lb" = "BN" ]; then
          crawlSubdomains=false
        else
          crawlSubdomains=true
        fi
	echo "Titel: $Titel"
	echo "URL: $URL"
	echo "Intervall: $Intervall"
	# if [ -n "$subDomainKZ" ]; then
	#	echo "subDomainKZ: $subDomainKZ"
	# fi
	echo "crawlSubdomains: $crawlSubdomains"
	if [ -n "$pid" ]; then
		echo "PID: $pid"
	fi

	# Jetzt eine Webpage anlegen
	./createWebpage.sh $curlopts "$Titel" "$URL" "$Intervall" "$pid" "$crawlSubdomains"
	if [ -n "$pid" ]; then
		pid=$(($pid+1))
	fi
	echo
	
done < $csv_datei.UTF-8

exit 0
