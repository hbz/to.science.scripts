#!/bin/bash
# Autor: Ingolf Kuss
# Erstellt  : 09.02.2023 - Anhängen von Kindern an einen Parent
# Input 1: eine parentPid
# Input 2: eine Liste mit Edoweb-IDs, txt-Datei, für das (Wieder-)Anhängen an einen Parent. Dies ist üblicherweise der Inhalt des seq-Datenstroms (ohne die eckigen Klammern, ohne Kommata und nicht in Anführungsstrichen).
# Aktionen : geht die Liste durch und setzt für jeden Treffer der Liste die parentPid

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

# Parameter auswerten
if [ $# -lt 2 ]; then
  echo "Bitte eine ParentPid und eine Liste übergeben !"
  exit 0
fi 
parentPid=$1
liste=$2
if [ ! -f $liste ]; then
  echo "($liste) ist keine Datei !"
  exit 0
fi

# Los geht's (Hauptverarbeitung)
echo "Bearbeite Liste: $liste"
for id in `cat $liste`
do
    echo "id=$id";
    curl -u$ADMIN_USER:$ADMIN_PASSWORD -XPATCH -d'{"parentPid":"'$parentPid'"}' "$BACKEND/resource/$id" -H"Content-Type: application/json"
    echo ""
done

echo "Skript wird regulär beendet (fertig)."
exit 0
