#!/bin/bash

errorHandling() 
{
    printf "${textBold}${textRED}Errors occurred while executing the script.${textNormal}${textNC}\n"
    printf "${textBold}${textRED}The execution was terminated.${textNormal}${textNC}\n"
    exit 1;
}

# Load colors
textRED='\033[0;31m'
textGREEN='\033[0;32m'
textYELLOW='\033[1;33m'
textNC='\033[0m' # No Color
textBold=$(tput bold)
textNormal=$(tput sgr0)

# Script init
printf "${textRED}${textBold}Replicate-script version 1.0${textNC}\n" 
printf "${textRED}${textBold}Created by Caio Mendonca https://cmconsultor.com.br / https://github.com/caiomendonca${textNC}\n"
printf "${textRED}${textBold}This script is a user-friendly interface to copy directory and database remote to local using ssh-rsync with sudo, mysql-client and postgresql-client.${textNC}\n" 
printf "${textRED}${textBold}It was made for my personal use for sync my production env with test env and there are no guarantees when using it. Use it at your own risk.${textNC}\n"
printf "${textRED}${textBold}WARNING: This script will overwrite local files and databases with the remote server data. Don't use in production host.${textNC}\n"

# install dependencies
case $(grep "^ID=" /etc/os-release | sed -E 's/ID=(.*)/\1/') in
    ubuntu|debian)
    sudo apt update || errorHandling
    sudo apt install mysql-client postgresql-client rsync -y || errorHandling ;;
    arch) echo "You linux distribution is not covered for now." && exit ;;
    fedora) echo "You linux distribution is not covered for now." && exit ;;
    almalinux) echo "You linux distribution is not covered for now." && exit ;;
    rhel) echo "You linux distribution is not covered for now." && exit ;;
    *) echo "You linux distribution is not covered." && exit ;;
esac

# copy /etc files
sudo mkdir -p /etc/cm-scripts/replicate-script/
sudo mv /etc/cm-scripts/replicate-script/default.conf /etc/cm-scripts/replicate-script/default-$(date -u +"%FT%H%M%S").conf.bak 2> /dev/null
sudo cp $PWD/etc/cm-scripts/replicate-script/default.conf /etc/cm-scripts/replicate-script/

# copy script to /bin
sudo cp $PWD/bin/replicate-script.sh /bin/replicate-script
sudo chmod +x /bin/replicate-script

# edit defaults.conf
while true; do
    read -p "Do you want to edit your local database credentials now? (Y/N)" yn
    case $yn in
        [Yy]* )
            read -p "Choose a text editor to change the file (ex: vi, vim, nano): " TEXT_EDITOR
            $TEXT_EDITOR /etc/cm-scripts/replicate-script/default.conf            
            echo "To run the script use the "replicate-script" command"
            printf "${textNormal}${textGREEN}If you need change local database settings, you can do it in /etc/cm-scripts/replicate-script/default.conf.${textNC}\n"
            echo "Execution finished";
            break;;
        [Nn]* ) 
            printf "${textNormal}${textGREEN}Execution finished, please change the /etc/cm-scripts/replicate-script/default.conf file with your database credentials.${textNC}\n"
            echo "To run the script use the "replicate-script" command";
            exit;;
        * ) echo "Please answer yes or no.";;
    esac
done
