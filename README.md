# MariaDB Backup Script
A simple shell script, to create bzipped backups of MariaDB databases. Also works with MySQL if the MariaDB specific commands are swapped for their MySQL equivalents.

Generates a hash of the latest existing backup, and only stores a new backup if the new backup has a different hash. This ensures duplicate backups are not retained.

Includes a version to store local backups, and a version to store backups both locally and on a remote machine.

## Usage

To run either script, a valid database user and credential file must be provided.

By default, the scripts contain a hard-coded list of system databases, which are ignored. Edit this list to exclude/include additional databases.

### Remote Backup Usage:
backup-remote.sh -a credential_file -u database_user -r user@remote -o remote_server_output_directory -l local_output_directory

To allow files to be copied to a remote server, the server must be configured to allow passwordless ssh from the backup machine.

If the backup cannot be copied to the server, it will be retained in /tmp/db-backups, and the script will attempt to copy the file on the next run. Otherwise, it will be moved to the specified local directory.

### Local Backup Usage:
backup.sh -a credential_file -u database_user -o local_output_directory

Similar to the remote backup script, but with remote-specific options omitted.
