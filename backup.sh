#!/bin/sh

# functions
    # curator check repo
    # check there is a log 
# decrypt
decrypt2()
{
    # check encryption log file if none create one
    if [ -e /var/nfs/encryptionLog.txt ]
    then
        if [ -s /var/nfs/encryptionLog.txt ]
        then
            echo "encryption Log found"
            # foreach file in log file decrypt
            while read in 
            do 
                gpg --batch --passphrase $PASSWORD -o $in -d $in.asc; 
                rm $in.asc
            done < ../encryptionLog.txt
            > ../encryptionLog.txt
        else
            echo "encryptionLog is empty: no encrypted files to decrypt"
        fi
    else
        echo "no encryption log found, creating log"
        touch /var/nfs/encryptionLog.txt
    fi
    #echo "Succesfully decrypting file $1"
}
# encrypt
encrypt2()
{ 
    # find files to be encrypted
    ls /var/nfs/$search_path | grep -v \\.asc  > ../tempList.txt
    #encrypt indies folder content
    while read in 
    do 
        # sync encryption
        gpg --batch -c --passphrase $PASSWORD --symmetric --cipher-algo AES256 $in; 
        echo "$in" >> /var/nfs/encryptionLog.txt
        if [ -e /var/nfs/encryptionLog.txt ]
        then
            rm $in
            echo "Successfully Encrypted file: $in"
        else
            echo "Error: $in was not encrypted"
        fi
    done < ../tempList.txt

    rm ../tempList.txt
}

makeRepo()
{
    curl -X PUT "localhost:9200/_snapshot/my_backup?pretty" -H 'Content-Type: application/json' -d'
    {
        "type": "fs",
        "settings": {
            "location": "my_backup_location"
        }
    }
    '

}

checkRepo()
{

    curl -X POST "localhost:9200/_snapshot/elastic/_verify?pretty"


    res=$(curl -X GET "localhost:9200/_snapshot/elastic?pretty" | jq '.elastic')
    echo $res
    if []
    then
        echo "repo found"
        return 0
    else
        echo "could not find repo"
        return 1
    fi
}


REPO=elastic
SNAPSHOT=snapshot_1

checkSnapshotState()
{
    curl -X GET "elasticsearch:9200/_snapshot/$REPO/$SNAPSHOT/_status?pretty" > respondState.json
    res=$( cat respondState.json | jq ".snapshots[].state")
    case $res in
        '"SUCCESS"')
            echo "The snapshot finished and all shards were stored successfully."
            return 0
            ;;
        '"FAILED"')
            echo "The snapshot finished with an error and failed to store any data."
            return 1
            ;;
        '"IN_PROGRESS"')
            echo "The snapshot is currently running."
            return 2
            ;;
        '"PARTIAL"')
            echo "The global cluster state was stored, but data of at least one shard was not stored successfully."
            errors=$( cat respondState.json | jq ".snapshots[].failures[]")
            echo " Errors: $errors "
            return 3
            ;;
        *)
            return 1
            ;;
    esac
    # if [ "$res" = '"SUCCESS"' ]
    # then
    #     echo "snapshot completed"
    #     return 0
    # else
    #     echo "waiting for snapshot completion"
    #     return 1
    # fi 
}

waitForState()
{
    snap=2
    while [ $snap -eq 2 ]
    do
        checkSnapshotState
        snap=$?
    done

    return $snap

}
takeSnapshot()
{
    curl -X PUT "localhost:9200/_snapshot/elastic/snapshot_3?wait_for_completion=true&pretty" -H 'Content-Type: application/json' -d'
    {
        "indices": "-.kibana1",
        "ignore_unavailable": true,
        "include_global_state": false,
        "metadata": {
            "taken_by": "kimchy",
            "taken_because": "backup before upgrading"
        }
    }
    '

}
restoreSnapshot()
{
    curl -X POST "localhost:9200/_snapshot/elastic/snapshot_1/_restore?pretty"
}
decrypt()
{
    if [ -e /var/nfs/backup-indices.tar.gz.gpg ] 
    then
        gpg --batch --passphrase $PASSWORD -o backup-indices.tar.gz -d backup-indices.tar.gz.gpg && rm backup-indices.tar.gz.gpg
        
        tar -xvzf backup-indices.tar.gz && rm backup-indices.tar.gz

        echo "file decrypted"
        
    else
        echo "No file to decrypt: $1.tar.gz"
    fi

}

encrypt()
{
    tar -czvf backup-indices.tar.gz indices && rm -R indices/
    gpg --batch --passphrase $PASSWORD --symmetric --cipher-algo AES256 backup-indices.tar.gz && rm backup-indices.tar.gz
    if [ $? -ne 0 ]; then
        echo "Could not encrypt: indices"
    fi
}

#checkRepo
#takeSnapshot
#checkSnapshotState
#restoreSnapshot

# if [ $? = 0 ]
# then
#     echo "code 0"
# else
#     echo "code 1"

# fi
# wait for status
cd /var/nfs/

if [ "backup" = $STATE ]; then
#     echo "Running backup cmd..."
    

    #repofound=$(checkRepo) 
    # check encryption log file if none create one
    decrypt $SEARCH_PATH

    # Run curator backup cmd
        # check repo exist if not create
    
    curator --config /config/config.yaml /config/backup.yaml

    waitForState
    success=$?

    if [ $success -eq 0 ]
    then
        echo "backup success"
        encrypt $SEARCH_PATH
        exit 0
    else
        echo "backup failed"
        encrypt $SEARCH_PATH
        exit 1
    fi
fi

if [ "restore" = $STATE ]; then

    echo "Running Restore cmd..."

    # check repo connection if error exit with error

    # Check log file
    # decrypt files in log
    decrypt $SEARCH_PATH
    # curator send restore cmd
    curator --config /config/config.yaml /config/restore.yaml
    # if [ $? -ne 0 ]; then
    #     echo "Back up not created, check db connection settings"
    #     exit 1
    # fi
    # wait for status 

    # encrypt files in indies folder
    encrypt $SEARCH_PATH
    # if status succesfull exit succesfull else error exit

    exit 0

fi

echo " invalid command STATE ENV must be set to backup or restore"
exit 1