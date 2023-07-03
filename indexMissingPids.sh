#! /bin/bash
# This script takes a PID list and re-indexes all pids in the list.

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

# Way 1: Create PID list along with identifiers : perl get_pids.pl -m 100000 -n edoweb
# Way 2: Create PID list based on creation dates: perl get_pidlist.pl -f 2023-05-01 -t 2023-06-30

echo "index all"
# Choose
# Way 1:
#cat ../logs/get_pids.txt | parallel --jobs 5 ./indexPid.sh {} $BACKEND >$REGAL_LOGS/index-`date +"%Y%m%d"`.log 2>&1
# Way 2:
cat get_pidlist.txt | parallel --jobs 5 ./indexPid.sh {} $BACKEND >$REGAL_LOGS/index-`date +"%Y%m%d"`.log 2>&1

cd -
