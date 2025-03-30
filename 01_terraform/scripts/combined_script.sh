#!/bin/bash

# Update package list and install dependencies
apt-get update
apt-get install -y wget gnupg

# Add MongoDB repository key and source
wget -qO - https://www.mongodb.org/static/pgp/server-4.0.asc | apt-key add -
echo "deb [ arch=amd64 ] https://repo.mongodb.org/apt/ubuntu bionic/mongodb-org/4.0 multiverse" > /etc/apt/sources.list.d/mongodb-org-4.0.list

# Install MongoDB
apt-get update
apt-get install -y mongodb-org

# Start and enable MongoDB service
systemctl start mongod
systemctl enable mongod

# Configure MongoDB authentication - Intentionally local and admin user!
mongo admin --eval 'db.createUser({
  user: "admin",
  pwd: "${mongodb_password}",
  roles: [{ role: "root", db: "admin" }]
})'

mongo myDatabase --eval 'db.createUser({
  user: "dbuser",
  pwd: "${mongodb_password}",
  roles: [{ role: "readWrite", db: "myDatabase" }]
})'

sed -i 's/#security:/security:\n  authorization: enabled/' /etc/mongod.conf
systemctl restart mongod

# Install Azure CLI for backup functionality
curl -sL https://aka.ms/InstallAzureCLIDeb | sudo bash

# Create backup script
cat > /home/${admin_username}/backup_mongodb.sh << 'BACKUPEOF'
#!/bin/bash
DATE=$(date +%Y-%m-%d-%H%M)
BACKUP_DIR="/tmp/backup"
STORAGE_ACCOUNT="${storage_account_name}"
CONTAINER_NAME="${container_name}"
SAS_TOKEN="${sas_token}"

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
  --sas-token "$SAS_TOKEN"

# Clean up
rm -rf $BACKUP_DIR/$DATE
rm $BACKUP_DIR/mongodb-$DATE.tar.gz
BACKUPEOF

# Make script executable
chmod +x /home/${admin_username}/backup_mongodb.sh
chown ${admin_username}:${admin_username} /home/${admin_username}/backup_mongodb.sh

# Add cron job to run backup daily at 2 AM
(crontab -l -u ${admin_username} 2>/dev/null; echo "0 2 * * * /home/${admin_username}/backup_mongodb.sh") | crontab -u ${admin_username} -

# Test backup immediately
sudo -u ${admin_username} /home/${admin_username}/backup_mongodb.sh

# Create wizexercise.txt file for demo purposes
echo "This is the wizexercise.txt file for MongoDB container" > /wizexercise.txt