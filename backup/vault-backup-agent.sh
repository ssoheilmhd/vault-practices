#/bin/bash

error_notification() {
curl -X POST "https://cliq.zoho.com/api/v2/bots/backupalerting/incoming?zapikey=API_KEY" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "text=Stage vault backup has a problem! Error" \
  -k
}


info_notification() {
curl -X POST "https://cliq.zoho.com/api/v2/bots/backupalerting/incoming?zapikey=API_KEY" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "text=Stage vault backup successfully created! Info" \
  -k
}


backup_from_vault() {
rm -rf result.txt vault_backup_from_keys vault_backup_from_policies vault-userBindpolicy-backup.json *.zip
./general-vault-backup.sh
command_output=`echo $?`

zip -r -P your_zip_key vault-backup-$(date '+%Y-%m-%d').zip vault_backup_from_keys vault_backup_from_policies vault-userBindpolicy-backup.json
}


save_backup_into_minio() {
BACKUP_FILE="vault-backup-$(date '+%Y-%m-%d').zip"
curl --location http://s3-fs-private.stdc.local/api/v1/file/upload \
  --form "file=@\"${BACKUP_FILE}\"" \
  --form "path=\"media\"" \
  --form "app_token=\"YOUR_APP_TOKEN\"" \
  --form "bucket_name=\"vault-backup-metadata-private\"" > result.txt
}


minio_backup_validator() {
grep true result.txt > /dev/null
command_output=`echo $?`
is_valid=0
if [[ $command_output != $is_valid  ]]
then
    error_notification
    echo "`date` backup saw an issue due to minio problem" >> /var/log/vault-backup.log
    exit
fi
}


creation_backup_validator() {
grep -w isok vault_backup_from_keys/backup-check-point/backup-path.json  > /dev/null
command_output=`echo $?`
is_valid=0
if [[ $command_output != $is_valid  ]]
then
    error_notification
    echo "`date` backup saw an issue due to creation problem, we couldnt find backup-check-point details" >> /var/log/vault-backup.log
    exit
fi
}



backup_from_vault
creation_backup_validator
save_backup_into_minio
minio_backup_validator
info_notification
