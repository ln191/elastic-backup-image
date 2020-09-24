#!/bin/sh

# functions
    # curator check repo
    # check there is a log 
# decrypt
decrypt()
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
encrypt()
{ 
    # find files to be encrypted
    ls /var/nfs/$search_path | grep -v \\.asc  > ../tempList.txt
    #encrypt indies folder content
    while read in 
    do 
        # sync encryption
        gpg --batch -c --passphrase $PASSWORD --armor --symmetric --cipher-algo AES256 $in; 
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

# wait for status
cd /var/nfs/$search_path

if [ "backup" = $STATE ]; then
    echo "Running backup cmd..."
    
    # check encryption log file if none create one
    decrypt

    # Run curator backup cmd
        # check repo exist if not create
    
    curator --config config.yaml backup.yaml
    if [ $? -ne 0 ]; then
        echo "Back up not created"
    fi
        # sent snapshot cmd

    # wait for status succesfull or error
        # timeout error if to long

        # if error exit with error

    encrypt
    # # if no errors exit succesfull

    echo 'Successfully backup of elastic logs'
    exit 0
fi

if [ "restore" = $STATE ]; then

    echo "Running Restore cmd..."

    # check repo connection if error exit with error

    # Check log file
    # decrypt files in log
    decrypt
    # curator send restore cmd
    curator --config config.yaml restore.yaml
    if [ $? -ne 0 ]; then
        echo "Back up not created, check db connection settings"
        exit 1
    fi
    # wait for status 

    # encrypt files in indies folder
    encrypt
    # if status succesfull exit succesfull else error exit

    exit 0

fi

echo " invalid command STATE ENV must be set to backup or restore"
exit 1