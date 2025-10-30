#!/bin/bash
# Dieses Skript lädt eine Datei zu einer Ressource hoch.
# Autor: I. Kuss (hbz), 21.08.2025

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf
source funktionen.sh

usage() {
  cat <<EOF
  Dieses Skript lädt eine Datei zu einer Ressource hoch.
  Beispielaufruf: $0 -a 991001929849708976
  Optionen:
   - a [AlmaMmsId]   eine Alma-MmsId.
   - h               Hilfe (dieser Text)
EOF
  exit 0
  }

almaMmsId=""

# Auswertung der Optionen und Kommandozeilenparameter
OPTIND=1         # Reset in case getopts has been used previously in the shell.
while getopts "a:h?" opt; do
    case "$opt" in
    a)  almaMmsId=$OPTARG
        ;;
    h|\?) usage
        ;;
    esac
done
shift $((OPTIND-1))
[ "${1:-}" = "--" ] && shift

# if [ "$almaMmsId" = "" ]; then
#   echo "Bitte übergeben Sie dem Skript über den Schalter -a eine Alma-Mms-Id"
#   usage
# fi
echo "Create file object."

#*** Beginn Hauptverarbeitung ***#
  unset tosIdPdf
  accessScheme="private"; # Lies aus Tabelle !
  tosIdPdf=$(createFileObject "$accessScheme")
  echo "tosIdPdf=$tosIdPdf created!"
  pdfFile="B00286704.pdf" # Lies aus Datei !
  uploadFile $tosIdPdf $pdfFile
  echo " uploaded to $tosIdPdf."
  parentPid="hsl:1239" # Lies aus Datei !
  appendFileToParent $parentPid $tosIdPdf

# Lade Metadaten im Format toscience.json zu der Datei hoch (nur einen Titel)

  TITLE="Pflegeforschung verstehen: mit 15 Tabellen"; # Lies aus Datei !
  cat > $REGAL_TMP/$tosIdPdf.json <<ENDE
{"rdftype":[{"prefLabel":"Unterordnung","@id":"http://purl.org/ontology/bibo/DocumentPart"}],"@id":"$tosIdPdf","id":"$BACKEND/resource/$tosIdPdf","title":["$TITLE"]}
ENDE
  curl -u$ADMIN_USER:$ADMIN_PASSWORD --form "data=@$REGAL_TMP/$tosIdPdf.json;type=application/json;charset=utf-8" -XPUT "$BACKEND/resource/$tosIdPdf/uploadUpdateMetadata"; echo
  # hier kommt es zwar mit 200 zurück, hat aber keinerlei Metadaten angelegt. Message ist "nullnullnull".

# Lade Metadaten im Format NTRIPLES zu der Datei hoch (nur einen Titel)
  # Anhand von N-Triples: Das erzeugt sowohl einen toscience Datenstrom als auch metadata2. Letzterer wird (noch) zur Anzeige der Daten im Frontend benötigt.
  # Der Datenstrom toscience JSON scheint aber leer zu sein.
  ntriples="<$tosIdPdf> <http://purl.org/dc/terms/title> \"$TITLE\" ."
  curl -u$ADMIN_USER:$ADMIN_PASSWORD --data-binary "$ntriples" -H "Content-Type:text/plain;charset=utf-8" -XPUT "$BACKEND/resource/$tosIdPdf/metadata"
   
  # bei .json2 fehlt das Element "title", bei toscience ist es aber enthalten.

cd -
exit 0
