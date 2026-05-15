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
# Ingolf Kuss  | 23.01.2026 | TOSDEV-32   | Ermittle das Kennzeichen "Data-Provider" aus dem Nummernkreis, Erfasser oder aus Letzter Bearbeiter
# Ingolf Kuss  | 04.05.2026 | TOSDEV-23   | Vereinheitlichung für Heritrix-, wpull- und Browsertrix-Crawls

source funktionen.sh
source btrix_functions.sh
scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

#[ bash-Funktionen
function stripOffQuotes {
  local string=$1;
  local len=${#string};
  echo ${string:1:$len-2};
}

function ermittleKennzeichen {
  local kennzeichen=""
  nummer=0
  createdBy=""
  lastModifiedBy=""
  # Ermittle das Kennzeichen "Data-Provider"
  if [[ "$pid" =~ ^$NAMESPACE:([0-9]+)$ ]]; then
    nummer=${BASH_REMATCH[1]}
    # echo "nummer=$nummer"
  fi
  # Ermittle das Kennzeichen "Data-Provider" anhand des Nummernkreises
  OLDIFS=$IFS
  IFS=","
  read -ra array <<< "$NUMMERNKREISE"
  for NUMMERNKREIS in "${array[@]}"
  do
    KENNZEICH=`echo  $NUMMERNKREIS | sed 's/^\([^\:]*\):\([0-9]*\)-\([0-9]*\)$/\1/'`
    NUMBER_LOW=`echo $NUMMERNKREIS  | sed 's/^\([^\:]*\):\([0-9]*\)-\([0-9]*\)$/\2/'`
    NUMBER_HIGH=`echo $NUMMERNKREIS | sed 's/^\([^\:]*\):\([0-9]*\)-\([0-9]*\)$/\3/'`
    if [ $nummer -ge $NUMBER_LOW ] && [ $nummer -lt $NUMBER_HIGH ]; then
      kennzeichen=$KENNZEICH
      break
    fi
  done
  IFS=$OLDIFS
  if [ "$kennzeichen" = "" ]; then
    createdBy=`echo $httpResponse | jq '.isDescribedBy.createdBy'`
    if [ $createdBy ] && [ "$createdBy" != "null" ]; then
      # Ermittle das Kennzeichen anhand des Erfassers
      createdBy=$(stripOffQuotes $createdBy)
      # echo "createdBy=$createdBy"
      kennzeichen=$(ermittleKennzeichenAnhandUserid $createdBy)
    fi
    if [ "$kennzeichen" = "" ]; then
      lastModifiedBy=`echo $httpResponse | jq '.isDescribedBy.lastModifiedBy'`
      if [ $lastModifiedBy ] && [ "$lastModifiedBy" != "null" ]; then
        # Ermittle das Kennzeichen anhand des Letzten Bearbeiters
        lastModifiedBy=$(stripOffQuotes $lastModifiedBy)
        # echo "lastModifiedBy=$lastModifiedBy"
        kennzeichen=$(ermittleKennzeichenAnhandUserid $lastModifiedBy)
      fi
    fi 
  fi
  echo $kennzeichen
}

function ermittleKennzeichenAnhandUserid {
  local userId=$1
  local kennzeichen=""
  OLDIFS=$IFS
  IFS="."
  read -ra array <<< "$USERIDS"
  for PROVIDER_USERS in "${array[@]}"
  do
    KENNZEICH=`echo $PROVIDER_USERS | sed 's/^\([^\:]*\):\(.*\)$/\1/'`
    USERLISTE=`echo   $PROVIDER_USERS | sed 's/^\([^\:]*\):\(.*\)$/\2/'`
    # Parse Userliste
    IFS=","
    read -ra array <<< "$USERLISTE"
    for USERID in "${array[@]}"
    do
      if [ "$USERID" = "$userId" ]; then
        kennzeichen=$KENNZEICH
        break
      fi
    done
    IFS="."
    if [ "$kennzeichen" != "" ]; then
      break
    fi
  done
  IFS=$OLDIFS
  echo $kennzeichen;
}

function increaseNumCrawlerSites {
  if [ "$crawler" = "wpull" ]; then
    sumWpullSites=$(($sumWpullSites+1))
  elif [ "$crawler" = "heritrix" ]; then
    sumHeritrixSites=$(($sumHeritrixSites+1))
  elif [ "$crawler" = "btrix" ]; then
    sumBtrixSites=$(($sumBtrixSites+1))
  fi
}

function addCrawlerDiscSpace {
  if [ "$crawler" = "wpull" ]; then
    sumWpullDiscSpace=`echo "scale=0; $sumWpullDiscSpace + $total_disc_usage" | bc`
  elif [ "$crawler" = "heritrix" ]; then
    sumHeritrixDiscSpace=`echo "scale=0; $sumHeritrixDiscSpace + $total_disc_usage" | bc`
  elif [ "$crawler" = "btrix" ]; then
    sumBtrixDiscSpace=`echo "scale=0; $sumBtrixDiscSpace + $total_disc_usage" | bc`
  fi
}

function findUrl {
  # ermittelt die URL zu einem Crawl. Steht in crawldir.
  if [ "$crawler" = "wpull" ]; then
    findUrlWpull
  elif [ "$crawler" = "heritrix" ]; then
    findUrlHeritrix
  # elif [ "$crawler" = "btrix" ]; then
    # Hier ist nichts zu tun. Die url wird bei getCrawlResultBtrix mit ermittelt.
  fi
}

function findUrlWpull {
  for datei in WEB-*.warc.gz; do
    ## Check if the glob gets expanded to existing files.
    ## If not, datei here will be exactly the pattern above
    ## and the exists test will evaluate to false.
    if [ -e "$datei" ]; then
      # echo "files do exist"
      url_raw=`echo $datei | sed 's/^WEB\-\(.*\)\-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\.warc\.gz/\1/'`
      # noch einmal versuchen für Dateinamen mit Zeitstempel im Namen (seit Frühjahr 2025):
      url_raw=`echo $url_raw | sed 's/^WEB\-\(.*\)\-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\.warc\.gz/\1/'`
      # noch einmal versuchen für Dateinamen mit ".attemptN" im Namen:
      url_raw=`echo $url_raw | sed 's/^WEB\-\(.*\)\-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\.attempt[0-9]\.warc\.gz/\1/'`
      url=`echo $url_raw | sed 's/_cdn$//'`
      echo "url=$url"
      break
    else # Suche auch noch in wpull-data-crawldir, falls Datei noch nicht verschoben wurde
      for datei_path in $wpullDataCrawldir/$pid/$crawldir/WEB-*.warc.gz; do
        ## Check if the glob gets expanded to existing files.
        ## If not, datei here will be exactly the pattern above
        ## and the exists test will evaluate to false.
        if [ -e "$datei_path" ]; then
          # echo "files do exist"
          datei=`basename $datei_path`
          url_raw=`echo $datei | sed 's/^WEB\-\(.*\)\-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\.warc\.gz/\1/'`
          # noch einmal versuchen für Dateinamen mit Zeitstempel im Namen (seit Frühjahr 2025):
          url_raw=`echo $url_raw | sed 's/^WEB\-\(.*\)\-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\.warc\.gz/\1/'`
          # noch einmal versuchen für Dateinamen mit ".attemptN" im Namen:
          url_raw=`echo $url_raw | sed 's/^WEB\-\(.*\)\-[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\.warc\.gz\.attempt[0-9]/\1/'`
          url=`echo $url_raw | sed 's/_cdn$//'`
          echo "url=$url"
          break
        fi
      done
    fi
  done
}

function findUrlHeritrix {
  # url zu der pid
  url=`grep "Edoweb crawl of" ../crawler-beans.cxml | sed 's/^.*Edoweb crawl of\(.*\)$/\1/'`
  echo "url=$url"
}

function getCrawlResult {
  # Auswertung der Eregbnisparameter zu einem Crawl.
  # steht in crawldir
  if [ "$crawler" = "wpull" ]; then
    getCrawlResultWpull
  elif [ "$crawler" = "heritrix" ]; then #[
    if [ -f reports/crawl-report.txt ]; then
      crawl_status=`grep -m 1 "^crawl status" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
      echo "crawl_status=$crawl_status"
      duration=`grep -m 1 "^duration" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
      echo "Dauer=$duration"
      uris_processed=`grep -m 1 "^URIs processed" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
      echo "uris_processed=$uris_processed"
      uris_successes=`grep -m 1 "^URI successes" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
      echo "uris_successes=$uris_successes"
      uris_failures=`grep -m 1 "^URI failures" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
      uris_disregards=`grep -m 1 "^URI disregards" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
      novel_uris=`grep -m 1 "^novel URIs" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
      total_crawled_bytes=`grep -m 1 "^total crawled bytes" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
      echo "total_crawled_bytes=$total_crawled_bytes"
      novel_crawled_bytes=`grep -m 1 "^novel crawled bytes" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
      uris_sec=`grep -m 1 "^URIs/sec" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
      kb_sec=`grep -m 1 "^KB/sec" reports/crawl-report.txt | sed 's/^.*: \(.*\)$/\1/'`
      kb_sec="$kb_sec KiB/s"
      echo "speed=$kb_sec"
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
  elif [ "$crawler" = "btrix" ]; then #]
    getCrawlResultBtrix
  fi
}

function getCrawlResultBtrix {
  # steht in crawldir
  # Hole CrawlId aus dem Namen der Archivdateien 
  CRAWL_ID=""
  for datei in archive/*.warc.gz; do
    if [ ! -e "$datei" ]; then 
      # the glob does not expand
      echo "WARN: archive files do not exist - no information about the crawl available!"
      break
    fi
    if [[ "$datei" =~ ^.*(manual-[0-9]{14}-[0-9a-f]{8}-[0-9a-f]{3})-[0-9]{17}-[0-9]+\.warc\.gz$ ]]; then
      CRAWL_ID=${BASH_REMATCH[1]}
      break
    else
      echo "WARN: CRAWL_ID could not be extracted from archive file name $datei !"
    fi    
  done
  if [ -z $CRAWL_ID ]; then
    echo "WARN: CrawlId for Btrix-Crawl can not be determined!"
    return
  fi
  echo "CRAWL_ID=$CRAWL_ID"
  local TOKEN=$(btrix_getBearerToken)
  #echo "TOKEN=$TOKEN"
  local crawlOutJson=$(btrix_getCrawlOut $CRAWL_ID)
  # echo $crawlOutJson | jq
  # crawlstart=`echo $crawlOutJson | jq ".started"` -- das ist schon bekannt!
  # echo "crawlstart=$crawlstart";
  crawl_status=`echo $crawlOutJson | jq ".state"`
  crawl_status=$(stripOffQuotes $crawl_status)
  echo "crawl_status=$crawl_status";
  # error_cause=
  local seconds=`echo $crawlOutJson | jq ".crawlExecSeconds"`
  duration=$(seconds2HoursMinSec $seconds)
  echo "duration=$duration";
  uris_processed=`echo $crawlOutJson | jq ".stats.done"`
  echo "uris_processed=$uris_processed";
  uris_successes=`echo $crawlOutJson | jq ".stats.found"`
  echo "uris_successes=$uris_successes";
  local bytes=`echo $crawlOutJson | jq ".fileSize"`
  total_crawled_bytes=$(bytes2GibMibKib $bytes)
  echo "total_crawled_bytes=$total_crawled_bytes";
  local firstSeed=`echo $crawlOutJson | jq ".firstSeed"`
  firstSeed=$(stripOffQuotes $firstSeed)
  url=`echo $firstSeed | sed 's/^http[s]*:\/\///' | sed 's/\/$//'`
  echo "url=$url";
  kb_sec=$(calcDownloadSpeed $bytes $seconds)
  echo "kb_sec=$kb_sec";
}

function getCrawlResultWpull {
  # steht in crawldir
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
            crawl_status="ABORTED/PICKED"
            echo "crawl_status=$crawl_status"
          elif grep --quiet "^ERROR" $crawllog ; then
            crawl_status="ERROR/PICKED"
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
    # kb_sec=`echo $kb_sec | sed 's/^\(.*\) KiB\/s$/\1/'`
    files_downloaded=`grep -m 1 "^INFO Downloaded" $crawllog | sed 's/^.*: \(.*\) files, \(.*\)\.$/\1/'` # => uris_successes
    echo "files_downloaded=$files_downloaded"
    uris_successes=$files_downloaded
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
}

function sumAnzAttempts {
  if [ "$crawler" = "wpull" ]; then
    sumWpullCrawls=$(($sumWpullCrawls+$anz_attempts))
  elif [ "$crawler" = "heritrix" ]; then
    sumHeritrixCrawls=$(($sumHeritrixCrawls+$anz_attempts))
  elif [ "$crawler" = "btrix" ]; then
    sumBtrixCrawls=$(($sumBtrixCrawls+$anz_attempts))
  fi
}
#] ENDE bash-Funktionen

reportDir=/opt/toscience/crawlreports
discUsageWebsites=$reportDir/discUsageWebsites/$(hostname).discUsageWebsites.$(date +"%Y%m%d%H%M%S").csv
crawlReport=$reportDir/crawlReports/$(hostname).crawlReport.$(date +"%Y%m%d%H%M%S").csv
baseUrl=https://$DOMAIN/crawlreports
REGAL_TMP=/opt/toscience/tmp
if [ ! -d $REGAL_TMP ]; then mkdir $REGAL_TMP; fi
aktJahr=`date +"%Y"`
# BEGINN Hauptverarbeitung
echo "*************************************************"
echo "BEGINN Crawl-Report" `date`
echo "*************************************************"
echo "schreibe nach csv-Dateien:"
echo "   $discUsageWebsites"
echo "   $crawlReport"
echo "^PID;KZ;URL;total_disc_usage [MB];Webschnitte;Crawl-Versuche;Crawler;Aleph-ID;" > $discUsageWebsites
echo "^PID;KZ;URL;Crawl-Start;Crawl-Status;Crawl-Dauer;Bytes eingesammelt;Anzahl URIs geholt;Geschwindigkeit;Plattenplatz für WARCs;Crawler;Aleph-ID;Fehlerursache(n);" > $crawlReport

# 1. Einstiegspunkt für alle Crawls (alle Crawler)
# ************************************************
sumHeritrixSites=0
sumWpullSites=0
sumBtrixSites=0
sumHeritrixDiscSpace=0
sumWpullDiscSpace=0
sumBtrixDiscSpace=0
sumHeritrixCrawls=0
sumWpullCrawls=0
sumBtrixCrawls=0
wpullDataCrawldir=/opt/toscience/wpull-data-crawldir
. ~/bin/syncCrawlErrorLogs.sh
cd $ARCHIVE_HOME
#[ Schleife über PIDs
for crawler_pid in `ls -dv wpull-data/$NAMESPACE:* btrix-data/$NAMESPACE:* heritrix-data/$NAMESPACE:*`; do
  if [[ "$crawler_pid" =~ ^([a-z]+)-data/(.*)$ ]]; then
    crawler=${BASH_REMATCH[1]}
    pid=${BASH_REMATCH[2]}
  else
    continue
  fi
  echo "crawler=$crawler"
  echo "pid=$pid"
  # Gibt es die PID überhaupt im Regal-Backend ? (fehlerhafte Crawls könnten dort gelöscht worden sein)
  # Falls ja, ermittle Aleph-ID zu der PID.
  hbzid="keine"
  title=""
  kennzeichen=""
  status_code="unknown"
  IFS=$'\n'
  for httpResponse in `curl -is -u $REGAL_ADMIN:$REGAL_PASSWORD "$BACKEND/resource/$pid.json2"`; do
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
    fi
    if [ -n "$KENNZEICHEN" ]; then
      # Ermittle das Kennzeichen "Data-Provider"
      kennzeichen=$(ermittleKennzeichen)
    fi
  fi
  echo "hbzid=$hbzid"
  if [ -n "$title" ]; then echo "Titel=$title"; fi
  if [ -n "$kennzeichen" ]; then echo "Kennzeichen=$kennzeichen"; fi
  increaseNumCrawlerSites
  cd $ARCHIVE_HOME/$crawler_pid
  total_disc_usage=`du -ks . | sed 's/^\(.*\)\s.*$/\1/'`
  echo "total disc usage=$(formatDiscUsage $total_disc_usage)"
  addCrawlerDiscSpace
  anz_success=`echo $httpResponse | jq '.hasPart | length'`
  anz_attempts=0
  url=""
  # Schleife über alle Crawls zu dieser pid
  for crawldir in 20???????????? ; do
    if [ ! -d "$crawldir" ]; then
      echo "Es gibt keine Crawl-Verzeichnisse."
      break
    fi
    anz_attempts=$(($anz_attempts+1))
    cd $ARCHIVE_HOME/$crawler_pid/$crawldir
    findUrl
    if [[ ! "$crawldir" =~ ^$aktJahr..........$ ]]; then 
      cd $ARCHIVE_HOME/$crawler_pid
      continue;
    fi
    # Crawl im aktuellen Jahr, wird weiter ausgewertet
    echo "crawldir=$crawldir"
    inputdate=`echo $crawldir | sed 's/^\([0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\)\([0-9][0-9]\)$/\1 \2:\3:\4/'`
    crawlstart=`date -d "$inputdate" +'%FT%T'`
    echo "crawlstart=$crawlstart"
    crawl_status=""
    error_cause=""
    duration=""
    uris_processed=""
    uris_successes=""
    total_crawled_bytes=""
    kb_sec=""
    getCrawlResult
    # von WARCs belegter Plattenplatz
    disc_usage_warcs=0
    crawldirs="."
    # suche auch in wpullDataCrawldir, falls wpull-Crawl und noch nicht beendet.
    if [ -d "$wpullDataCrawldir/$pid/$crawldir" ]; then
      crawldirs="$crawldirs $wpullDataCrawldir/$pid/$crawldir"
    fi
    for datei in `find $crawldirs -name "*.warc.gz"`; do
      disc_usage_kb=`du -ks $datei | sed 's/^\(.*\)\s.*$/\1/'`
      disc_usage_warcs=`echo "$disc_usage_warcs + $disc_usage_kb" | bc`
    done
    echo "disc usage for warcs=$(formatDiscUsage $disc_usage_warcs)"
    # *** Schreibe Zeile nach crawlReport für diesen Crawl***
    echo "$pid;$kennzeichen;$url;$crawlstart;$crawl_status;$duration;$total_crawled_bytes;$uris_successes;$kb_sec;$(formatDiscUsage $disc_usage_warcs);$crawler;$hbzid;$error_cause;" >> $crawlReport
    cd $ARCHIVE_HOME/$crawler_pid
    continue # next crawldir
  done
  if [ $anz_attempts -eq 0 ]; then
    # noch keine Crawls für diese pid vorhanden
    # *** Schreibe Zeile nach crawlReport für diese PID ***
    echo "no crawls yet" # kommt nie vor
    # echo "$crawler;$pid;$url;;;;;;;;;;;;" >> $crawlReport
  fi
  # Anzahl gestarteter Crawls zu dieser pid (inklusive Crawl-Versuche)
  echo "anz_attempts=$anz_attempts"
  sumAnzAttempts
  # Schreibe Zeile nach discUsageWebsites für diese PID
  if [ $anz_attempts -gt 0 ]; then
    echo "$pid;$kennzeichen;$url;$(formatDiscUsage $total_disc_usage);$anz_success;$anz_attempts;$crawler;$hbzid" >> $discUsageWebsites
  fi
  echo
done #] next pid

echo " "
echo "Summenwerte :"
echo "****************************************"
echo " "

echo "Summen;Anzahl Sites;;belegter Plattenplatz;Anzahl Crawl-Versuche;" >> $discUsageWebsites
echo "Anzahl Sites mit jemals für Heritrix eingeplanten Crawls: $sumHeritrixSites"
echo "Anzahl angestarteter Heritrix-Crawls im Jahre $aktJahr: $sumHeritrixCrawls"
echo "Plattenplatzbelegung durch Heritrix Crawls: $(formatDiscUsage $sumHeritrixDiscSpace)"
echo "Summe heritrix;$sumHeritrixSites Sites;;$(formatDiscUsage $sumHeritrixDiscSpace);$sumHeritrixCrawls;" >> $discUsageWebsites
echo "Anzahl Sites mit jemals für Wpull eingeplanten Crawls: $sumWpullSites"
echo "Anzahl angestarteter Wpull-Crawls im Jahre $aktJahr: $sumWpullCrawls"
echo "Plattenplatzbelegung durch Wpull Crawls: $(formatDiscUsage $sumWpullDiscSpace)"
echo "Summe wpull;$sumWpullSites Sites;;$(formatDiscUsage $sumWpullDiscSpace);$sumWpullCrawls;" >> $discUsageWebsites
echo "Anzahl Sites mit jemals für Browsertrix eingeplanten Crawls: $sumBtrixSites"
echo "Anzahl angestarteter Browsertrix-Crawls im Jahre $aktJahr: $sumBtrixCrawls"
echo "Plattenplatzbelegung durch Browsertrix Crawls: $(formatDiscUsage $sumBtrixDiscSpace)"
echo "Summe Browsertrix;$sumBtrixSites Sites;;$(formatDiscUsage $sumBtrixDiscSpace);$sumBtrixCrawls;" >> $discUsageWebsites
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
mailbodydatei=$REGAL_TMP/mail_crawlReport.$$.out.txt
echo "******************************************" > $mailbodydatei
echo "$PROJECT Website Crawl Reports" >> $mailbodydatei
echo "******************************************" >> $mailbodydatei
aktdate=`date +"%d.%m.%Y %H:%M:%S"`
echo "Aktuelles Datum und Uhrzeit: $aktdate" >> $mailbodydatei
echo "Berichte für den Server: $SERVER" >> $mailbodydatei
echo "" >> $mailbodydatei
echo "Aktuelle Speicherplatzbelegung (Summen) durch Website-Crawls: $baseUrl/discUsageWebsites/`basename $discUsageWebsites`" >> $mailbodydatei
echo "Aktuelle Status und Kennzahlen der einzelnen Crawl-Aufträge : $baseUrl/crawlReports/`basename $crawlReport`" >> $mailbodydatei

subject="$DOMAIN Website Crawl Reports";
xheader="X-Edoweb: $(hostname) crawl reports";
recipients=$EMAIL_RECIPIENT_ADMIN_USERS;
OLDIFS=$IFS
IFS=" "
read -ra array <<< "$recipients"
for recipient in "${array[@]}"
do
  mailx -s "$subject" $recipient < $mailbodydatei
done
IFS=$OLDIFS
# rm $mailbodydatei

exit 0
