#!/bin/bash
# Skript zum Holen/Abgleich der Apache-Logs von Produktion
# von edoweb2 (neue Produktion) nach hier (edoweb-test2)
# weil hier ein Matomo läuft, das vorübergehend als Stats-Server für Produktion dient,
# bis stats auf den Analytics-Server umgezogen ist.
# IK erstellt 31.10.2023
  scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  cd $scriptdir
  source variables.conf

  #heute=$(date +%Y-%m-%d)
  # rsync -avz "${quelle}" "${ziel}"
  # -r = rekursiv
  # -a = rekurisv, erhalte Berechtigungen etc.
  # -t = erhalte Änderungsdatum
  # -l = kopiere symbolische Verknüpfungen als symbolische Verknüpfungen
  # -v = gesprächig
  # -z = Daten kompressieren während des Transfers (für langsame Verbindungen)
  rsync -ratlvz --delete --rsh="/usr/bin/sshpass -p $PROD_UNIX_PASSWORD ssh -o StrictHostKeyChecking=no -l $PROD_UNIX_USER" edoweb2:/var/log/apache2/ "/var/log/apache2.prod/"

  exit 0
