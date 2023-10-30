#!/bin/bash
# Skript zum Backup/täglichen Abgleich der Webschnitt-Daten von /data2_old, /data_old => /data2

  # 1. Auf der 10 TB-Platte /data2_old (alte Produktion) gespeicherte Daten
  # (i.W. muss alles kopiert werden; wir machen es Verzeichnis für Verzeichnis:)
  quelle=/data2_old/wpull-data/
  ziel=/data2/wpull-data/
  #heute=$(date +%Y-%m-%d)

  #rsync -avR --delete "${quelle}"  "${ziel}${heute}/" --link-dest="${ziel}last/"
  #ln -nsf "${ziel}${heute}" "${ziel}last"
  rsync -avz "${quelle}" "${ziel}"
  rsync -avz "/data2_old/heritrix-data/" "/data2/heritrix-data/"
  rsync -avz "/data2_old/cdn-data/" "/data2/cdn-data/"
  rsync -avz "/data2_old/public-data/" "/data2/public-data/"

  # 2. Auf der 4 TB-Platte /data_old gespeicherte Webschnitte (wpull-data):
  rsync -avz "/data_old/edoweb/wpull-data/" "/data2/wpull-data/"
  # Bem.: Das sind im einzelnen folgende Websites:
  # /data2_old/wpull-data/edoweb:1127 -> /data/edoweb/wpull-data/edoweb:1127
  # /data2_old/wpull-data/edoweb:1192 -> /data/edoweb/wpull-data/edoweb:1192
  # /data2_old/wpull-data/edoweb:1415 -> /data/edoweb/wpull-data/edoweb:1415
  # /data2_old/wpull-data/edoweb:151 -> /data/edoweb/wpull-data/edoweb:151
  # /data2_old/wpull-data/edoweb:155 -> /data/edoweb/wpull-data/edoweb:155
  # /data2_old/wpull-data/edoweb:185 -> /data/edoweb/wpull-data/edoweb:185
  # /data2_old/wpull-data/edoweb:7004621 -> /data/edoweb/wpull-data/edoweb:7004621
  # /data2_old/wpull-data/edoweb:7009474 -> /data/edoweb/wpull-data/edoweb:7009474
  # /data2_old/wpull-data/edoweb:7012886 -> /data/edoweb/wpull-data/edoweb:7012886
  # /data2_old/wpull-data/edoweb:7022970 -> /data/edoweb/wpull-data/edoweb:7022970
  # /data2_old/wpull-data/edoweb:7024773 -> /data/edoweb/wpull-data/edoweb:7024773
  # /data2_old/wpull-data/edoweb:7037489 -> /data/edoweb/wpull-data/edoweb:7037489
  # /data2_old/wpull-data/edoweb:7041713 -> /data/edoweb/wpull-data/edoweb:7041713
  # /data2_old/wpull-data/edoweb:7041755 -> /data/edoweb/wpull-data/edoweb:7041755
  # /data2_old/wpull-data/edoweb:7029984 -> /data/edoweb/wpull-data/edoweb:7029984
  # /data2_old/wpull-data/edoweb:7042881 -> /data/edoweb/wpull-data/edoweb:7042881
  # 08.09.2023, 09:00 Uhr: die Daten von /data_old/edoweb/wpull-data sind komplett nach /data2/wpull-data/ übertragen worden.

  rsync -avz "/data_old/restrictedweb/" "/data2/restrictedweb/"
  rsync -avz "/data_old/webharvests/" "/data2/webharvests/"
  rsync -avz "/data_old/wget-data/" "/data2/wget-data/"
  rsync -avz "/data_old/alt-daten/" "/data2/alt-daten/"
  # von /data_old gelangen auf diese Weise auf die Platte /data2 folgende Volumina:
  #   1613381 MB  edoweb/
  #       629 MB  restrictedweb/  
  #    139564 MB  webharvests/
  #    114964 MB  wget-data/

  exit 0
