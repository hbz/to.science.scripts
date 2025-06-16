#!/bin/bash
# Dieses Skript führt einen Sync (Abgleich) aus, auf Webcrawling Error Logs in ~/crawlreports/logAnalyses
# vs. Logdateien in den Original-Verzeichnissen /data/wpull-data oder ~/wpull-data-crawldir
# Autor        | Datum      | Ticket      | Änderungsgrund
# -------------+------------+-----------------------------------------------------------
# Ingolf Kuss  | 12.06.2025 | TOSDEV-7    | Neuerstellung; auch für TOS-1295

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

# BEGINN Hauptverarbeitung
# 1. Logs in ~/wpull-data-crawldir
# (gescheiterte oder noch laufende Crawls)
for logdatei in `find ~/wpull-data-crawldir -name crawl.log`; do
	# echo "logdatei: $logdatei"
	relpath=`echo $(dirname $logdatei) | sed "s#^$HOME/wpull-data-crawldir/##"`
	mkdir -p ~/crawlreports/logAnalyses/$relpath
	grep ERROR $logdatei > ~/crawlreports/logAnalyses/$relpath/crawlerrors.log
done

# 2. Logs unter /data
# (erfolgreich beendete Crawls)
