#! /bin/bash

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf
PASSWORD=$REGAL_PASSWORD
NAMESPACE=frl
alephId=$1
pid=$2
doi=$3
pdf=$pid.pdf

curl -s -O -L -referer ";auto" $doi -o $pdf
echo
echo "File Downloaded $pdf"
curl -s -u$ADMIN_USER:$PASSWORD -H"content-type:application/json" -XPUT -d'{"contentType":"monograph"}' "$BACKEND/resource/$NAMESPACE:$pid"
echo
echo "Title Object created $NAMESPACE:$pid"
curl -s -u$ADMIN_USERn:$PASSWORD -XPOST "$BACKEND/utils/lobidify/$NAMESPACE:$pid?alephid=$alephId"
echo
echo "$NAMESPACE:$pid lobidified $alephId"

resp=`curl -s -u$ADMIN_USERn:$PASSWORD -H"content-Type:application/json" -XPOST -d"{\"contentType\":\"file\",\"parentPid\":\"$NAMESPACE:$pid\"}" $BACKEND/resource/$NAMESPACE`
filePid=`echo $resp|grep -o "$NAMESPACE:......."`
echo
echo "File Object created $filePid!"
curl -s -u$ADMIN_USERn:$PASSWORD -XPUT -F"data=@$pdf;type=application/pdf" "$BACKEND/resource/$filePid/data"
echo
echo "PDF uploaded $filePid/data"

curl -s -u$ADMIN_USERn:$PASSWORD -XPOST https://frl.publisso.de/resource/$NAMESPACE:$pid/doi/update
echo
echo "DOI update $doi -->  https://frl.publisso.de/resource/$NAMESPACE:$pid"
