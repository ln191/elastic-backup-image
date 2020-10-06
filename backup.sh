#!/bin/sh

makeRepo()
{
    curl -X PUT "$ELASTIC_HOST:$PORT/_snapshot/$1?pretty" -H 'Content-Type: application/json' -d' { "type": "fs","settings": { "compress": "true", "location": "/nfs" } }' > respondState.json 

    res=$( cat respondState.json | jq ".acknowledged" )
    echo $res
    if [ "true" = $res ]
    then
        echo "repo created: $1"
        return 0
    else
        echo "ERROR: could not create repo: $1"
        return 1
    fi
}

checkRepo()
{
    res=$(curl -X GET "$ELASTIC_HOST:$PORT/_snapshot/$1" | jq 'has("'$1'")')
    if [ $res = "true" ] 
    then
        echo "repo found: $1"
        return 0
    else
        echo "ERROR: could not find repo: $1"
        return 1
    fi
}

checkSnapshotState()
{
    curl -X GET "elasticsearch:9200/_snapshot/$REPO/_current/_status?pretty" > respondState.json
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

decrypt()
{
    if [ -e /var/nfs/backup-$1.tar.gz.gpg ] 
    then
        gpg --batch --quiet --passphrase $PASSWORD -o backup-$1.tar.gz -d backup-$1.tar.gz.gpg && rm backup-$1.tar.gz.gpg
        
        if [ $? -ne 0 ]; then
            echo "Could not decrypt: backup-$1.tar.gz.gpg"
        else
            echo "file decrypted: backup-$1.tar.gz.gpg "
        fi
        tar -xzf backup-$1.tar.gz && rm backup-$1.tar.gz
        
    else
        echo "Error:  Could not find file backup-$1.tar.gz.glspg to decrypt"
    fi

}

encrypt()
{
    tar -czf backup-$1.tar.gz $1 && rm -R $1
    gpg --batch --quiet --passphrase $PASSWORD --symmetric --cipher-algo AES256 backup-$1.tar.gz && rm backup-$1.tar.gz
    if [ $? -ne 0 ]; then
        echo "Could not encrypt: $1"
    else
        echo "folder encrypted: $1"
    fi
}

cd /var/nfs/

if [ "backup" = $STATE ]; then
    echo "Running snapshot cmd..."
    
    checkRepo $REPO
    if [ $? -ne 0 ]
    then
        makeRepo $REPO
        if [ $? -ne 0 ]
        then
            exit 1
        fi
    fi

    if [ "true" = $ENCRYPTION ]
    then
        decrypt $SEARCH_PATH
    fi
    
    curator --config /config/config.yaml /config/backup.yaml

    if [ $? -eq 0 ]
    then
        echo "backup success"
        if [ "true" = $ENCRYPTION ]
        then
            encrypt $SEARCH_PATH
        fi
        exit 0
    else
        echo "backup failed"
        if [ "true" = $ENCRYPTION ]
        then
            encrypt $SEARCH_PATH
        fi
        exit 1
    fi
fi

if [ "restore" = $STATE ]; then

    echo "Running Restore cmd..."

    checkRepo $REPO
    if [ $? -ne 0 ]
    then
        exit 1
    fi

    if [ "true" = $ENCRYPTION ]
    then
        decrypt $SEARCH_PATH
    fi

    curator --config /config/config.yaml /config/restore.yaml

    if [ $? -eq 0 ]
    then
        echo "Restore success"
        if [ "true" = $ENCRYPTION ]
        then
            encrypt $SEARCH_PATH
        fi
        exit 0
    else
        echo "restore failed, re-encrypt logs"
        if [ "true" = $ENCRYPTION ]
        then
            encrypt $SEARCH_PATH
        fi
        exit 1
    fi

fi

echo " invalid ENV STATE must be set to backup or restore"
exit 1