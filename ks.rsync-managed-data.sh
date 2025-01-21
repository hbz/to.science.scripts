#!/bin/bash
# Skript zum einmaligen Kopieren und täglichen Abgleich der gemanagten Daten
# von ellinet (alte Produktion) nach frl (neue Produktion)
# IK erstellt 14.09.2023 für edoweb => edoweb2
# ab 18.10.2023 mit sshpass
# 28.08.2024 angepasst für ellinet => frl
# 20.11.2024 erneut angepasst für frl ; rsync-Optionen von Peter ; ohne Passwörter --> ssh-Schlüssel in ~/.ssh
  scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
  # cd $scriptdir
  # source variables.conf

  #heute=$(date +%Y-%m-%d)
  # rsync -avz "${quelle}" "${ziel}"
  # -r = rekursiv
  # -a = rekurisv, erhalte Berechtigungen etc. / Archivierungsmodus
  # -t = erhalte Änderungsdatum
  # -l = kopiere symbolische Verknüpfungen als symbolische Verknüpfungen
  # -v = gesprächig
  # -z = Daten kompressieren während des Transfers (für langsame Verbindungen)
  rsync -av --stats -e ssh --delete "edoweb@ellinet:/opt/regal/fedora/data/objectStore/" "/opt/toscience/fedora/data/objectStore/"
  rsync -av --stats -e ssh --delete "edoweb@ellinet:/opt/regal/fedora/data/datastreamStore/" "/opt/toscience/fedora/data/datastreamStore/"

  exit 0
