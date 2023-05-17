#! /bin/bash

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

function init(){
    echo "Init"
    echo "Please do zypper install jq"
    mkdir -p $REGAL_BACKUP/elasticsearch
    echo "Please do zypper install jq"
    echo "Please do chown -R elasticsearch $REGAL_BACKUP/elasticsearch"
    curl -XPUT $ELASTICSEARCH/_snapshot/my_backup -d'{"type":"fs","settings":{"compress":true,"location":"$REGAL_BACKUP/elasticsearch"}}}'
    echo "Done!"
}

function clean(){
    echo "Clean"
    # The amount of snapshots we want to keep.
    LIMIT=30
    # Name of our snapshot repository
    REPO=my_backup
    # Get a list of snapshots that we want to delete
    SNAPSHOTS=`curl -s -XGET "$ELASTICSEARCH/_snapshot/$REPO/_all" \
  | jq -r ".snapshots[:-${LIMIT}][].snapshot"`

    # Loop over the results and delete each snapshot
    for SNAPSHOT in $SNAPSHOTS
    do
        echo "Deleting snapshot: $SNAPSHOT"
        curl -s -XDELETE "$ELASTICSEARCH/_snapshot/$REPO/$SNAPSHOT?pretty"
    done
    echo "Done!"
}

function backup(){
    echo "Backup"
    SNAPSHOT=`date +%Y%m%d-%H%M%S`
    curl -XPUT "$ELASTICSEARCH/_snapshot/my_backup/$SNAPSHOT?wait_for_completion=true"
    echo "Done!"
}


function restore(){
    echo "Restore"
    #
    # Restore a snapshot from our repository
    SNAPSHOT=123

    # We need to close the index first
    curl -XPOST "$ELASTICSEARCH/my_index/_close"

    # Restore the snapshot we want
    curl -XPOST "$ELASTICSEARCH/_snapshot/my_backup/$SNAPSHOT/_restore" -d '{
     "indices": "my_index"
    }'

    # Re-open the index
    curl -XPOST '$ELASTICSEARCH/my_index/_open'
    echo "Done!"
}

# Use -gt 1 to consume two arguments per pass in the loop (e.g. each
# argument has a corresponding value to go with it).
# Use -gt 0 to consume one or more arguments per pass in the loop (e.g.
# some arguments don't have a corresponding value to go with it such
# as in the --default example).
# note: if this is set to -gt 0 the /etc/hosts part is not recognized ( may be a bug )
while [[ $# -gt 0 ]]
do
key="$1"

case $key in
    -i|--init)
	init;
    shift # past argument
    ;;
    -b|--backup)
	backup;
    shift # past argument
    ;;
    -r|--restore)
	restore
    shift # past argument
    ;;
    -c|--clean)
	clean
    shift # past argument
    ;;
    *)
       # unknown option
      echo "Use --init|--backup|--clean|--restore"     
    ;;
esac
shift # past argument or value
done

cd -
