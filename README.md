# Mysql Backup Scrit
A simple shell script, to create bzipped backups of mysql/mariadb databases.

Only backups with changes are retained, to save space.


## Usage:
backup.sh -u user -a credential_file -o outdir

To run this script, a valid database user and credential file must be provided.

By default, the script contains a hard-coded list of system databases, which are ignored. Edit this list to exclude/include additional databases.
