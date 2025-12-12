#!/bin/bash
# Dieses kleine Skript hängt einen bestehenden Webschnitt (Type Version) an einen Parent (Type Website) an.

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

pid="nwweb:1359"
versionPid=""
dataDir="/opt/toscience/wpull-data"
timestamp="20250206200019"
filename="WEB-www.lindt.de-20250206.warc.gz"
curl -XPOST -u$ADMIN_USER:$ADMIN_PASSWORD "$BACKEND/resource/$pid/postVersion?versionPid=$versionPid&dataDir=$dataDir&timestamp=$timestamp&filename=$filename" -H "UserId=gatherposter" -H "Content-Type: text/plain; charset=utf-8";
