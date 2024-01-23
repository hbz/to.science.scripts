#! /bin/bash

scriptdir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
cd $scriptdir
source variables.conf

function init(){
    echo "Init"
    mkdir -p $REGAL_BACKUP/mysql
    echo "Done!"
}

function backup(){
    SNAPSHOT=`date +%Y%m%d-%H%M%S`
    mysqldump -u root -p$MYSQL_PASSWORD --events --all-databases > $REGAL_BACKUP/mysql/$SNAPSHOT.sql
}

function clean(){
    echo "Clean"
    # The amount of snapshots we want to keep.
    LIMIT=30

    # Get a list of snapshots that we want to delete
    len=`ls -tr $REGAL_BACKUP/mysql/|wc -l`
    num=`expr $len - $LIMIT`
    if [ $num -gt 0 ]
    then
        SNAPSHOTS=`ls -tr $REGAL_BACKUP/mysql/|head -$num` 
        # Loop over the results and delete each snapshot
        for SNAPSHOT in $SNAPSHOTS
        do
            echo "Deleting snapshot: $SNAPSHOT"
            rm -rf $REGAL_BACKUP/mysql/$SNAPSHOT
        done
    fi
    echo "Done!"
}

function restore(){
    SNAPSHOT=123
    mysql -u root $MYSQL_PASSWORD -p < $SNAPSHOT.sql
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
