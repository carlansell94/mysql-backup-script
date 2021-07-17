#!/bin/bash

SYS_DBS=(information_schema performance_schema mysql phpmyadmin)

function get_last_file() {
	unset matched_files

	for entry in $OUTPUT_FOLDER/*
	do
		file=${entry##*/}

		if [[ ${file%-*} == $1 ]]; then
			matched_files+=( $entry )
			result=$(sha1sum $entry)
		fi
	done

	for file in ${matched_files[@]}; do
		[[ $file -nt $latest ]] && latest=$file
	done

	echo $(sha1sum $file | cut -f 1 -d " ")
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

	if [[ -z $OUTPUT_FOLDER ]]; then
		echo "Missing flag -o: output folder"
		exit 1
	fi
}


function usage {
	echo "usage: $programname [-h] [-u user] [-a authfile] [-o outdir]"
	echo "  -h             display help"
	echo "  -u user        specify the database username"
	echo "  -a authfile    specify the path to the mysql/mariadb auth file"
	echo "  -o outdir      specify the path to output the backup files"
	exit 1
}


while getopts 'a:vu:ve:vo:vh' flag; do
	case "${flag}" in
		a) DB_AUTH_FILE="${OPTARG}" ;;
		u) DB_USER="${OPTARG}" ;;
		o) OUTPUT_FOLDER="${OPTARG}" ;;
		h) usage
		exit 0 ;;
	esac
done

check=$(check_flags)

if [[ -n $check ]]; then 
	echo $check
	exit 1
fi

databases=$(mysql --defaults-extra-file=$DB_AUTH_FILE -u $DB_USER -e "SHOW DATABASES;" | tr -d "| " | grep -v Database) || exit 1

for db in $databases; do
	if ! echo ${SYS_DBS[@]} | grep -q -w "$db"; then
		echo "Checking database '"$db"'"

		echo "  - Getting last hash" 
		old_hash=$(get_last_file $db)

		echo "  - Creating new backup"
		mysqldump --defaults-extra-file=$DB_AUTH_FILE --compact -u $DB_USER $db | bzip2 -9 > /tmp/$db-`date +"%y%m%d"`.sql.bzip2
		new_hash=$(sha1sum /tmp/$db-`date +"%y%m%d"`.sql.bzip2 | cut -f 1 -d " ")

		echo "  - Comparing new hash with last hash"
		if [[ $old_hash != $new_hash ]]; then
			echo "  - Hashes are different, new backup of database" $db "saved"
		    mv /tmp/$db-`date +"%y%m%d"`.sql.bzip2 $OUTPUT_FOLDER
		else
			echo "  - Hashes match, new backup discarded"
		fi

		echo -e "\n"
	fi
done
