#!/bin/bash
# Dieses kleine Skript hängt einen bestehenden Webschnitt (Type Version) an einen Parent (Type Website) an.

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

pid="toscience:1234"
versionPid=""
dataDir="/data2/wpull-data"
timestamp="20240630120000"
filename="WEB-mysite.de-20240630.warc.gz"
curl -XPOST -u$ADMIN_USER:$ADMIN_PASSWORD "$BACKEND/resource/$pid/postVersion?versionPid=$versionPid&dataDir=$dataDir&timestamp=$timestamp&filename=$filename" -H "UserId=gatherposter" -H "Content-Type: text/plain; charset=utf-8";
