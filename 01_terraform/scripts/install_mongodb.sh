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

# Configure MongoDB authentication
mongo admin --eval 'db.createUser({
  user: "admin",
  pwd: "'$1'",
  roles: [{ role: "root", db: "admin" }]
})'

sed -i 's/#security:/security:\n  authorization: enabled/' /etc/mongod.conf
systemctl restart mongod
