#!/bin/bash

SYS_DBS=(information_schema performance_schema mysql phpmyadmin sys)

function get_last_remote_file() {
    db=$1
    last_remote_backup_file=$(ssh "$REMOTE_LOGIN" "ls -1 \"$OUTPUT_FOLDER/${db}\"-* 2>/dev/null | sort -r | head -n 1 || true")

    if [ -n "$last_remote_backup_file" ]; then
        ssh "$REMOTE_LOGIN" "sha1sum \"$last_remote_backup_file\" | awk '{print \$1}'"
    else
        echo ""
    fi
}


function check_flags() {
        if [[ -z $DB_AUTH_FILE ]]; then
                echo "Missing flag -a: database auth file";
                exit 1
        fi

        if [[ -z $DB_USER ]]; then
                echo "Missing flag -u: database user";
                exit 1
        fi

        if [[ -z $LOCAL_FOLDER ]]; then
                echo "Missing flag -l: local folder"
                exit 1
        fi

        if [[ -z $OUTPUT_FOLDER ]]; then
                echo "Missing flag -o: output folder"
                exit 1
        fi

        if [[ -z $REMOTE_LOGIN ]]; then
                echo "Missing flag -r: remote login details"
                exit 1
        fi
}


function usage {
        echo "usage: ${0##*/} [-h] [-u user] [-a authfile] [-o outdir]"
        echo "  -h             display help"
        echo "  -u user        specify the database username"
        echo "  -a authfile    specify the path to the mysql/mariadb auth file"
        echo "  -l localdir    specify a local path to output a local copy of the backup files"
        echo "  -r remote      provide the ssh@ip address for the remote server"
        echo "  -o outdir      specify the path to output the backup files on the remote server"
        exit 1
}


while getopts 'a:u:o:l:r:h' flag; do
        case "${flag}" in
                a) DB_AUTH_FILE="${OPTARG}" ;;
                u) DB_USER="${OPTARG}" ;;
                l) LOCAL_FOLDER="${OPTARG}" ;;
                r) REMOTE_LOGIN="${OPTARG}" ;;
                o) OUTPUT_FOLDER="${OPTARG}" ;;
                *) usage
        esac
done

check=$(check_flags)

if [[ -n $check ]]; then
        echo "$check"
        exit 1
fi

databases=$(mariadb --defaults-extra-file="$DB_AUTH_FILE" -u "$DB_USER" -e "SHOW DATABASES;" | tr -d "| " | grep -v Database) || exit 1
mkdir -p /tmp/db-backups

for db in $databases; do
        if ! echo "${SYS_DBS[@]}" | grep -q -w "$db"; then
                echo "Checking database $db"

                echo "  - Getting last hash"
                old_hash=$(get_last_remote_file "$db")

                echo "  - Creating new backup"
                mariadb-dump --defaults-extra-file="$DB_AUTH_FILE" --single-transaction --compact -u "$DB_USER" "$db" | bzip2 -9 > /tmp/db-backups/"$db"-"$(date +"%y%m%d")".sql.bzip2
                new_hash=$(sha1sum /tmp/db-backups/"$db"-"$(date +"%y%m%d")".sql.bzip2 | cut -f 1 -d " ")

                echo "  - Comparing new hash with last hash"
                if [[ $old_hash != "$new_hash" ]]; then
                        echo "  - Hashes are different, new backup of database" "$db" "saved"
                else
                        echo "  - Hashes match, new backup discarded"
                        rm /tmp/db-backups/"$db"-"$(date +"%y%m%d")".sql.bzip2
                fi

                echo -e "\n"
        fi
done

if [ "$(ls -A /tmp/db-backups)" ]; then
    echo "New backup files exist, attempting to copy files to the remote backup server"
    scp -q /tmp/db-backups/* "$REMOTE_LOGIN:$OUTPUT_FOLDER/"

    if [ $? -eq 0 ]; then
        mkdir -p "$LOCAL_FOLDER"
        mv /tmp/db-backups/* "$LOCAL_FOLDER"
        echo "  - Network copy successful, local copies moved to" "$LOCAL_FOLDER"
    else
        echo "  - Network copy failed, backup will remain in /tmp/db-backups for processing on next run"
    fi
else
    echo "No new backups available to copy"
fi
