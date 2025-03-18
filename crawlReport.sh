#!/bin/bash
# Listest Plattenplatz auf, der von Webschnitten belegt wurde. 
# Inklusive "Beifang" (Logs, andere Verwaltungsdateien)
# für wöchentlichen oder täglichen Bericht
# Output-Format: CSV
# Autor        | Datum      | Ticket      | Änderungsgrund
# -------------+------------+-----------------------------------------------------------
# Ingolf Kuss  | 02.08.2018 | EDOZWO-849  | Neuerstellung
# Ingolf Kuss  | 26.10.2018 | EDOZWO-849  | Anzeige der Aleph-ID (HT-Nr) in den Berichten
# Ingolf Kuss  | 01.02.2021 | EDOZWO-1045 | Nur Crawls des laufenden Jahres auswerten, da der Report sonst zu lange läuft.
#              |            |             | Aktuell läuft der Report 21 - 27 Stunden lang für eine Auswertung aller Crawls,
#              |            |             | die jemals gelaufen sind. Das ist für einen täglichen Nachtlauf zu lange.

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

# bash-Funktionen
function stripOffQuotes {
  local string=$1;
  local len=${#string};
  echo ${string:1:$len-2};
}

reportDir=/opt/toscience/crawlreports
discUsageWebsites=$reportDir/$(hostname).discUsageWebsites.$(date +"%Y%m%d%H%M%S").csv
crawlReport=$reportDir/$(hostname).crawlReport.$(date +"%Y%m%d%H%M%S").csv
REGAL_TMP=/opt/toscience/tmp
if [ ! -d $REGAL_TMP ]; then mkdir $REGAL_TMP; fi
aktJahr=`date +"%Y"`
echo "*************************************************"
echo "BEGINN Crawl-Report" `date`
echo "*************************************************"
echo "schreibe nach csv-Dateien:"
echo "   $discUsageWebsites"
echo "   $crawlReport"
echo "^PID;KZ;URL;total_disc_usage [MB];Webschnitte;Crawl-Versuche;Crawler;Aleph-ID;" > $discUsageWebsites
echo "^PID;KZ;URL;Crawl-Start;Crawl-Status;Crawl-Dauer;Bytes eingesammelt;Anzahl URIs geholt;Geschwdgk. [KB/sec];disc_usage_warcs [MB];disc_usage_database [MB];disc_usage_logs [MB];Crawler;Aleph-ID;Fehlerursache;" > $crawlReport

# 1. für Heritrix-Crawls
# **********************
# Summen
sumHeritrixSites=0
sumHeritrixDiscSpace=0
sumHeritrixCrawls=0
heritrixData=/opt/toscience/heritrix-data
crawler=heritrix
echo "crawler=$crawler"
cd $heritrixData
# Schleife über PIDs
# ls Option -v : numerisch sortiert
for pid in `ls -dv $NAMESPACE:*`; do
  echo
  echo "pid=$pid"
  # Gibt es die PID überhaupt im Regal-Backend ? (fehlerhafte Crawls könnten dort gelöscht worden sein)
  # Falls ja, ermittle Aleph-ID zu der PID.
  hbzid="keine"
  status_code="unknown"
  title=""
  kennzeichen=""
  IFS=$'\n'
  for httpResponse in `curl -is -u $REGAL_ADMIN:$REGAL_PASSWORD "$BACKEND/resource/$pid.json"`; do
    # echo $httpResponse
    if [[ "$httpResponse" =~ ^HTTP(.*)\ ([0-9]{1,3})\ (.*)$ ]]; then
      status_code=${BASH_REMATCH[2]}
    fi
  done
  echo "statusCode: $status_code"
  # echo "httpResonse is now: $httpResponse"
  if [ $status_code == 404 ]; then
    echo "pid $pid existiert nicht."
  else
    # Alles OK mit der PID. Ermittle Aleph-ID zu der PID.
    hbzid=`echo $httpResponse | jq '.hbzId[0]'`
    if [ $hbzid ] && [ "$hbzid" != "null" ]; then
      hbzid=$(stripOffQuotes $hbzid)
    fi
    # Ermittle den Titel
    title=`echo $httpResponse | jq '.title[0]'`
    if [ -n "$title" ] && [ "$title" != "null" ]; then
      title=$(stripOffQuotes $title)
      if [ -n "$KENNZEICHEN" ]; then
        # Ermittle auch ein Kennzeichen im Titel
        OLDIFS=$IFS
        IFS=","
        read -ra array <<< "$KENNZEICHEN"
        for KZ in "${array[@]}"
        do
          if [[ "$title" =~ ^$KZ[:\ ] ]]; then
            kennzeichen=$KZ
	    break
	  fi
        done
        IFS=$OLDIFS
      fi
    fi
  fi
  echo "hbzid=$hbzid"
  echo "Titel=$title"
  echo "Kennzeichen=$kennzeichen"
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
  anz_success=`curl -XGET -u$ADMIN_USER:$ADMIN_PASSWORD -H"Content-type: application/json" "$BACKEND/resource/$pid.json2" | jq '.hasPart | length'`
  anz_attempts=0
  if [ -d latest ]; then
    # Schleife über alle Crawls zu dieser pid
    for crawldir in 20???????????? ; do
      if [ -d "$crawldir" ]; then
        anz_attempts=$(($anz_attempts+1))
        if [[ "$crawldir" =~ ^$aktJahr..........$ ]]; then 
          # Crawl im aktuellen Jahr, wird weiter ausgewertet
          echo "crawldir=$crawldir"
        else
          continue;
        fi
        inputdate=`echo $crawldir | sed 's/^\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\)$/\1 \2:\3:\4/'`
        crawlstart=`date -d "$inputdate" +'%FT%T'`
        echo "crawlstart=$crawlstart"
        cd $heritrixData/$pid/$crawldir
        # Auswertung der Informationen in reports/crawl-report.txt
        crawl_status=""
        error_cause=""
        duration=""
        uris_processed=""
        uri_successes=""
        total_crawled_bytes=""
        kb_sec=""
        if [ -f reports/crawl-report.txt ]; then
          crawl_status=`grep -m 1 "^crawl status" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          echo "crawl_status=$crawl_status"
          duration=`grep -m 1 "^duration" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          echo "Dauer=$duration"
          uris_processed=`grep -m 1 "^URIs processed" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          echo "uris_processed=$uris_processed"
          uri_successes=`grep -m 1 "^URI successes" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          echo "uri_successes=$uri_successes"
          uri_failures=`grep -m 1 "^URI failures" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          uri_disregards=`grep -m 1 "^URI disregards" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          novel_uris=`grep -m 1 "^novel URIs" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          total_crawled_bytes=`grep -m 1 "^total crawled bytes" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          echo "total_crawled_bytes=$total_crawled_bytes"
          novel_crawled_bytes=`grep -m 1 "^novel crawled bytes" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          uris_sec=`grep -m 1 "^URIs/sec" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
          kb_sec=`grep -m 1 "^KB/sec" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
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
        echo "$pid;$kennzeichen;$url;$crawlstart;$crawl_status;$duration;$total_crawled_bytes;$uri_successes;$kb_sec;$disc_usage_warcs;$disc_usage_database;$disc_usage_logs;$crawler;$hbzid;$error_cause;" >> $crawlReport
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
  echo "anz_attempts=$anz_attempts"
  sumHeritrixCrawls=$(($sumHeritrixCrawls+$anz_attempts))
  # Schreibe Zeile nach discUsageWebsites für diese PID
  if [ $anz_attempts -gt 0 ]; then
    echo "$pid;$kennzeichen;$url;$total_disc_usage;$anz_success;$anz_attempts;$crawler;$hbzid" >> $discUsageWebsites
  fi
done # next pid
sumHeritrixDiscSpace=`echo "scale=1; $sumHeritrixDiscSpace / 1024" | bc`

echo " "
echo "****************************************"
echo " "

# echo "^crawler;pid;url;total_disc_usage;anz_attempts;anz_success;" > $discUsageWebsites
# echo "^crawler;pid;url;crawlstart;crawl_status;error_cause;duration;uris_processed;uri_successes;total_crawled_bytes;speed [KB/sec];disc_usage_warcs;disc_usage_database;disc_usage_logs;" > $crawlReport
# 2. für wpull-Crawls
# *******************
sumWpullSites=0
sumWpullDiscSpace=0
sumWpullCrawls=0
wpullData=/opt/toscience/wpull-data
wpullDataCrawldir=/opt/toscience/wpull-data-crawldir
crawler=wpull
echo "crawler=$crawler"
cd $wpullData
# Schleife über PIDs
for pid in `ls -dv $NAMESPACE:*`; do
  echo
  echo "pid=$pid"
  # Gibt es die PID überhaupt im Regal-Backend ? (fehlerhafte Crawls könnten dort gelöscht worden sein)
  # Falls ja, ermittle Aleph-ID zu der PID.
  hbzid="keine"
  title=""
  kennzeichen=""
  status_code="unknown"
  IFS=$'\n'
  for httpResponse in `curl -is -u $REGAL_ADMIN:$REGAL_PASSWORD "$BACKEND/resource/$pid.json"`; do
    # echo $httpResponse
    if [[ "$httpResponse" =~ ^HTTP(.*)\ ([0-9]{1,3})\ (.*)$ ]]; then
      status_code=${BASH_REMATCH[2]}
    fi
  done
  echo "statusCode: $status_code"
  # echo "httpResonse is now: $httpResponse"
  if [ $status_code == 404 ]; then
    echo "pid $pid existiert nicht."
  else
    # Alles OK mit der PID. Ermittle Aleph-ID zu der PID.
    hbzid=`echo $httpResponse | jq '.hbzId[0]'`
    if [ $hbzid ] && [ "$hbzid" != "null" ]; then
      hbzid=$(stripOffQuotes $hbzid)
    fi
    # Ermittle den Titel
    title=`echo $httpResponse | jq '.title[0]'`
    if [ -n "$title" ] && [ "$title" != "null" ]; then
      title=$(stripOffQuotes $title)
      if [ -n "$KENNZEICHEN" ]; then
        # Ermittle auch ein Kennzeichen im Titel
        OLDIFS=$IFS
        IFS=","
        read -ra array <<< "$KENNZEICHEN"
        for KZ in "${array[@]}"
        do
          if [[ "$title" =~ ^$KZ[:\ ] ]]; then
            kennzeichen=$KZ
	    break
	  fi
        done
        IFS=$OLDIFS
      fi
    fi
  fi
  echo "hbzid=$hbzid"
  echo "Titel=$title"
  echo "Kennzeichen=$kennzeichen"
  sumWpullSites=$(($sumWpullSites+1))
  cd $wpullData/$pid
  url=""
  total_disc_usage=`du -ks . | sed 's/^\(.*\)\s.*$/\1/'`
  total_disc_usage=`echo "scale=0; $total_disc_usage / 1024" | bc`
  echo "total disc usage=$total_disc_usage MB"
  sumWpullDiscSpace=`echo "scale=0; $sumWpullDiscSpace + $total_disc_usage" | bc`
  anz_success=`curl -XGET -u$ADMIN_USER:$ADMIN_PASSWORD -H"Content-type: application/json" "$BACKEND/resource/$pid.json2" | jq '.hasPart | length'`
  anz_attempts=0
  # Schleife über alle Crawls zu dieser pid
  for crawldir in 20???????????? ; do
    if [ -d "$crawldir" ]; then
      anz_attempts=$(($anz_attempts+1))
      # Ermittlung der URL
      cd $wpullData/$pid/$crawldir
      for datei in WEB-*.warc.gz; do
        ## Check if the glob gets expanded to existing files.
        ## If not, datei here will be exactly the pattern above
        ## and the exists test will evaluate to false.
        if [ -e "$datei" ]; then
          # echo "files do exist"
          url_raw=`echo $datei | sed 's/^WEB\-\(.*\)\-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\.warc\.gz/\1/'`
          url=`echo $url_raw | sed 's/_cdn$//'`
          echo "url=$url"
        fi
        ## This is all we needed to know, so we can break after the first iteration
        break
      done
      if [[ "$crawldir" =~ ^$aktJahr..........$ ]]; then 
        # Crawl im aktuellen Jahr, wird weiter ausgewertet
        echo "crawldir=$crawldir"
      else
        cd $wpullData/$pid
        continue;
      fi
      inputdate=`echo $crawldir | sed 's/^\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\)$/\1 \2:\3:\4/'`
      crawlstart=`date -d "$inputdate" +'%FT%T'`
      echo "crawlstart=$crawlstart"
      crawl_status=""
      error_cause=""
      duration=""
      uris_processed=""
      uri_successes=""
      total_crawled_bytes=""
      kb_sec=""
      # Auswertung der Informationen in crawl.log
      if [ -f crawl.log -o -f "$wpullDataCrawldir/$pid/$crawldir/crawl.log" ]; then
        crawllog="crawl.log"
        if [ ! -f $crawllog ]; then
          crawllog="$wpullDataCrawldir/$pid/$crawldir/crawl.log"
        fi
        if grep --quiet "^INFO FINISHED." $crawllog ; then
          crawl_status="FINISHED"
          echo "crawl_status=$crawl_status"
        elif grep --quiet "^wpull3: error" $crawllog ; then
          crawl_status="ERROR"
          echo "crawl_status=$crawl_status"
          error_cause=`grep -m 1 "^wpull3: error" $crawllog | sed 's/^wpull3: error: \(.*\)$/\1/'`
          echo "error_cause=$error_cause"
        elif [ `stat --format=%Y $crawllog` -gt $(( `date +%s` - 3600 )) ]; then
          # crawl.log wurde in der letzten Stunde modifiziert
          crawl_status="RUNNING"
          echo "crawl_status=$crawl_status"
        else
          for datei in WEB-*.warc.gz; do
            ## Check if the glob gets expanded to existing files.
            ## If not, datei here will be exactly the pattern above
            ## and the exists test will evaluate to false.
            if [ -e "$datei" ]; then
              # echo "files do exist"
              if [ `stat --format=%Y $datei` -gt $(( `date +%s` - 3600 )) ]; then
                # warc-Datei wurde in der letzten Stunde modifiziert
                crawl_status="RUNNING"
                echo "crawl_status=$crawl_status"
              elif grep --quiet "^RuntimeError: Event loop stopped" $crawllog; then
                crawl_status="ABORTED"
                echo "crawl_status=$crawl_status"
              elif grep --quiet "^ERROR" $crawllog ; then
                crawl_status="ERROR"
                echo "crawl_status=$crawl_status"
                error_cause=`grep "^ERROR" $crawllog | tail -n1 | sed 's/^ERROR \(.*\)$/\1/'`
                echo "error_cause=$error_cause"
              fi
            else # Suche auch noch in wpull-data-crawldir, falls Datei noch nicht verschoben wurde
              for datei in $wpullDataCrawldir/$pid/$crawldir/WEB-*.warc.gz; do
                ## Check if the glob gets expanded to existing files.
                ## If not, datei here will be exactly the pattern above
                ## and the exists test will evaluate to false.
                if [ -e "$datei" ]; then
                  # echo "files do exist"
                  if [ `stat --format=%Y $datei` -gt $(( `date +%s` - 3600 )) ]; then
                    # warc-Datei wurde in der letzten Stunde modifiziert
                    crawl_status="RUNNING"
                    echo "crawl_status=$crawl_status"
                  elif grep --quiet "^RuntimeError: Event loop stopped" $crawllog; then
                    crawl_status="ABORTED"
                    echo "crawl_status=$crawl_status"
                  elif grep --quiet "^ERROR" $crawllog ; then
                    crawl_status="ERROR"
                    echo "crawl_status=$crawl_status"
                    error_cause=`grep "^ERROR" $crawllog | tail -n1 | sed 's/^ERROR \(.*\)$/\1/'`
                    echo "error_cause=$error_cause"
                  fi
                else # keine .warc-Datei vorhanden
                  crawl_status="ERROR"
                  echo "crawl_status=$crawl_status"
                  error_cause="No warc file or not matching the naming convention WEB-*.warc.gz"
                  echo "error_cause=$error_cause"
                fi
                ## This is all we needed to know, so we can break after the first iteration
                break
              done
            fi
            ## This is all we needed to know, so we can break after the first iteration
            break
          done
        fi
        duration=`grep -m 1 "^INFO Duration" $crawllog | sed 's/^.*: \(.*\). Speed: \(.*\)\.$/\1 h/'`
        echo "Dauer=$duration"
        speed=`grep -m 1 "^INFO Duration" $crawllog | sed 's/^.*: \(.*\). Speed: \(.*\)\.$/\2/'` # => kb_sec; "1.2 MiB/s", "30.8 KiB/s"
        echo "speed=$speed"
        kb_sec=$speed
        kb_sec=`echo $kb_sec | sed 's/^\(.*\) KiB\/s$/\1/'`
        # hier noch Umrechnung, falls speed in MiB/s angegeben ist
        files_downloaded=`grep -m 1 "^INFO Downloaded" $crawllog | sed 's/^.*: \(.*\) files, \(.*\)\.$/\1/'` # => uris_successes
        echo "files_downloaded=$files_downloaded"
        uri_successes=$files_downloaded
        bytes_downloaded=`grep -m 1 "^INFO Downloaded" $crawllog | sed 's/^.*: \(.*\) files, \(.*\)\.$/\2/'` # = total_crawled_bytes
        echo "bytes_downloaded=$bytes_downloaded"
        total_crawled_bytes=$bytes_downloaded
      else
        # keine Logdatei für den Crawl
        crawl_status="ERROR"
        echo "crawl_status=$crawl_status"
        error_cause="no crawl log"
        echo "error_cause=$error_cause"
      fi
      # von WARCs belegter Plattenplatz
      disc_usage_warcs=0
      for datei in *.warc.gz; do
        ## Check if the glob gets expanded to existing files.
        ## If not, datei here will be exactly the pattern above
        ## and the exists test will evaluate to false.
        if [ -e "$datei" ]; then
          # echo "files do exist"
          disc_usage_warcs=`du -ks $datei | sed 's/^\(.*\)\s.*$/\1/'`
          disc_usage_warcs=`echo "scale=0; $disc_usage_warcs / 1024" | bc`
        fi
        ## This is all we needed to know, so we can break after the first iteration
        break
      done
      echo "disc usage for warcs=$disc_usage_warcs"
      # belegter Plattenplatz eingesammeler Datenbankinhalte
      disc_usage_database=0
      for dbfile in *.db; do
        ## Check if the glob gets expanded to existing files.
        ## If not, f here will be exactly the pattern above
        ## and the exists test will evaluate to false.
        if [ -e "$dbfile" ]; then
          # echo "files do exist"
          disc_usage_dbfile=`du -ks $dbfile | sed 's/^\(.*\)\s.*$/\1/'`
          disc_usage_database=$((disc_usage_database + disc_usage_dbfile))
        fi
      done
      disc_usage_database=`echo "scale=0; $disc_usage_database / 1024" | bc`
      echo "disc usage for database contents=$disc_usage_database"
      # von Log-Dateien belegter Plattenplatz
      disc_usage_logs=0
      if [ -f crawl.log ]; then
        disc_usage_logs=`du -ks crawl.log | sed 's/^\(.*\)\s.*$/\1/'`
        disc_usage_logs=`echo "scale=0; $disc_usage_logs / 1024" | bc`
      fi
      echo "disc usage for logs=$disc_usage_logs"
      # *** Schreibe Zeile nach crawlReport für diesen Crawl***
      echo "$pid;$kennzeichen;$url;$crawlstart;$crawl_status;$duration;$total_crawled_bytes;$uri_successes;$kb_sec;$disc_usage_warcs;$disc_usage_database;$disc_usage_logs;$crawler;$hbzid;$error_cause;" >> $crawlReport
      cd $wpullData/$pid
      continue
    else
      echo "Es gibt keine Crawl-Verzeichnisse."
      break
    fi
  done
  if [ $anz_attempts -eq 0 ]; then
    # noch keine Crawls für diese pid vorhanden
    # *** Schreibe Zeile nach crawlReport für diese PID ***
    echo "no crawls yet" # kommt nie vor
    # echo "$crawler;$pid;$url;;;;;;;;;;;;" >> $crawlReport
  fi
  # Anzahl gestarteter Crawls zu dieser pid (inklusive Crawl-Versuche)
  echo "anz_attempts=$anz_attempts"
  # Schreibe Zeile nach discUsageWebsites für diese PID
  echo "$pid;$kennzeichen;$url;$total_disc_usage;$anz_success;$anz_attempts;$crawler;$hbzid" >> $discUsageWebsites
  sumWpullCrawls=$(($sumWpullCrawls+$anz_attempts))
done # next pid
sumWpullDiscSpace=`echo "scale=1; $sumWpullDiscSpace / 1024" | bc`

echo " "
echo "Summenwerte :"
echo "****************************************"
echo " "

echo "Summen;Anzahl Sites;;belegter Plattenplatz;Anzahl Crawl-Versuche;" >> $discUsageWebsites
echo "Anzahl Sites mit jemals für Heritrix eingeplanten Crawls: $sumHeritrixSites"
echo "Anzahl angestarteter Heritrix-Crawls im Jahre $aktJahr: $sumHeritrixCrawls"
echo "total disc usage for Heritrix Crawls: $sumHeritrixDiscSpace GB"
echo "Summe heritrix;$sumHeritrixSites Sites;;$sumHeritrixDiscSpace GB;$sumHeritrixCrawls;" >> $discUsageWebsites
echo "Anzahl Sites mit jemals für Wpull eingeplanten Crawls: $sumWpullSites"
echo "Anzahl angestarteter Wpull-Crawls im Jahre $aktJahr: $sumWpullCrawls"
echo "total disc usage for Wpull Crawls: $sumWpullDiscSpace GB"
echo "Summe wpull;$sumWpullSites Sites;;$sumWpullDiscSpace GB;$sumWpullCrawls;" >> $discUsageWebsites
spaceLeftOnDevice=0
nr_df_item=0
for item in `df -h | awk '/\/data$/ {print}'`; do
  nr_df_item=$(($nr_df_item+1))
  if [ $nr_df_item -eq 4 ]; then spaceLeftOnDevice=$item; fi
done
echo "Space left on device /data: $spaceLeftOnDevice"
echo "Space left on device /data;;;$spaceLeftOnDevice;;" >> $discUsageWebsites
echo "ENDE Crawl-Report" `date`
echo ""

# ********************************************************
# E-Mail verschicken mit den Links zu den beiden Berichten
# ********************************************************
baseUrl=https://www.$DOMAIN/crawlreports
mailbodydatei=$REGAL_TMP/mail_crawlReport.$$.out.txt
echo "******************************************" > $mailbodydatei
echo "$PROJECT Website Crawl Reports" >> $mailbodydatei
echo "******************************************" >> $mailbodydatei
aktdate=`date +"%d.%m.%Y %H:%M:%S"`
echo "Aktuelles Datum und Uhrzeit: $aktdate" >> $mailbodydatei
echo "Berichte für den Server: $SERVER" >> $mailbodydatei
echo "" >> $mailbodydatei
echo "Aktuelle Speicherplatzbelegung (Summen) durch Website-Crawls: $baseUrl/`basename $discUsageWebsites`" >> $mailbodydatei
echo "Aktuelle Status und Kennzahlen der einzelnen Crawl-Aufträge : $baseUrl/`basename $crawlReport`" >> $mailbodydatei

subject="$PROJECT Website Crawl Reports";
xheader="X-Edoweb: $(hostname) crawl reports";
recipients=$EMAIL_RECIPIENT_ADMIN_USERS;
OLDIFS=$IFS
IFS=" "
read -ra array <<< "$recipients"
for recipient in "${array[@]}"
do
  mailx -s "$subject" -a "$xheader" $recipient < $mailbodydatei
done
IFS=$OLDIFS
# rm $mailbodydatei

exit 0
