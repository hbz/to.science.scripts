#!/bin/bash
# Listest Plattenplatz auf, der von Webschnitten belegt wurde. 
# Inklusive "Beifang" (Logs, andere Verwaltungsdateien)
# für wöchentlichen Bericht, der ans LBZ verschickt werden soll.
# Output-Format: CSV
# Autor        | Datum      | Ticket     | Änderungsgrund
# -------------+------------+-----------------------------------------------------------
# Ingolf Kuss  | 02.08.2018 | EDOZWO-849 | Neuerstellung
# Ingolf Kuss  | 26.10.2018 | EDOZWO-849 | Anzeige der Aleph-ID (HT-Nr) in den Berichten

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

# bash-Funktionen
function stripOffQuotes {
  local string=$1;
  local len=${#string};
  echo ${string:1:$len-2};
}

reportDir=/opt/regal/crawlreports
discUsageWebsites=$reportDir/$(hostname).discUsageWebsites.$(date +"%Y%m%d%H%M%S").csv
crawlReport=$reportDir/$(hostname).crawlReport.$(date +"%Y%m%d%H%M%S").csv
REGAL_TMP=/opt/regal/tmp
if [ ! -d $REGAL_TMP ]; then mkdir $REGAL_TMP; fi
echo "*************************************************"
echo "BEGINN Crawl-Report" `date`
echo "*************************************************"
echo "schreibe nach csv-Dateien:"
echo "   $discUsageWebsites"
echo "   $crawlReport"
echo "^crawler;pid;aleph-id;url;total_disc_usage [MB];anz_crawls;" > $discUsageWebsites
echo "^crawler;pid;aleph-id;url;crawlstart;crawl_status;error_cause;duration;uris_processed;uri_successes;total_crawled_bytes;speed [KB/sec];disc_usage_warcs [MB];disc_usage_database [MB];disc_usage_logs [MB];" > $crawlReport

# 1. für Heritrix-Crawls
# **********************
# Summen
sumHeritrixSites=0
sumHeritrixDiscSpace=0
sumHeritrixCrawls=0
heritrixData=/data2/heritrix-data
crawler=heritrix
echo "crawler=$crawler"
cd $heritrixData
# Schleife über PIDs
for pid in `ls -d edoweb:*`; do
  echo
  echo "pid=$pid"
  # Gibt es die PID überhaupt im Regal-Backend ? (fehlerhafte Crawls könnten dort gelöscht worden sein)
  # Falls ja, ermittle Aleph-ID zu der PID.
  hbzid="keine"
  status_code="unknown"
  status_code_line=`curl -Is -u $REGAL_ADMIN:$REGAL_PASSWORD "$BACKEND/resource/$pid.json" | head -1`
  # echo $status_code_line
  if [[ "$status_code_line" =~ ^HTTP(.*)\ ([0-9]{1,3})\ (.*)$ ]]; 
  then 
    status_code=${BASH_REMATCH[2]}
  else
    echo "Statuscode-Zeile ist nicht im erwarteten Format. Continuing anyway."
  fi
  if [ $status_code == 404 ]; then
    echo "pid $pid existiert nicht."
  else
    # Alles OK mit der PID. Ermittle Aleph-ID zu der PID.
    hbzid=`curl -s "$BACKEND/resource/$pid.json" | jq '.hbzId[0]'`
    if [ $hbzid ] && [ "$hbzid" != "null" ]; then
      hbzid=$(stripOffQuotes $hbzid)
    fi
  fi
  echo "hbzid=$hbzid"
  sumHeritrixSites=$(($sumHeritrixSites+1))
  cd $heritrixData/$pid
  # url zu der pid
  url=`grep "Edoweb crawl of" crawler-beans.cxml | sed 's/^.*Edoweb crawl of\(.*\)$/\1/'`
  echo "url=$url"
  # insgesamt von der pid verbrauchter Plattenplatz
  total_disc_usage=`du -ks . | sed 's/^\(.*\)\s.*$/\1/'`
  total_disc_usage=`echo "scale=0; $total_disc_usage / 1024" | bc`
  echo "total disc usage=$total_disc_usage MB"
  sumHeritrixDiscSpace=`echo "scale=0; $sumHeritrixDiscSpace + $total_disc_usage" | bc`
  anz_crawls=0
  if [ -d latest ]; then
    # Schleife über alle Crawls zu dieser pid
    for crawldir in 20???????????? ; do
      if [ -d "$crawldir" ]; then
        echo "crawldir=$crawldir"
        inputdate=`echo $crawldir | sed 's/^\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\)$/\1 \2:\3:\4/'`
        crawlstart=`date -d "$inputdate" +'%FT%T'`
        echo "crawlstart=$crawlstart"
        cd $heritrixData/$pid/$crawldir
        anz_crawls=$(($anz_crawls+1))
        # Auswertung der Informationen in reports/crawl-report.txt
        crawl_status=""
        error_cause=""
        duration=""
        uris_processed=""
        uri_successes=""
        total_crawled_bytes=""
        kb_sec=""
        if [ -f reports/crawl-report.txt ]; then
          crawl_status=`grep "^crawl status" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          echo "crawl_status=$crawl_status"
          duration=`grep "^duration" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          echo "Dauer=$duration"
          uris_processed=`grep "^URIs processed" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          echo "uris_processed=$uris_processed"
          uri_successes=`grep "^URI successes" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          echo "uri_successes=$uri_successes"
          uri_failures=`grep "^URI failures" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          uri_disregards=`grep "^URI disregards" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          novel_uris=`grep "^novel URIs" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          total_crawled_bytes=`grep "^total crawled bytes" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          echo "total_crawled_bytes=$total_crawled_bytes"
          novel_crawled_bytes=`grep "^novel crawled bytes" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          uris_sec=`grep "^URIs/sec" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          kb_sec=`grep "^KB/sec" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          echo "KB/sec=$kb_sec"
        else
          # kein reports-Verzeichnis
          if [ -f logs/crawl.log ]; then
            if [ `stat --format=%Y logs/crawl.log` -gt $(( `date +%s` - 3600 )) ]; then
              # crawl.log wurde in der letzten Stunde modifiziert
              crawl_status="RUNNING"
              echo "crawl_status=$crawl_status"
            fi
          fi
        fi
        # von WARCs belegter Plattenplatz
        disc_usage_warcs=0
        if [ -d warcs ]; then
          disc_usage_warcs=`du -ks warcs | sed 's/^\(.*\)\s.*$/\1/'`
          disc_usage_warcs=`echo "scale=0; $disc_usage_warcs / 1024" | bc`
          echo "disc usage for warcs=$disc_usage_warcs"
        fi
        disc_usage_database=0
        # von Log-Dateien belegter Plattenplatz
        disc_usage_logs=0
        if [ -d logs ]; then
          disc_usage_logs=`du -ks logs | sed 's/^\(.*\)\s.*$/\1/'`
          disc_usage_logs=`echo "scale=0; $disc_usage_logs / 1024" | bc`
          echo "disc usage for logs=$disc_usage_logs"
        fi
        # *** Schreibe Zeile nach crawlReport für diesen Crawl***
        echo "$crawler;$pid;$hbzid;$url;$crawlstart;$crawl_status;$error_cause;$duration;$uris_processed;$uri_successes;$total_crawled_bytes;$kb_sec;$disc_usage_warcs;$disc_usage_database;$disc_usage_logs;" >> $crawlReport
        cd $heritrixData/$pid
        continue
      else
        echo "Es gibt keine Crawl-Verzeichnisse."
        break
      fi
    done
  else
    # noch keine Crawls für diese pid vorhanden
    # *** Schreibe Zeile nach crawlReport für diese PID ***
    echo "no crawls yet"
    # echo "$crawler;$pid;$url;;;;;;;;;;;;" >> $crawlReport
  fi
  # Anzahl gestarteter Crawls zu dieser pid (inklusive Crawl-Versuche)
  echo "anz_crawls=$anz_crawls"
  sumHeritrixCrawls=$(($sumHeritrixCrawls+$anz_crawls))
  # Schreibe Zeile nach discUsageWebsites für diese PID
  echo "$crawler;$pid;$hbzid;$url;$total_disc_usage;$anz_crawls;" >> $discUsageWebsites
done # next pid
sumHeritrixDiscSpace=`echo "scale=1; $sumHeritrixDiscSpace / 1024" | bc`

echo " "
echo "****************************************"
echo " "

# echo "^crawler;pid;url;total_disc_usage;anz_crawls;" > $discUsageWebsites
# echo "^crawler;pid;url;crawlstart;crawl_status;error_cause;duration;uris_processed;uri_successes;total_crawled_bytes;speed [KB/sec];disc_usage_warcs;disc_usage_database;disc_usage_logs;" > $crawlReport
# 2. für wpull-Crawls
# *******************
sumWpullSites=0
sumWpullDiscSpace=0
sumWpullCrawls=0
wpullData=/data2/wpull-data
crawler=wpull
echo "crawler=$crawler"
cd $wpullData
# Schleife über PIDs
for pid in `ls -d edoweb:*`; do
  echo
  echo "pid=$pid"
  # Gibt es die PID überhaupt im Regal-Backend ? (fehlerhafte Crawls könnten dort gelöscht worden sein)
  # Falls ja, ermittle Aleph-ID zu der PID.
  hbzid="keine"
  status_code="unknown"
  status_code_line=`curl -Is -u $REGAL_ADMIN:$REGAL_PASSWORD "$BACKEND/resource/$pid.json" | head -1`
  # echo $status_code_line
  if [[ "$status_code_line" =~ ^HTTP(.*)\ ([0-9]{1,3})\ (.*)$ ]]; 
  then 
    status_code=${BASH_REMATCH[2]}
  else
    echo "Statuscode-Zeile ist nicht im erwarteten Format. Continuing anyway."
  fi
  if [ $status_code == 404 ]; then
    echo "pid $pid existiert nicht."
  else
    # Alles OK mit der PID. Ermittle Aleph-ID zu der PID.
    hbzid=`curl -s "$BACKEND/resource/$pid.json" | jq '.hbzId[0]'`
    if [ $hbzid ] && [ "$hbzid" != "null" ]; then
      hbzid=$(stripOffQuotes $hbzid)
    fi
  fi
  echo "hbzid=$hbzid"
  sumWpullSites=$(($sumWpullSites+1))
  cd $wpullData/$pid
  url=""
  total_disc_usage=`du -ks . | sed 's/^\(.*\)\s.*$/\1/'`
  total_disc_usage=`echo "scale=0; $total_disc_usage / 1024" | bc`
  echo "total disc usage=$total_disc_usage MB"
  sumWpullDiscSpace=`echo "scale=0; $sumWpullDiscSpace + $total_disc_usage" | bc`
  anz_crawls=0
  # Schleife über alle Crawls zu dieser pid
  for crawldir in 20???????????? ; do
    if [ -d "$crawldir" ]; then
      echo "crawldir=$crawldir"
      inputdate=`echo $crawldir | sed 's/^\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\)$/\1 \2:\3:\4/'`
      crawlstart=`date -d "$inputdate" +'%FT%T'`
      echo "crawlstart=$crawlstart"
      cd $wpullData/$pid/$crawldir
      anz_crawls=$(($anz_crawls+1))
      # url
      if [ -f WEB-*.warc.gz ]; then
        url=`ls WEB-*.warc.gz | sed 's/^WEB\-\(.*\)\-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\.warc\.gz/\1/'`
        echo "url=$url"
      fi
      crawl_status=""
      error_cause=""
      duration=""
      uris_processed=""
      uri_successes=""
      total_crawled_bytes=""
      kb_sec=""
      # Auswertung der Informationen in crawl.log
      if [ -f crawl.log ]; then
        if grep --quiet "^INFO FINISHED." crawl.log ; then
          crawl_status="FINISHED"
          echo "crawl_status=$crawl_status"
        elif grep --quiet "^wpull3: error" crawl.log ; then
          crawl_status="ERROR"
          echo "crawl_status=$crawl_status"
          error_cause=`grep "^wpull3: error" crawl.log | sed 's/^wpull3: error: \(.*\)$/\1/'`
          echo "error_cause=$error_cause"
        elif [ `stat --format=%Y crawl.log` -gt $(( `date +%s` - 3600 )) ]; then
          # crawl.log wurde in der letzten Stunde modifiziert
          crawl_status="RUNNING"
          echo "crawl_status=$crawl_status"
        else
          if [ -f WEB-*.warc.gz ]; then 
            if [ `stat --format=%Y WEB-*.warc.gz` -gt $(( `date +%s` - 3600 )) ]; then
              # warc-Datei wurde in der letzten Stunde modifiziert
              crawl_status="RUNNING"
              echo "crawl_status=$crawl_status"
            elif grep --quiet "^RuntimeError: Event loop stopped" crawl.log; then
              crawl_status="ABORTED"
              echo "crawl_status=$crawl_status"
            elif grep --quiet "^ERROR" crawl.log ; then
              crawl_status="ERROR"
              echo "crawl_status=$crawl_status"
              error_cause=`grep "^ERROR" crawl.log | tail -n1 | sed 's/^ERROR \(.*\)$/\1/'`
              echo "error_cause=$error_cause"
            fi
          else # keine .warc-Datei vorhanden
            crawl_status="ERROR"
            echo "crawl_status=$crawl_status"
            error_cause="No warc file or not matching the naming convention WEB-*.warc.gz"
            echo "error_cause=$error_cause"
          fi
        fi
        duration=`grep "^INFO Duration" crawl.log | sed 's/^.*: \(.*\). Speed: \(.*\)\.$/\1 h/'`
        echo "Dauer=$duration"
        speed=`grep "^INFO Duration" crawl.log | sed 's/^.*: \(.*\). Speed: \(.*\)\.$/\2/'` # => kb_sec; "1.2 MiB/s", "30.8 KiB/s"
        echo "speed=$speed"
        kb_sec=$speed
        kb_sec=`echo $kb_sec | sed 's/^\(.*\) KiB\/s$/\1/'`
        # hier noch Umrechnung, falls speed in MiB/s angegeben ist
        files_downloaded=`grep "^INFO Downloaded" crawl.log | sed 's/^.*: \(.*\) files, \(.*\)\.$/\1/'` # => uris_successes
        echo "files_downloaded=$files_downloaded"
        uri_successes=$files_downloaded
        bytes_downloaded=`grep "^INFO Downloaded" crawl.log | sed 's/^.*: \(.*\) files, \(.*\)\.$/\2/'` # = total_crawled_bytes
        echo "bytes_downloaded=$bytes_downloaded"
        total_crawled_bytes=$bytes_downloaded
      else
        crawl_status="ERROR"
        echo "crawl_status=$crawl_status"
        error_cause="no crawl log"
        echo "error_cause=$error_cause"
      fi
      # von WARCs belegter Plattenplatz
      disc_usage_warcs=0
      if [ -f *.warc.gz ]; then
        disc_usage_warcs=`du -ks *.warc.gz | sed 's/^\(.*\)\s.*$/\1/'`
        disc_usage_warcs=`echo "scale=0; $disc_usage_warcs / 1024" | bc`
      fi
      echo "disc usage for warcs=$disc_usage_warcs"
      # belegter Plattenplatz eingesammeler Datenbankinhalte
      disc_usage_database=0
      for dbfile in *.db; do
        ## Check if the glob gets expanded to existing files.
        ## If not, f here will be exactly the pattern above
        ## and the exists test will evaluate to false.
        if [ -e "$dbfile" ]; then
          # echo "files do exist"
          disc_usage_database=`cat *.db > /tmp/$$.db; du -ks /tmp/$$.db | sed 's/^\(.*\)\s.*$/\1/'`
          rm /tmp/$$.db
          disc_usage_database=`echo "scale=0; $disc_usage_database / 1024" | bc`
        fi
        ## This is all we needed to know, so we can break after the first iteration
        break
      done
      echo "disc usage for database contents=$disc_usage_database"
      # von Log-Dateien belegter Plattenplatz
      disc_usage_logs=0
      if [ -f crawl.log ]; then
        disc_usage_logs=`du -ks *.log | sed 's/^\(.*\)\s.*$/\1/'`
        disc_usage_logs=`echo "scale=0; $disc_usage_logs / 1024" | bc`
      fi
      echo "disc usage for logs=$disc_usage_logs"
      # *** Schreibe Zeile nach crawlReport für diesen Crawl***
      echo "$crawler;$pid;$hbzid;$url;$crawlstart;$crawl_status;$error_cause;$duration;$uris_processed;$uri_successes;$total_crawled_bytes;$kb_sec;$disc_usage_warcs;$disc_usage_database;$disc_usage_logs;" >> $crawlReport
      cd $wpullData/$pid
      continue
    else
      echo "Es gibt keine Crawl-Verzeichnisse."
      break
    fi
  done
  if [ $anz_crawls -eq 0 ]; then
    # noch keine Crawls für diese pid vorhanden
    # *** Schreibe Zeile nach crawlReport für diese PID ***
    echo "no crawls yet" # kommt nie vor
    # echo "$crawler;$pid;$url;;;;;;;;;;;;" >> $crawlReport
  fi
  # Anzahl gestarteter Crawls zu dieser pid (inklusive Crawl-Versuche)
  echo "anz_crawls=$anz_crawls"
  # Schreibe Zeile nach discUsageWebsites für diese PID
  echo "$crawler;$pid;$hbzid;$url;$total_disc_usage;$anz_crawls;" >> $discUsageWebsites
  sumWpullCrawls=$(($sumWpullCrawls+$anz_crawls))
done # next pid
sumWpullDiscSpace=`echo "scale=1; $sumWpullDiscSpace / 1024" | bc`

echo " "
echo "Summenwerte :"
echo "****************************************"
echo " "

echo "Anzahl Sites mit für Heritrix eingeplanten Crawls: $sumHeritrixSites"
echo "Anzahl angestarteter Heritrix-Crawls: $sumHeritrixCrawls"
echo "total disc usage for Heritrix Crawls: $sumHeritrixDiscSpace GB"
echo "Summe heritrix;$sumHeritrixSites Sites;;$sumHeritrixDiscSpace GB;$sumHeritrixCrawls;" >> $discUsageWebsites
echo "Anzahl Sites mit für Wpull eingeplanten Crawls: $sumWpullSites"
echo "Anzahl angestarteter Wpull-Crawls: $sumWpullCrawls"
echo "total disc usage for Wpull Crawls: $sumWpullDiscSpace GB"
echo "Summe wpull;$sumWpullSites Sites;;$sumWpullDiscSpace GB;$sumWpullCrawls;" >> $discUsageWebsites
spaceLeftOnDevice=0
nr_df_item=0
for item in `df -h | awk '/\/data2$/ {print}'`; do
  nr_df_item=$(($nr_df_item+1))
  if [ $nr_df_item -eq 4 ]; then spaceLeftOnDevice=$item; fi
done
echo "Space left on device /data2: $spaceLeftOnDevice"
echo "Space left on device /data2;;;$spaceLeftOnDevice;;" >> $discUsageWebsites
echo "ENDE Crawl-Report" `date`
echo ""

# ********************************************************
# E-Mail verschicken mit den Links zu den beiden Berichten
# ********************************************************
baseUrl=https://www.$SERVER/crawlreports
mailbodydatei=$REGAL_TMP/mail_crawlReport.$$.out.txt
echo "******************************************" > $mailbodydatei
echo "hbz edoweb Website Crawl Reports" >> $mailbodydatei
echo "******************************************" >> $mailbodydatei
aktdate=`date +"%d.%m.%Y %H:%M:%S"`
echo "Aktuelles Datum und Uhrzeit: $aktdate" >> $mailbodydatei
echo "Berichte für den Server: $SERVER" >> $mailbodydatei
echo "" >> $mailbodydatei
echo "Aktuelle Speicherplatzbelegung (Summen) durch Website-Crawls: $baseUrl/`basename $discUsageWebsites`" >> $mailbodydatei
echo "Aktuelle Status und Kennzahlen der einzelnen Crawl-Aufträge : $baseUrl/`basename $crawlReport`" >> $mailbodydatei

subject="edoweb Website Crawl Reports"
xheader="X-Edoweb: $(hostname) crawl reports"
recipients=$EMAIL_RECIPIENT_PROJECT_ADMIN
mailx -s "$subject" -a "$xheader" $recipients < $mailbodydatei
# rm $mailbodydatei

exit 0
