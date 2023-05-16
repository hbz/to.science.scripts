#!/bin/bash
# Dieses Skript verschiebt Dateien aus dem wpull-Arbeitsverzeichnis in das wpull-Outputverzeichnis.
# Das Verschieben wird nur durchgeführt, wenn im Arbeitsverzeichnis keine WARC-Datei mehr liegt.
# Dass im Arbeitsverzeichnis keine WARC-Datei mehr liegt bedeutet, dass der Crawl beendet ist.
# Grundsätzlich werden alle Dateien aus dem Arbeitsverzeichnis verschoben. Das Arbeitsverzeichnis wird anschließend gelöscht.
# Typische Dateien, die von der Verschiebung betroffen sind, sind Log-Dateien (cdncrawl.log, cdnparse.log, cdn.txt, crawl.log) und die DB-Dateien (*.db).
# Autor : I. Kuss
# Datum : 05.03.2020
echo "*************************************************************"
echo "BEGINN move files from crawldir " `date`
echo "*************************************************************"
jobDir=/opt/toscience/wpull-data-crawldir
outDir=/opt/toscience/wpull-data
cd $jobDir
for crawldir in edoweb:*/20*/; do
  if [ ! -e "$crawldir" ]; then
    echo "Leeres Crawldir, nichts zu tun."
    echo
    exit 0
  fi
  break
done
for crawldir in `ls -d edoweb:*/20*/`; do
  echo "crawldir=$crawldir"
  cd $jobDir/$crawldir
  for warcfile in *.warc.gz; do
    if [ -e "$warcfile" ]; then
      # WARC-Datei existiert, nichts verschieben
      echo "WARC-Datei $warcfile existiert."
      echo "Crawl läuft noch oder ist abgebrochen."
      break
    fi
    # Dateien verschieben
    echo "Crawl wurde abgeschlossen. Dateien werden verschoben."
    mv * $outDir/$crawldir
    aktdirname=`basename $PWD`
    cd ..
    rmdir $aktdirname
    echo "Verzeichnis $PWD/$aktdirname wurde gelöscht."
    if [ -z "$(ls -A $PWD)" ]; then
      # aktuelles Verzeichnis ist leer
      aktdirname=`basename $PWD`
      cd ..
      rmdir $aktdirname
      echo "Verzeichnis $PWD/$aktdirname wurde gelöscht."
    fi
  done
done
echo "ENDE move files from crawldir " `date`
echo
exit 0
