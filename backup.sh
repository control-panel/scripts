#!/bin/bash

# Backup script
# Created by **** 21.11.2013
# Last edited by **** 10.10.2016
# Version: beta6
#
# Script for creating backup of certain dirs and logical backup of DBs in MySQL RDBMS
# And also for delivering backups to remote backup server via sshfs.
# Use it within cron, and setup email notification by means of cron to be able to check work of the script
#


#################
## Config section
#################

SCRIPTNAME="backup.sh"
HOSTNAME="$(hostname)"
TIMESTAMP=$(date +"%F")

PATH_BACKUP_ROOT="/media/backup_server"

PATH_BACKUP="$PATH_BACKUP_ROOT/backup"
PATH_BACKUP_CURR="$PATH_BACKUP/$TIMESTAMP"

# List of dirs to backup:
DIRS2BACKUP="/etc /root /home /var/lib"
# List of databases to backup:
DB2BACKUP="db1 db2 db3"

# backups time to live in days:
BACKUP_TTL="10"

# Prog used to create backup:
MYSQLDUMP=/usr/bin/mysqldump

# List of admins of server:
MAILTO="admin1@dom.com admin2@dom.com"

LOG_FILE="/var/log/backupper.log"

LOCK_FILE="/var/run/backup.lock"

########################
## End of config section
########################

####################
## Functions section:
####################

# Exit function. Hooks "exit" call through this script
do_exit() {
    RETURN_VALUE=$?

    rm -f "$LOCK_FILE"
    exit $RETURN_VALUE
}

# Check if script is already running
check_run() {
    if [ -f "$LOCK_FILE" ]; then
    echo -e "n\The process is already running"
    exit 1
    fi

    touch "$LOCK_FILE"
    # hooks standart built-in exit function in this script, and executes do_exit function instead
    trap do_exit EXIT
}

# email notification function, uses "ssmtp" as mail transfer:
function send_fail_mail(){
    mailto="$1"
    msg="$2"
    for dude in $mailto; do
	ssmtp -F"$SCRIPTNAME@$HOSTNAME" "$dude" <<< "$msg"
    done
    return 0
}

###########################
## End of functions section
###########################

###############
## Main section:
###############

# check if script is running:
check_run

# try safely unmount remote dir which stores backup:
umount -l $PATH_BACKUP_ROOT &>/dev/null

# try to mount this dir where to store backup:
mount $PATH_BACKUP_ROOT

if [ $? -eq 0 ]
then
    # delete old backups:
    cd $PATH_BACKUP
    currdir=`pwd`
    if [ "$currdir"="$PATH_BACKUP" ]; then
    find ./ -not -path "*/\.*" -mtime +"$BACKUP_TTL" -exec rm -rf {} + | tee -a $LOG_FILE
    else
    echo "Cannot change directory to backup dir!" | tee -a $LOG_FILE
    exit 1
    fi
    mkdir -p $PATH_BACKUP_CURR

    # performing backup:
    for i in $DIRS2BACKUP; do
    # need to replace "/" in dst filename
    j=${i//\//_}
    tar czf "$PATH_BACKUP_CURR/dir_$j.tar.gz" $i | tee -a $LOG_FILE
    if [ $? -eq 0 ]
    then
        echo "`date` : Directory $i successfully backuped" | tee -a $LOG_FILE
    else
        echo "`date` : Directory $i backup failed" | tee -a $LOG_FILE
        send_fail_mail "$MAILTO" "Directory $i backup failed"
    fi
    done
    for db in $DB2BACKUP; do 
	$MYSQLDUMP --defaults-file=/etc/mysql/debian.cnf --force --opt --max-allowed-packet=1G --databases $db | gzip > "$PATH_BACKUP_CURR/db_$db.sql.gz"
    if [ $? -eq 0 ]
    then
        echo "`date` : Database $db successfully backuped" | tee -a $LOG_FILE
    else
        echo "`date` : Database $db backup failed" | tee -a $LOG_FILE
        send_fail_mail "$MAILTO" "Database $db backup failed"
    fi
    done
    ls -l $PATH_BACKUP_CURR
    ls -l $PATH_BACKUP
    umount -l $PATH_BACKUP_ROOT
    echo "$(date) - backup succesfully done" | tee -a $LOG_FILE
else
    echo "Can not mount remote dir on backup server" | tee -a $LOG_FILE
    send_fail_mail "$MAILTO" "Can not mount remote dir on backup server"
    exit 1
fi

exit 0
