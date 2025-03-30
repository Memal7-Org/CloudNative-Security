#!/bin/bash

# Install Azure CLI
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Create backup script
cat > /home/$1/backup_mongodb.sh << 'EOF'
#!/bin/bash
DATE=$(date +%Y-%m-%d-%H%M)
BACKUP_DIR="/tmp/backup"
STORAGE_ACCOUNT=$1
CONTAINER_NAME=$2
SAS_TOKEN=$3

# Create backup directory if it doesn't exist
mkdir -p $BACKUP_DIR

# Backup MongoDB
mongodump --out $BACKUP_DIR/$DATE

# Archive the backup
tar -czf $BACKUP_DIR/mongodb-$DATE.tar.gz -C $BACKUP_DIR $DATE

# Upload to Azure Storage using SAS token
az storage blob upload \
  --account-name $STORAGE_ACCOUNT \
  --container-name $CONTAINER_NAME \
  --name mongodb-$DATE.tar.gz \
  --file $BACKUP_DIR/mongodb-$DATE.tar.gz \
  --sas-token $SAS_TOKEN

# Clean up
rm -rf $BACKUP_DIR/$DATE
rm $BACKUP_DIR/mongodb-$DATE.tar.gz
EOF

# Make script executable
chmod +x /home/$1/backup_mongodb.sh

# Add cron job to run backup daily at 2 AM
(crontab -l 2>/dev/null; echo "0 2 * * * /home/$1/backup_mongodb.sh $2 $3 $4") | crontab -