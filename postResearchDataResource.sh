#!/bin/bash
# Autor: I. Kuss, hbz
echo "POST Forschungsdaten Ressource nach Forschungsdaten-Hauptobjekt"
echo "  falls ein URL-Unterverzeichnis angegeben wird, wird eine Überordnung unterhalb des Forschungsdatenobjektes angelegt,"
echo "    soweit diese noch nicht existiert."
. variables.conf
# Vorgeschlagene Werte
pid_vorschlag=6402648
resourcePid_vorschlag=""
NAMESPACE=${NAMESPACE:=$INDEXNAME}
dateiname_vorschlag="Wetterdaten2020.tar.xz"

# Benutzereingaben
read -p "PID Forschungsdaten (übergeordnetes Objekt)              : ($pid_vorschlag) " pid
read -p "PID Ressource (Datei) (leer = wird automatisch vergeben) : ($resourcePid_vorschlag) " resourcePid
pid=${pid:=$pid_vorschlag}
dataDir_vorschlag="subPath"
read -p "URL-Unterverzeichnis (relative Pfadangabe unterhalb von $NAMESPACE:$pid) : ($dataDir_vorschlag) " dataDir
read -p "Dateiname (ohne Pfadangaben, mit Dateiendung)            : ($dateiname_vorschlag) " dateiname

# Eingabewert oder (wenn leer) Standards verwenden
resourcePid=${resourcePid:=$resourcePid_vorschlag}
dataDir=${dataDir:=$dataDir_vorschlag}
dateiname=${dateiname:=$dateiname_vorschlag}

# Ausgabe der verwendeten Werte
echo "*** Verwendete Werte :"
echo "PID Forschungsdaten = $pid"
echo "PID Ressource       = $resourcePid"
echo "Unterverzeichnis    = $dataDir"
echo "Dateiname           = $dateiname"

curl -XPOST -u$REGAL_ADMIN:$REGAL_PASSWORD "$BACKEND/resource/$NAMESPACE:$pid/postResearchData?collectionUrl=data&subPath=$dataDir&filename=$dateiname&resourcePid=$resourcePid" -H "UserId=resourceposter" -H "Content-Type: text/plain; charset=utf-8";
