#!/bin/bash
# Dieses Skript prüft, ob wpull gerade auf der Maschine läuft, d.h. ob gerade ein Crawl läuft.
# Ist das der Fall, gibt das Skript 1 zurück (das ist dann ein "Veto").
# Läuft kein wpull-Crawl, wird 0 zurück gegeben.
# Für hbz-unattended-online-patching : 
# Aufruf in der crontab:
#   hbz-unattended-online-patching-sh --veto-check /opt/toscience/bin/veto-check-wpull-running.sh
# Autor        | Datum      | Ticket      | Änderungsgrund
# -------------+------------+-----------------------------------------------------------
# Ingolf Kuss  | 07.11.2024 | TOS-1168    | Neuerstellung

ps_out=`ps --no-headers -C wpull`
if [ "$ps_out" == "" ]; then
	RetCode=0
else
	RetCode=1
fi
# echo "ps_out=$ps_out"
# echo "RetCode=$RetCode"
exit $RetCode
