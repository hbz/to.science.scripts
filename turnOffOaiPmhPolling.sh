#!/bin/bash

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

mysql -uoaipmh -p$OAIPMH_PASSWORD -e"UPDATE oaipmh.rcAdmin SET pollingEnabled=0;"

