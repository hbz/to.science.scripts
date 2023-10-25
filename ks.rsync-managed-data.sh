#!/bin/bash
# Skript zum einmaligen Kopieren und täglichen Abgleich der gemanagten Daten
# von edoweb (alte Produktion) nach edoweb2 (neue Produktion)
# IK erstellt 14.09.2023
# ab 18.10.2023 mit sshpass
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
  rsync -ratlvz --delete --rsh="/usr/bin/sshpass -p $LEGACY_UNIX_PASSWORD ssh -o StrictHostKeyChecking=no -l $LEGACY_UNIX_USER" edoweb:/opt/regal/fedora/data/objectStore/ "/opt/toscience/fedora/data/objectStore/"

  rsync -ratlvz --delete --rsh="/usr/bin/sshpass -p $LEGACY_UNIX_PASSWORD ssh -o StrictHostKeyChecking=no -l $LEGACY_UNIX_USER" edoweb:/opt/regal/fedora/data/datastreamStore/ "/opt/toscience/fedora/data/datastreamStore/"

  exit 0
