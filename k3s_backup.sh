#!/bin/bash
BACKUP_DIR="/data/backup/k3s"

#Check paperless is up
PAPERLESS_READY=0
PAPERLESS_POD=$(kubectl -n paperless get pod | grep paperless | awk {'print $1'})
CIRCUIT_BREAKER=0
while [ $PAPERLESS_READY -eq 0 ] && [ $CIRCUIT_BREAKER -lt 12  ]
do
	PAPERLESS_STATUS=$(kubectl -n paperless get pods $PAPERLESS_POD -o jsonpath="{.status.phase}")
	echo "Paperless pod is in state - ${PAPERLESS_STATUS}"
	if [[ "$PAPERLESS_STATUS" == "Running" ]]; then
		PAPERLESS_READY=1
	else
		((CIRCUIT_BREAKER=CIRCUIT_BREAKER+1))
		sleep 20
	fi
done

#Find paperless PVC
SERVICE="paperless"
PVC=$(kubectl get pv | grep $SERVICE | grep "data-pvc" | awk {'print $1'})
PAPERLESS_DIR=$(find /var/lib/rancher/k3s/storage -type d -name "$PVC*")
PAPERLESS_EXPORT_PATH="/export"

#Purge old paperless backups
find $PAPERLESS_DIR/$PAPERLESS_EXPORT_PATH -mtime +30 -exec rm {} \;

#Generate paperless backup
kubectl -n paperless exec --stdin --tty $PAPERLESS_POD -- document_exporter /usr/src/paperless/export --zip
PAPERLESS_BACKUP=$(ls -r $PAPERLESS_DIR$PAPERLESS_EXPORT_PATH | head -n 1)
cp $PAPERLESS_DIR$PAPERLESS_EXPORT_PATH/$PAPERLESS_BACKUP $BACKUP_DIR/$SERVICE/

#Silverbullet
SERVICE="silverbullet"
PVC=$(kubectl get pv | grep $SERVICE | awk {'print $1'})
DIR=$(find /var/lib/rancher/k3s/storage -type d -name "$PVC*")
cp -a $DIR/* $BACKUP_DIR/$SERVICE/

#Gitea
SERVICE="gitea"
PVC=$(kubectl get pv | grep $SERVICE-pvc | awk {'print $1'})
DIR=$(find /var/lib/rancher/k3s/storage -type d -name "$PVC*")
cp -a $DIR/git $BACKUP_DIR/$SERVICE/

