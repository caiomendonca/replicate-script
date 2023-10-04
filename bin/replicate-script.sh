#!/bin/bash

helpFunction()
{
   printf "${textBold}Example for sync directory: ${textNormal}${textGREEN}$0 -s /path/directory/to/sync -k /path/to/ssh/key -l ubuntu -h server.hostname ${textNC}\n"
   printf "${textBold}Example for sync database: ${textNormal}${textGREEN}$0 -e pgsql -h database.host -d database.name -u database.user -a default.conf ${textNC}\n"
   printf "${textBold}Example for sync directory and database: ${textNormal}${textGREEN}$0 -e pgsql -h database.host -d database.name -u database.user -f rsync.host ${textNC}\n"
   echo ""
   printf "${textBold}Available parameters: ${textNormal}\n"
   echo -e "\t-s Specify directory remote to copy for the same path on local host. Required for sync directory"
   echo -e "\t-e Speficy database type (available: pgsql mysql). Required for sync database"
   echo -e "\t-h Specify the remote host for database dump. Required for sync database"
   echo -e "\t-d Specify the remote host database name. Required for sync database"
   echo -e "\t-u Specify the remote host database user. Required for sync database "
   echo -e "\t-i Specify the remote host database port. Optional but if not defined, will use 3306 for mysql and 5432 for pgsql"
   echo -e "\t-k Specify ssh key path ex: /path/to/ssh/key. Required for sync directory"
   echo -e "\t-l Specify ssh user. Required for sync directory"
   echo -e "\t-f Used to specify a different host for rsync files. When defining -h and -i in the same command, -h host will be used for database dump and -i host for directory synchronization. Optional"
   echo -e "\t-a Used to specify a different local database configuration file. If not defined, the script will use the /etc file as default. Optional "
   exit 1 # Exit script after printing help
}

errorHandling() 
{
    rm -rf $HOME/job-$JOB_ID
    printf "${textBold}${textRED}Errors occurred while executing the script.${textNormal}${textNC}\n"
    printf "${textBold}${textRED}The execution was terminated.${textNormal}${textNC}\n"
    exit 1;
}

pgsqlFunction()
{
    # Check if the required parameters are filled in
    if [ -z $REMOTE_DB_HOST ] || [ -z $REMOTE_DB_NAME ] || [ -z $REMOTE_DB_USER ]; then
        printf "${textBold}${textYELLOW}WARNING: Some required database backup parameter is empty (-h, -p, -u, -e). Ignore this message if you don't prentend to copy database.${textNormal}${textNC}\n"
        
    else
        while true; do
            printf "${textBold}${textYELLOW}The database will be dump in $HOME, make sure you have enough disk space.${textNormal}${textNC}\n"
            read -p "This will overwrite your local Postgres SQL database $REMOTE_DB_NAME with the remote server data. Do you want to continue (Y/N)" yn
            case $yn in
                [Yy]* )
                read -s -p "Remote Postgres SQL password: " REMOTE_DB_PASSWORD
                echo ""
                # load defaults in config file
                source $LOCAL_DB_FILE
                # backup database to home dir
                mkdir -p $HOME/job-$JOB_ID
                echo "Dumping Postgres SQL "$REMOTE_DB_NAME" database from $REMOTE_DB_HOST.."
                #pg_dumpall --globals-only --dbname=postgresql://$REMOTE_DB_USER:$REMOTE_DB_PASSWORD@$REMOTE_DB_HOST:$REMOTE_DB_PORT/postgres > $HOME/job-$JOB_ID/postgres_all_roles_and_users.sql || errorHandling
                PGPASSWORD=$REMOTE_DB_PASSWORD pg_dump -Fd --host=$REMOTE_DB_HOST --port=$REMOTE_DB_PORT --username=$REMOTE_DB_USER --dbname=$REMOTE_DB_NAME -f $HOME/job-$JOB_ID/$REMOTE_DB_NAME.dump || errorHandling
                echo "Database dumped on $HOME/job-$JOB_ID/$REMOTE_DB_NAME.dump temporaly"
                # recovery to local database
                echo "Recovering "$REMOTE_DB_NAME" database to local Postgres SQL Server ($LOCAL_DB_PGSQL_HOST).."
                #PGPASSWORD=$LOCAL_DB_PGSQL_PASSWORD psql -h $LOCAL_DB_PGSQL_HOST -p $LOCAL_DB_PGSQL_PORT -U $LOCAL_DB_PGSQL_USER -f $HOME/job-$JOB_ID/postgres_all_roles_and_users.sql || errorHandling
                PGPASSWORD=$LOCAL_DB_PGSQL_PASSWORD psql -h $LOCAL_DB_PGSQL_HOST -p $LOCAL_DB_PGSQL_PORT -U $LOCAL_DB_PGSQL_USER -tc "SELECT 1 FROM pg_database WHERE datname = '$REMOTE_DB_NAME'" | grep -q 1 | PGPASSWORD=$LOCAL_DB_PGSQL_PASSWORD psql -h $LOCAL_DB_PGSQL_HOST -p $LOCAL_DB_PGSQL_PORT -U $LOCAL_DB_PGSQL_USER -c "CREATE DATABASE $REMOTE_DB_NAME" || echo "Skipping CREATE DATABASE process.."; #|| errorHandling
                PGPASSWORD=$LOCAL_DB_PGSQL_PASSWORD pg_restore --clean -h $LOCAL_DB_PGSQL_HOST -p $LOCAL_DB_PGSQL_PORT -U $LOCAL_DB_PGSQL_USER -d $REMOTE_DB_NAME $HOME/job-$JOB_ID/$REMOTE_DB_NAME.dump || errorHandling
                # delete backuped files
                echo "Deleting dump files on $HOME/job-$JOB_ID.."
                rm -rf $HOME/job-$JOB_ID;
                echo "Dump files deleted"
                printf "${textBold}${textGREEN}Postgres database "$REMOTE_DB_NAME" on $REMOTE_DB_HOST restored to local server ($LOCAL_DB_PGSQL_HOST).${textNormal}${textNC}\n"
                break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
}

