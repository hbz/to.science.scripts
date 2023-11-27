#!/bin/bash
# Autor: Ingolf Kuss, hbz
# Erstelldatum: 18.01.2023
# Dieses Skript macht einen einfachen "Touch" auf eine Liste von Ressourcen (toscience-Objekte).
# Dadurch werden z.B. noch nicht indexierte Ressourcen indexiert.
# Input: eine Liste mit Edoweb-IDs
# Aktionen : geht die Liste durch und macht für jedes Objekt einen minimalen Touch.

# Parameter auswerten
if [ $# -eq 0 ]; then
  echo "Bitte eine Liste übergeben !"
  exit 0
fi 
liste=$1
if [ ! -f $liste ]; then
  echo "($liste) ist keine Datei !"
  exit 0
fi

# bash-Funktionen
function stripOffQuotes {
  local string=$1;
  local len=${#string};
  echo ${string:1:$len-2};
}

# erwartet Eingabe
echo "Bitte auswählen:"
echo "Server: (1) edoweb-test2.hbz-nrw.de"
echo "        (2) edoweb-rlp.de"
unset server
while [ -z $server ]
do
  read server_id
  if [ $server_id -eq 1 ]; then
    server="edoweb-test2.hbz-nrw.de"
  elif [ $server_id -eq 2 ]; then
    server="edoweb-rlp.de"
  else
    echo "Falsche Eingabe! Bitte 1 oder 2 auswählen."
  fi
done
echo "Server: $server"

user="edoweb-admin"
echo "Server-User: $user"
unset password
read -p "Server-Passwort: " password

# los geht's (Hauptverarbeitung)
echo "Bearbeite Liste: $1"
for id in `cat $liste`
do
    echo "id=$id";
    curl -u$user:$password -XPATCH -d'{"@id":"'$id'"}' "https://api.$server/resource/$id" -H"Content-Type: application/json"
    echo ""
done

echo "Skript wird regulär beendet (fertig)."
exit 0
