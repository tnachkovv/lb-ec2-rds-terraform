#!/bin/bash

# Update package list and install MySQL client
sudo apt-get update -y && sudo apt install mysql-client -y

# Install Node.js and NPM
sudo apt install -y curl 
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt install -y nodejs npm

# Populating app.js and index.html
cat app.js > /home/ubuntu/app/app.js
cat index.html > /home/ubuntu/app/index.html

# Mount EFS file system
mkdir -p /mnt/efs
if ! mount -t efs "${aws_efs_file_system.test_efs.id}":/ /mnt/efs; then
    echo "Mounting EFS failed!"
    exit 1
fi

# Navigate to the app directory and install dependencies
cd /home/ubuntu/app
npm install

# Start the Node.js application
node app.js
