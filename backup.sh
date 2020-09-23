#!/bin/sh

# functions
    # curator check repo
    # check there is a log 
# decrypt
decrypt()
{
    gpg --batch --passphrase $PASSWORD -o $1 -d $1

    echo "Succesfully decrypting file $1"
}
# encrypt
encrypt()
{
    # sync encryption
    gpg --batch -c --passphrase $PASSWORD --armor --symmetric --cipher-algo AES256 $1

    echo "Successfully Encrypted file: $1"
}
    # wait for status
cd /var/nfs

if [ "backup" = $STATE ]; then
    echo "Running Backup cmd..."
    
    # check encryption log file if none create one
    if [ -e /var/nfs/encryptionLog.txt ]
    then
        echo "encryption Log found"
        # foreach file in log file decrypt
        while read in 
        do 
            decrypt "$in"; 
        done < encryptionLog.txt
        > encryptionLog.txt
    else
        echo "no encryption log found, creating log"
        touch /var/nfs/encryptionLog.txt
    fi

    # Run curator backup cmd
        # check repo exist if not create
        # sent snapshot cmd

    # wait for status succesfull or error
        # timeout error if to long

        # if error exit with error

    # find files to be encrypted
    ls /var/nfs/$search_path > tempList.txt

    # encrypt indies folder content
    # while read in 
    # do 
    #     encrypt "$in"; 
    #     echo "$in" >> encryptionLog.txt
    # done < tempList.txt

    # rm tempList.txt
    # # if no errors exit succesfull

    # if [ $? -ne 0 ]; then
    #     echo "Back up failed"
    #     exit 1
    # fi

    echo 'Successfully Backup of elastic logs'
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