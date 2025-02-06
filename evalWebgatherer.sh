#!/bin/bash
# Auswertung von Log-File webgatherer.log
#| Autor              | Datum      | Beschreibung
#+--------------------+------------+-----------------------------------------
#| I. Kuss            | 02.06.2016 | Neuerstellung
#| I. Kuss            | 12.01.2018 | Auslagerung von Systemvariablen
#+--------------------+------------+-----------------------------------------
#
# Der Pfad, in dem dieses Skript steht
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf
echo "AUSWERTUNG WEBGATHERER.log : "
LOG=$REGAL_APP/logs/webgatherer.log
echo "Anzahl gefundener   Sites: " `cat $LOG | grep -o "Found .* webpages"`
echo "Anzahl berabeiteter Sites: " `cat $LOG | grep -c "Precount: "`
echo "Websites, die jetzt eingesammelt werden sollen: Anzahl:" `cat $LOG | grep -c "Die Website soll jetzt eingesammelt werden\."`
echo "Davon nicht erfolgreich eingesammelt:"
echo "  - Site unbekannt verzogen.                    Anzahl:" `cat $LOG | grep -c "De Sick is unbekannt vertrocke !"`
echo "  - Site umgezogen (wartet auf Bestaetigung).   Anzahl:" `cat $LOG | grep -c "De Sick is umjetrocke noh"`
echo "  - Version konnte nicht angelegt werden.       Anzahl:" `cat $LOG | grep -c "Couldn't create webpage version for"`
echo "Davon erfolgreich eingesammelt:                 Anzahl:" `cat $LOG | grep -c "$NAMESPACE:.* webgatherer conf updated!"`
echo "nachrichtlich : Kein Host zur URL ! (wird irrtümlich als "erfolgreich gesammelt" gezaehlt): Anzahl:" `cat $LOG | grep -c "Kein Host zur URL !"`
echo "******* ENDE Zaehlsummen *******"
echo "Neu gestartete Crawls mit ID; Anzahl:" `cat $LOG | grep -c "Create new version for:.*"`
cat $LOG | grep -o "Create new version for:.*"
echo "Fehlermeldungen; Anzahl:" `cat $LOG | grep -c "ERROR"`
cat $LOG | grep "ERROR"
# echo "Demnächst anstehende Gatherläufe: Anzahl:" `cat $LOG | grep -c "will be launched next time at"`
# echo "Anstehende sortiert nach Zeitpunkt:"
# cat $LOG | grep -o "will be launched next time at.*" | sort
echo "ENDE AUSWERTUNG WEBGATHERER.log"