mysqlFunction()
{
    # Check if the required parameters are filled in
    if [ -z $REMOTE_DB_HOST ] || [ -z $REMOTE_DB_NAME ] || [ -z $REMOTE_DB_USER ]; then
        printf "${textBold}${textYELLOW}WARNING: Some required database backup parameter is empty (-h, -p, -u, -e). Ignore this message if you don't prentend to copy database.${textNormal}${textNC}\n"
    else
        while true; do
            printf "${textBold}${textYELLOW}The database will be dump in $HOME, make sure you have enough disk space.${textNormal}${textNC}\n"
            read -p "This will overwrite your local MySQL database "$REMOTE_DB_NAME" with the remote server data. Do you want to continue (Y/N)" yn
            case $yn in
                [Yy]* )
                read -s -p "Remote MySQL password: " REMOTE_DB_PASSWORD
                echo ""
                # load defaults in config file
                source $LOCAL_DB_FILE
                # backup database to home dir
                mkdir -p $HOME/job-$JOB_ID
                # backup database to home dir
                #echo "dumping mysql users and roles.."
                echo "Dumping MySQL "$REMOTE_DB_NAME" database from $REMOTE_DB_HOST.."
                mysqldump --column-statistics=0 -h $REMOTE_DB_HOST -u $REMOTE_DB_USER -p$REMOTE_DB_PASSWORD --port=${REMOTE_DB_PORT} $REMOTE_DB_NAME > $HOME/job-$JOB_ID/$REMOTE_DB_NAME.sql || errorHandling
                echo "Database dumped on $HOME/job-$JOB_ID/$REMOTE_DB_NAME.sql temporaly"
                echo "Recovering "$REMOTE_DB_NAME" database to local MySQL Server ($LOCAL_DB_MYSQL_HOST).."
                #mysql -h $LOCAL_DB_MYSQL_HOST -u $LOCAL_DB_MYSQL_USER -p$LOCAL_DB_MYSQL_PASSWORD -e "DROP DATABASE $REMOTE_DB_NAME"
                mysql -h $LOCAL_DB_MYSQL_HOST -u $LOCAL_DB_MYSQL_USER -p$LOCAL_DB_MYSQL_PASSWORD -e "CREATE DATABASE IF NOT EXISTS $REMOTE_DB_NAME" || errorHandling
                mysql -h $LOCAL_DB_MYSQL_HOST -u $LOCAL_DB_MYSQL_USER -p$LOCAL_DB_MYSQL_PASSWORD $REMOTE_DB_NAME < $HOME/job-$JOB_ID/$REMOTE_DB_NAME.sql || errorHandling
                # delete backuped files
                echo "Deleting dump files on $HOME/job-$JOB_ID.."
                rm -rf $HOME/job-$JOB_ID;
                printf "${textBold}${textGREEN}MySQL database "$REMOTE_DB_NAME" on $REMOTE_DB_HOST restored to local server ($LOCAL_DB_MYSQL_HOST).${textNormal}${textNC}\n"
                break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi

}

