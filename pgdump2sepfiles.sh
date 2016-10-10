#!/bin/bash

BACKUP_ROOT="/srv/local_backup/postgresql"
TIMESTAMP=$(date +"%F")
BACKUP_DIR="$BACKUP_ROOT/$TIMESTAMP/"

BACKUP_TTL=2

mkdir -p $BACKUP_DIR
cd $BACKUP_DIR

dblist=`sudo -u postgres psql -l | awk '{ print $1 }' |grep -vE '(^-|Name|List|^template(0|1)|postgres|\||^\(|^$)'`

# do backup of each database in cycle:
for db in $dblist
do
  sudo -u postgres pg_dump -C -b "$db" | gzip -c > "$BACKUP_DIR/$db.sql.gz"
    echo "Database '$db' backed up"
done

# delete old dumps:
cd $BACKUP_ROOT
find ./ -type d -mtime +"$BACKUP_TTL" -exec rm -rf {} +

ls -l $BACKUP_ROOT
ls -l $BACKUP_DIR


exit 0
