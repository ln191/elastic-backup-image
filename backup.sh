#!/bin/bash

date=$(date +'%Y-%m-%d')

rep="$REPO-$date"

customeBackup="false"

selectRepo(){
    if [ -z "$DATE" ]
    then
        echo "Repo selected: $rep"
    else
        rep="$REPO-$DATE"
        date=$DATE
        customeBackup="true"
        echo "Repo selected: $rep"
    fi
    
}

deleteRepo(){
     curl -X DELETE "$ELASTIC_HOST:$PORT/_snapshot/$1" > respondState.json 

    res=$( cat respondState.json | jq ".acknowledged" )
    echo $res
    if [ "true" = $res ]
    then
        echo "repo deleted: $1"
        return 0
    else
        echo "ERROR: could not delete repo: $1"
        return 1
    fi
}
makeRepo()
{
    curl -X PUT "$ELASTIC_HOST:$PORT/_snapshot/$1?pretty" -H 'Content-Type: application/json' -d' { "type": "fs","settings": { "compress": "true", "location": "'$1'" } }' > respondState.json 

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
    if [ -e /var/nfs/$2/backup-$1.tar.gz.gpg ] 
    then
        gpg --batch --quiet --passphrase $PASSWORD -o $2/backup-$1.tar.gz -d $2/backup-$1.tar.gz.gpg && rm $2/backup-$1.tar.gz.gpg
        
        if [ $? -ne 0 ]; then
            echo "Could not decrypt: backup-$1.tar.gz.gpg"
        else
            echo "file decrypted: backup-$1.tar.gz.gpg "
        fi
        tar -xzf $2/backup-$1.tar.gz && rm $2/backup-$1.tar.gz
        
    else
        echo "Error:  Could not find file backup-$1.tar.gz.glspg to decrypt"
    fi

}

encrypt()
{
    tar -czf $2/backup-$1.tar.gz $2/$1 && rm -R $2/$1
    gpg --batch --quiet --passphrase $PASSWORD --symmetric --cipher-algo AES256 $2/backup-$1.tar.gz && rm $2/backup-$1.tar.gz
    if [ $? -ne 0 ]; then
        echo "Could not encrypt: $1"
    else
        echo "folder encrypted: $1"
    fi
}

restore()
{

    cp /config/restore.yaml currentRestore.yaml
    sed -r "s/^(\s*repository\s*:\s*).*/\1$1/" -i currentRestore.yaml
    sed -r "s/^(\s*name\s*:\s*).*/\1/" -i currentRestore.yaml

    if [ "true" = $ENCRYPTION ]
    then
        decrypt $SEARCH_PATH $1
    fi

    curator --config /config/config.yaml currentRestore.yaml

    if [ $? -eq 0 ] 
    then
        echo "Restore success"
        if [ "true" = $ENCRYPTION ]
        then
            encrypt $SEARCH_PATH $1
        fi 
    else
        echo "restore failed, re-encrypt logs"
        if [ "true" = $ENCRYPTION ]
        then
            encrypt $SEARCH_PATH $1
        fi
    fi

    rm currentRestore.yaml
}

restoreList()
{
    IFS=',' read -ra ary <<< $1
    for i in "${ary[@]}"
    do
        echo $i
        checkRepo $i
        if [ $? -ne 0 ]
        then
            makeRepo $i
            if [ $? -ne 0 ]
            then
                exit 1
            fi
        fi
        
        restore "$REPO-$i"
    done
}

restoreRange()
{
    IFS='>' read -ra ary <<< $1
    d=$(date -d ${ary[0]} +%s)
    enddate=$(date -d ${ary[1]} +%s)
    #change dates to second
    while [ $d -le ${enddate} ]; do 
        echo $d
        df=$(date -d @$d +%Y-%m-%d)
        echo $df
        checkRepo "$REPO-$df"
        if [ $? -ne 0 ]
        then
            makeRepo "$REPO-$df"
            if [ $? -ne 0 ]
            then
                exit 1
            fi
        fi
        
        restore "$REPO-$df"
        d=$(( $d + 86400 ))
        #Unix timestamp don't include leap seconds, so 1 day equals always exactly 86400 seconds.
    done
}
restoreRangeOrList()
{
   tmp=$(echo $RESTOREINDICES | grep '>' )
   echo $tmp
   if [ -z $tmp ];then
      echo "is list"
      restoreList $RESTOREINDICES
   else
      echo "is range"
      restoreRange $RESTOREINDICES
   fi
}

delete()
{
    if [ "true" = $DELETEOLDBACKUPS ]; then
        echo 'Delete backups older than '$OLDERTHAN' days'
        find /var/nfs/* -type d -mtime +$OLDERTHAN -print -exec rm -rf {} \;
        current=$(date +%s)
        older=$((86400 * $OLDERTHAN))
        old=$(( $current - $older ))
        echo "delete repo: $(date -d @$old +%Y-%m-%d)"
        deleteRepo "$REPO-$(date -d @$old +%Y-%m-%d)" 
    fi
}

cd /var/nfs/

if [ "backup" = $STATE ]; then
    echo "Running snapshot cmd..."
    selectRepo
    checkRepo $rep
    if [ $? -ne 0 ]
    then
        mkdir "$rep" && chmod -R 777 "$rep"/
        makeRepo $rep
        if [ $? -ne 0 ]
        then
            exit 1
        fi
    fi
    
    if [ "true" = $ENCRYPTION ]
    then
        decrypt $SEARCH_PATH $rep
    fi
    if [ "true" = $customeBackup ]
    then
        cp /config/customeBackup.yaml currentBackup.yaml

        sed -r "s/^(\s*repository\s*:\s*).*/\1$rep/" -i currentBackup.yaml
        sed -r "s/^(\s*name\s*:\s*).*/\1$rep/" -i currentBackup.yaml
        sed -r "s/customeDate/-$DATE/" -i currentBackup.yaml
        
        curator --config /config/config.yaml currentBackup.yaml

        rm currentBackup.yaml
    else
        cp /config/backup.yaml currentBackup.yaml

        sed -r "s/^(\s*repository\s*:\s*).*/\1$rep/" -i currentBackup.yaml

        curator --config /config/config.yaml currentBackup.yaml

        rm currentBackup.yaml
    fi

    if [ $? -eq 0 ]
    then
        echo "backup success"
        delete 
        
        if [ "true" = $ENCRYPTION ]
        then
            encrypt $SEARCH_PATH $rep
        fi
         
        exit 0
    else
        echo "backup failed"
        if [ "true" = $ENCRYPTION ]
        then
            encrypt $SEARCH_PATH $rep
        fi
        exit 1
    fi
fi

if [ "restore" = $STATE ]; then

    echo "Running Restore cmd..."

    restoreRangeOrList
    
    exit 0
fi

echo " invalid ENV STATE must be set to backup or restore"
exit 1