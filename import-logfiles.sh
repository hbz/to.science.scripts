#! /bin/bash

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

CURDIR=`pwd`
cd $scriptdir
source variables.conf

YESTERDAY=$(LANG=en;date +"%d/%b/%Y" -d"yesterday")    
IDSITE=1
STATS_LOG=$REGAL_LOGS/stats.log



function loadLogFile() {
    DIR=`date +%s`
    mkdir $REGAL_TMP/$DIR

    PATTERN=$1
    echo Lade $PATTERN >> $STATS_LOG
    zgrep --no-filename $PATTERN /var/log/apache2.prod/access_log*|sort|uniq > $REGAL_TMP/matomoImport.log

    cd $REGAL_TMP/$DIR
    split -l 5000 $REGAL_TMP/matomoImport.log
    
    for i in `ls`
    do
	/usr/bin/python $MATOMO/misc/log-analytics/import_logs.py --recorder-max-payload-size=200 --url $MATOMO_URL --login $MATOMO_ADMIN --password $MATOMO_PASSWORD $i --idsite=$IDSITE >> $STATS_LOG
    done
    cd -
    rm -rf $REGAL_TMP/$DIR
}


loadLogFile "$YESTERDAY"
#loadLogFile "01/Nov/2023"
#loadLogFile "31/Oct/2023"
#loadLogFile "18/Feb/2019"
#loadLogFile "07/Mar/2019"
#loadLogFile "19/Mar/2019"
#loadLogFile "20/Mar/2019"
#loadLogFile "09/May/2019"
#loadLogFile "18/Jun/2019"
#loadLogFile "24/Jun/2019"
#loadLogFile "27/Jun/2019"
#loadLogFile "04/Jul/2019"
#loadLogFile "09/Jul/2019" 

# Beispiel um die Logfiles der letzten 10-40 Tage zu laden
#
#for i in {10..40};do loadLogFile "$(LANG=en;date +"%d/%b/%Y" -d"$i days ago")";done

# Beispiel um die Differenz in Tagen auszurechnen
#
# A="2018-01-21"
# B="2018-04-08"
# echo $(( (`date -d $B +%s` - `date -d $A +%s`) / 86400 )) days

#for i in `ls $REGAL_TMP/x*`
#do
#python $MATOMO/misc/log-analytics/import_logs.py --recorder-max-payload-size=200 --url $MATOMO_URL --login $MATOMO_ADMIN --password $MATOMO_PASSWORD $i --idsite=$IDSITE >> $STATS_LOG
#done

cd $CURDIR
