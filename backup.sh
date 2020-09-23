#!/bin/sh

# functions
    # curator check repo
    # check there is a log 
    # decrypt
    # encrypt
    # wait for status

if [ "backup" = $STATE ]; then
    echo "Running Backup cmd..."
    
    # encryption log file if none create one

    # Decrypt indies folder content
        # read file name from log file
        # foreach file in log file decrypt

    # Run curator backup cmd
        # check repo exist if not create
        # sent snapshot cmd

    # wait for status succesfull or error
        # timeout error if to long

        # if error exit with error
    
    # encrypt indies folder content

    # if no errors exit succesfull

    DUMP_FILE_NAME="${DBAPP}-$(date +$DATEFORMAT).dump"
    echo "time format: $(date +$DATEFORMAT)"
    echo "Creating dump: $DUMP_FILE_NAME"

    # dump sql db
    pg_dump -Fc $PGDATABASE > $DUMP_FILE_NAME

    if [ $? -ne 0 ]; then
        echo "Back up not created, check db connection settings"
        exit 1
    fi

    echo 'Successfully Backed Up'

    # sync encryption
    gpg --batch -c --passphrase $PASSWORD --armor --symmetric --cipher-algo AES256 $DUMP_FILE_NAME

    echo "Successfully Encrypted dump file: ${DUMP_FILE_NAME}"

    # move backup file
    ssh $REMOTEUSER@$REMOTEIP mkdir $STORAGEPATH/$NAMESPACE
    ssh $REMOTEUSER@$REMOTEIP mkdir $STORAGEPATH/$NAMESPACE/$DBAPP
    scp $DUMP_FILE_NAME.asc $REMOTEUSER@$REMOTEIP:$STORAGEPATH/$NAMESPACE/$DBAPP

    if [ $? -ne 0 ]; then
        echo "Back up could not be move to storage, check scp connection to ${REMOTEUSER}@${$REMOTEIP}"
        exit 1
    fi

    echo 'Successfully pushed to backup storage'
    exit 0
fi

if [ "restore" = $STATE ]; then

    echo "Running Restore cmd..."

    # check repo connection if error exit with error

    # Check log file
    # decrypt files in log

    # curator send restore cmd
    # wait for status 

    # encrypt files in indies folder

    # if status succesfull exit succesfull else error exit




    if [ -z ${BACKUPFILE+x} ]; then
        echo "Pulling backup lastes backup from server"
        BACKUP=$( ssh $REMOTEUSER@$REMOTEIP ls -c $STORAGEPATH/$NAMESPACE/$DBAPP | head -1 )
        scp $REMOTEUSER@$REMOTEIP:$STORAGEPATH/$NAMESPACE/$DBAPP/$BACKUP ./
       
        if [ $? -ne 0 ]; then
            echo "Back up could not be pulled from storage, check scp connection to ${REMOTEUSER}@${$REMOTEIP}"
            exit 1
        fi
        echo "Latest backup: $BACKUP"
    else
        echo "Pulling backup ${BACKUPFILE} from server"
        BACKUP=$BACKUPFILE
        scp $REMOTEUSER@$REMOTEIP:$STORAGEPATH/$NAMESPACE/$DBAPP/$BACKUPFILE ./
        if [ $? -ne 0 ]; then
            echo "Back up could not be pulled from storage, check scp connection to ${REMOTEUSER}@${$REMOTEIP}"
            exit 1
        fi
    fi
    echo "Succesfully retrived Backup file"

    gpg --batch --passphrase $PASSWORD -o backup.dump -d $BACKUP

    echo "Succesfully decrypting Backup file"

    pg_restore $RESTOREOPTIONS -d $PGDATABASE backup.dump
    if [ $? -ne 0 ]; then
        echo "Error: Restoring of backup failed, check db connection settings"
        exit 1
    fi
    echo "Succesfully restoring ${PGDATABASE} from backup"
    exit 0
fi
echo " invalid command STATE ENV must be set to backup or restore"
exit 1