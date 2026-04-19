#!/bin/bash

# Clean up
rm -rf ./build

# Create directories and copy template configuration files
mkdir -p ./build/node1/{etcd-certs,pg-certs}
cp ./templates/* ./build/node1/

# Create cipher pass for pgbackrest
REPO_CIPHER_PASS=$(openssl rand -base64 48)
sed -i "s|{{ REPO_CIPHER_PASS }}|${REPO_CIPHER_PASS}|g" ./build/node1/pgbackrest.conf

# Create certificates for etcd, Postgres & Pgbouncer
#bash ./create-certificates.sh

# Run all containers
docker compose up -d --build
