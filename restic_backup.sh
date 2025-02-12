#!/bin/bash
TODAY=$(date '+%Y-%m-%d-%H:%M:%S')

#Clear up old log files
echo "Clearing old log files."
/usr/bin/find /root/backup/logs/ -name "*.log" -mtime +30 -delete

# Check is lock file exists, if not create it and set trap on exit
if { set -C; 2>/dev/null >/tmp/restic_backup.lock; }; then
        trap "rm -f /tmp/restic_backup.lock" EXIT
else
        echo "Lock file exists, exiting."
        exit
fi

echo -e "\n-----"
echo "Backup started - ${TODAY}"
echo -e "-----"

#Set env vars
cd /root/backup/scripts
source ./restic.env

#Backup GitHub
bash ./github_mirror.sh
GIT_EXIT_CODE=$?
echo "github_mirror.sh exit code - ${GIT_EXIT_CODE}"

#Backup k3s
bash ./k3s_backup.sh
K3S_EXIT_CODE=$?
echo "k3s_backup.sh exit code - ${K3S_EXIT_CODE}"

# Run backup to Backblaze
echo "Starting backup to Backblaze."
echo "Backblaze backup:" >> /tmp/moria_backup_report_$TODAY
restic -r b2:$BUCKET_NAME:moria backup /data/backup /data/immich-data >> /tmp/moria_backup_report_$TODAY
BACKBLAZE_EXIT_CODE=$?
echo "Finished backup to Backblaze. Exit code ${BACKBLAZE_EXIT_CODE}"

#Run backup to external HDD if it's mounted
EXTERNAL_HDD_MOUNTED=$(mount | grep $EXTERNAL_HDD_PATH | wc -l)
EXTERNAL_HDD_EXIT_CODE=0
if [ $EXTERNAL_HDD_MOUNTED -eq 1 ]; then
	echo "External HDD is mounted. Starting backup to external HDD."
	echo "External HDD backup:" >> /tmp/moria_backup_report_$TODAY
	restic -r $EXTERNAL_HDD_PATH/backups/moria backup /data/backup /data/immich-data >> /tmp/moria_backup_report_$TODAY
	EXTERNAL_HDD_EXIT_CODE=$?
	echo "Finished backup to external HDD. Exit code ${EXTERNAL_HDD_EXIT_CODE}"
else
	echo "External HDD is not mounted."
fi

#Check if backup was successful or not
if [ $BACKBLAZE_EXIT_CODE -eq 0 ] && [ $EXTERNAL_HDD_EXIT_CODE -eq 0 ] && [ $GIT_EXIT_CODE -eq 0 ] && [ $K3S_EXIT_CODE -eq 0 ]; then
	# Notify
	curl -s \
	--form-string "token=${PUSHOVER_TOKEN}" \
	--form-string "user=${PUSHOVER_USER}" \
	--form-string "html=1" \
	--form-string "title=Backup successful" \
	--form-string "message=The backup was <b>successful</b>

	$(cat /tmp/moria_backup_report_$TODAY)" \
	https://api.pushover.net/1/messages.json
else
	# Notify
	curl -s \
	--form-string "token=${PUSHOVER_TOKEN}" \
	--form-string "user=${PUSHOVER_USER}" \
	--form-string "html=1" \
	--form-string "title=Backup unsuccessful" \
	--form-string "message=The backup was <b>unsuccessful</b>, please review the logs.

	$(cat /tmp/moria_backup_report_$TODAY)" \
	https://api.pushover.net/1/messages.json
fi

