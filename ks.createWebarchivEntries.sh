#!/bin/bash
# Autor: Dr. Ingolf Kuss, hbz
# Erstellungsdatum: 17.01.2025
# Beschreibung: Erstellt Webarchivierungs-Datensätze (Webpages) anhand einer CSV-Datei
# Für TOS-1178 und TOS-1177 : Webarchivierung NRW ULBs, 800er-Listen
source funktionen.sh

usage() {
  cat <<EOF
  Erstellt Webarchivierungs-Datensätze (Webpages) anhand einer CSV-Datei
  Die CSV-Datei enthät: TITEL;ERSCHEINUNGSORT;URL;INTERVALL(optional)
  Beispielaufruf:        ./ks.createWebarchivEntries.sh -l BN -f 4 -t 6 -i ../src/ULB_BN_Website-Archivierung_800_20241212.CSV  -- legt 3 Webpages an

  Optionen:
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
while getopts "f:h?i:l:st:v" opt; do
    case "$opt" in
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
while read zeile; do
        n=$(($n+1))
	if [ $n -lt $von ]; then
		continue
	fi
	if [ $bis -gt 0 ] && [ $n -gt $bis ]; then
		continue
	fi
	printf "Zeile Nr. $n\n"
	# Split lines at semicolon
	## Mask spaces by <
	zeile_maskiert=$(echo $zeile | tr " " "<")
	arr=($(echo $zeile_maskiert | tr ";" "\n"))
	Titel=$(echo ${arr[0]} | tr "<" " ")
	URL=$(echo ${arr[2]} | tr "<" " ")
	Intervall=$(echo ${arr[3]} | tr "<" " ")
	echo "Titel: $Titel"
	echo "URL: $URL"
	echo "Intervall: $Intervall"

	# Jetzt eine Webpage anlegen
	./createWebpage.sh $curlopts "$Titel" "$URL" "$Intervall"
	echo
	
done < $csv_datei.UTF-8

exit 0
