#! /bin/bash

#
# Author: Jan Schnasse
#

# only work on files older then $days 
days=7
# look for files in this directory
logDir="/var/log/apache2/"
# with this extension 
extension="*.xz"
# depersonalize by replacing the last two bytes of an IP with this string
anoBytes=".0.0"
# define how to behave after anonymizing 
function postProcess(){
#  echo remove $1 
#  rm -f $1
  mv $1 /opt/toscience/apachelog.bck
}

#-----------config end-----------------

# Generate list of files to work on
filesToAnnonymize=`find $logDir -type f -name "$extension" ! -name "*.ano.*" -mtime +$days`
#echo "Try to annonymize $filesToAnnonymize"
# Test if
if touch $logDir/.annonymize-apache-logs.sh.test > /dev/null 2>&1
then
	rm $logDir/.annonymize-apache-logs.sh.test
else
	echo "You don't have permission to write into $logDir"
	exit 1;
fi


#Work through each file
for file in `echo $filesToAnnonymize`
do
	datestamp=`date +"%Y%m%d%H%M%s"`
        echo Process $file
    	xzcat $file |sed -E "s/([0-9]{1,3}\.[0-9]{1,3})\.[0-9]{1,3}\.[0-9]{1,3}/\1$anoBytes/"|gzip > ${file%.*}.ano.${datestamp}.gz 
	postProcess $file
done
