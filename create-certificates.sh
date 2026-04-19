#!/bin/bash

# Number of nodes
NODE_COUNT=1

# CFSSL for certificate generation
CFSSL_VERSION="1.6.5"

# Directory for certificate creation
mkdir -p ./build/{profiles,certs}

cd ./build

# Download CFSSL
echo "Download CFSSL ..."
curl -L "https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssl_${CFSSL_VERSION}_linux_amd64" \
  -o ./cfssl
curl -L "https://github.com/cloudflare/cfssl/releases/download/v${CFSSL_VERSION}/cfssljson_${CFSSL_VERSION}_linux_amd64" \
  -o ./cfssljson

chmod +x ./{cfssl,cfssljson}

# Create Key for etcd JWT authentication
echo "Generate etcd JWT key ..."
openssl genrsa -out ./certs/jwt_RS256 4096
openssl rsa -in ./certs/jwt_RS256 -pubout > ./certs/jwt_RS256.pub

# Create CA
echo '{
  "signing": {
    "default": {
      "expiry": "43800h"
    },
    "profiles": {
      "server": {
        "expiry": "43800h",
        "usages": ["signing", "key encipherment", "server auth"]
      },
      "client": {
        "expiry": "43800h",
        "usages": ["signing", "key encipherment", "client auth"]
      },
      "peer": {
        "expiry": "43800h",
        "usages": ["signing", "key encipherment", "server auth", "client auth"]
      }
    }
  }
}' > ./profiles/config.json

echo '{"CN":"etcd-ca","key":{"algo":"ecdsa","size":256}}' > ./profiles/ca.json
echo '{"CN":"root","key":{"algo":"ecdsa","size":256}}' > ./profiles/client.json
echo '{"CN":"etcd-member","key":{"algo":"ecdsa","size":256}}' > ./profiles/peer.json
echo '{"CN":"etcd-server","key":{"algo":"ecdsa","size":256}}' > ./profiles/server.json

# Create CA files: ca.pem, ca-key.pem, ca.csr
./cfssl gencert -initca ./profiles/ca.json | ./cfssljson -bare ./certs/ca

# Generate a client cert
./cfssl gencert -ca=./certs/ca.pem -ca-key=./certs/ca-key.pem \
        -config=./profiles/config.json -profile=client \
        ./profiles/client.json | ./cfssljson -bare ./certs/etcd-client

# Copy certs to each node build-directory
for i in $(seq -w 1 ${NODE_COUNT}); do

  echo "Generate etcd server & peer certificate for node${i} ..."

  cp ./certs/{jwt_RS256,jwt_RS256.pub,ca.pem,etcd-client.pem,etcd-client-key.pem} ./node${i}/etcd-certs
  cp ./certs/{ca.pem,etcd-client.pem,etcd-client-key.pem} ./node${i}/pg-certs

  # Generate a peer cert
  ./cfssl gencert -ca=./certs/ca.pem -ca-key=./certs/ca-key.pem \
        -config=./profiles/config.json -profile=peer -hostname="node${i},localhost,172.20.0.1${i},127.0.0.1" \
        ./profiles/peer.json | ./cfssljson -bare ./node${i}/etcd-certs/etcd-peer

  # Generate a server cert
  ./cfssl gencert -ca=./certs/ca.pem -ca-key=./certs/ca-key.pem \
          -config=./profiles/config.json -profile=server -hostname="node${i},localhost,172.20.0.1${i},127.0.0.1" \
          ./profiles/server.json | ./cfssljson -bare ./node${i}/etcd-certs/etcd-server

  echo "Generate PostgreSQL Certificate for node${i} ..."

  cat > pg-server-csr.json <<'EOF'
{
  "CN": "postgres",
  "hosts": [
    "node${i}",
    "172.20.0.1${i}",
    "127.0.0.1"
  ],
  "key": {"algo":"ecdsa","size":256}
}
EOF

./cfssl gencert -ca=./certs/ca.pem -ca-key=./certs/ca-key.pem -config=./profiles/config.json \
      -profile=server pg-server-csr.json | ./cfssljson -bare ./node${i}/pg-certs/pg-server

done
