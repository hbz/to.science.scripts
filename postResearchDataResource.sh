#!/bin/bash
# Autor: I. Kuss, hbz
echo "POST Forschungsdaten Ressource (Datei) nach Forschungsdaten-Hauptobjekt"
. variables.conf
# Vorgeschlagene Werte
pid_vorschlag=6402617
resourcePid_vorschlag=""
dataBasedir_vorschlag=${RDM_RESOURCES:=/opt/ellinet_repo/resources}
NAMESPACE=${NAMESPACE:=$INDEXNAME}
dateiname_vorschlag="Figures.tar.gz"

# Benutzereingaben
read -p "PID Forschungsdaten (übergeordnetes Objekt)              : ($pid_vorschlag) " pid
read -p "PID Ressource (Datei) (leer = wird automatisch vergeben) : ($resourcePid_vorschlag) " resourcePid
read -p "Hauptverzeichnis für RDM-Ressourcen (ein absoluter Pfad) : ($dataBasedir_vorschlag) " dataBasedir
pid=${pid:=$pid_vorschlag}
dataDir_vorschlag="$NAMESPACE:$pid"
read -p "Unterverzeichnis (relative Pfadangabe unter Hauptverz.)  : ($dataDir_vorschlag) " dataDir
read -p "Dateiname (ohne Pfadangaben, mit Dateiendung)            : ($dateiname_vorschlag) " dateiname

# Eingabewert oder (wenn leer) Standards verwenden
resourcePid=${resourcePid:=$resourcePid_vorschlag}
dataBasedir=${dataBasedir:=$dataBasedir_vorschlag}
dataDir=${dataDir:=$dataDir_vorschlag}
dateiname=${dateiname:=$dateiname_vorschlag}

# Ausgabe der verwendeten Werte
echo "*** Verwendete Werte :"
echo "PID Forschungsdaten = $pid"
echo "PID Ressource       = $resourcePid"
echo "Hauptverzeichnis    = $dataBasedir"
echo "Unterverzeichnis    = $dataDir"
echo "Dateiname           = $dateiname"

curl -XPOST -u$REGAL_ADMIN:$REGAL_PASSWORD "$BACKEND/resource/$NAMESPACE:$pid/postResearchDataResource?resourcePid=$resourcePid&dataDir=$dataBasedir/$dataDir&filename=$dateiname" -H "UserId=resourceposter" -H "Content-Type: text/plain; charset=utf-8";
