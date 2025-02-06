#! /bin/bash


scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

curlog=$REGAL_LOGS/lobidify-20160404.log
recipients="toscience-admin@hbz-nrw.de";
subject="FRL - Fehlerhafte Updates";
mailfile="updateAll.mailbody.txt"
grep "Exception" $curlog|grep -o "frl\:[^\ ]*"|sort -u | sed s,"\(.*\)","https://$SERVER/resource/\1", > $mailfile
mailx -s "$subject" $recipients < $mailfile 
rm $mailfile

cd -