dataSyncFunction() # falta fazer
{
    # Verify if custom host for rsync
    if [ -z $SSH_HOST ]; then
        SSH_HOST=$REMOTE_DB_HOST
    fi
    if [ -z $SSH_KEY ] || [ -z $SSH_USER ] || [ -z $SSH_HOST ] || [ -z $REMOTE_DIR ]; then
        echo "Directory synchronization was skipped because there were not enough arguments to perform rsync. Required parameters -k -h -l -s"
    else
        while true; do
            read -p "This will overwrite the local $REMOTE_DIR with the $SSH_HOST data. Do you want to continue (Y/N)" yn
            case $yn in
                [Yy]* )
                echo "Syncing $REMOTE_DIR local with $REMOTE_DIR on $SSH_HOST"
                # Directory split
                LOCAL_DIR=$( echo ${REMOTE_DIR%/*} )
                file=$( echo ${REMOTE_DIR##*/} )
                mkdir -p $LOCAL_DIR
                # Sync directory remote to local
                # Script will rsync with user input password
                read -s -p "Remote sudo password: " SUDOPASS && rsync -a -v -P --delete --stats --rsync-path="echo $SUDOPASS | sudo -Sv && sudo rsync" -e "ssh -i $SSH_KEY -y" $SSH_USER@$SSH_HOST:$REMOTE_DIR $LOCAL_DIR || errorHandling
                # Script will rsync with pre-defined password
                #rsync -a -v -P --delete --stats --rsync-path="echo $PASSWORD | sudo -Sv && sudo rsync" -e "ssh -i $SSH_KEY -y" $SSH_USER@$SSH_HOST:$REMOTE_DIR $LOCAL_DIR
                #printf "${textBold}${textGREEN}Directory $REMOTE_DIR on $SSH_HOST synced with local $REMOTE_DIR.${textNormal}${textNC}\n"
                printf "${textBold}${textGREEN}Directory $REMOTE_DIR local synced with $SSH_HOST data.${textNormal}${textNC}\n"
                break;;
                [Nn]* ) exit;;
                * ) echo "Please answer yes or no.";;
            esac
        done
    fi
}

while getopts "s:e:h:u:i:k:l:f:d:a:" opt
do
   case "$opt" in
      s ) parameterS="$OPTARG" ;;
      e ) parameterE="$OPTARG" ;;
      h ) parameterH="$OPTARG" ;;
      u ) parameterU="$OPTARG" ;;
      i ) parameterI="$OPTARG" ;;
      k ) parameterK="$OPTARG" ;;
      l ) parameterL="$OPTARG" ;;
      f ) parameterF="$OPTARG" ;;
      d ) parameterD="$OPTARG" ;;
      a ) parameterA="$OPTARG" ;; # new
      ? ) helpFunction ;; # Print helpFunction in case parameter is non-existent
   esac
done

# Load colors
textRED='\033[0;31m'
textGREEN='\033[0;32m'
textYELLOW='\033[1;33m'
textNC='\033[0m' # No Color
textBold=$(tput bold)
textNormal=$(tput sgr0)

# Print helpFunction in case parameters are empty
if [ -z "$parameterH" ]
then
    echo ""
    printf "${textBold}ERROR: Some required parameter is empty.\n \n"
    helpFunction
fi

# Script init
printf "${textRED}${textBold}Replicate-script version 1.0${textNC}\n" 
printf "${textRED}${textBold}Created by Caio Mendonca https://cmconsultor.com.br / https://github.com/caiomendonca${textNC}\n"
printf "${textRED}${textBold}This script is a user-friendly interface to copy directory and database remote to local using ssh-rsync with sudo, mysql-client and postgresql-client.${textNC}\n" 
printf "${textRED}${textBold}It was made for my personal use for sync my production env with test env and there are no guarantees when using it. Use it at your own risk.${textNC}\n"
printf "${textRED}${textBold}WARNING: This script will overwrite local files and databases with the remote server data. Don't use in production host.${textNC}\n"

# Load user put parameters
REMOTE_DB_TYPE=$parameterE
REMOTE_DB_HOST=$parameterH
REMOTE_DB_NAME=$parameterD
REMOTE_DB_USER=$parameterU
REMOTE_DB_PASSWORD=$parameterP
REMOTE_DB_PORT=$parameterI
REMOTE_DIR=$parameterS
SSH_KEY=$parameterK
SSH_USER=$parameterL
SSH_HOST=$parameterF
JOB_ID=$(date -u +"%FT%H%M%S")
LOCAL_DB_FILE_DIR=/etc/cm-scripts/replicate-script #new


# new
if  [ -z $parameterA ]; then
    LOCAL_DB_FILE=$LOCAL_DB_FILE_DIR/default.conf

else
    LOCAL_DB_FILE=$LOCAL_DB_FILE_DIR/$parameterA

fi

# start script execution
if  [ -z $REMOTE_DB_TYPE ]; then
    dataSyncFunction

elif [ $REMOTE_DB_TYPE = "pgsql" ]; then
    if [ -z "$REMOTE_DB_PORT" ]; then
        REMOTE_DB_PORT="5432"
    fi
    pgsqlFunction
    dataSyncFunction

elif [ $REMOTE_DB_TYPE = "mysql" ]; then
    if [ -z "$REMOTE_DB_PORT" ]; then
        REMOTE_DB_PORT="3306"
    fi
    mysqlFunction
    dataSyncFunction

else
    printf "${textBold}${textRED}Invalid database type, put mysql or pgsql.${textNormal}${textNC}\n"
fi