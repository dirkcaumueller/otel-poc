#!/bin/bash
set -e

# Number of nodes
NODE_COUNT=1

GARAGE_BUCKETS=pgcluster1
GARAGE_CAPACITY=10G
CONTAINER="garage"
GARAGE="docker exec $CONTAINER /garage"

echo "Waiting for Garage to become ready..."
until $GARAGE status > /dev/null 2>&1; do
  sleep 2
done

echo "Initializing layout..."
NODE_ID=$($GARAGE status 2>/dev/null | awk '/NO ROLE/{print $1}' | head -1)

if [ -z "$NODE_ID" ]; then
  echo "ERROR: Could not determine node ID!" >&2
  exit 1
fi

echo "Node ID: $NODE_ID"
$GARAGE layout assign -z dc1 -c "${GARAGE_CAPACITY:-10G}" "$NODE_ID"
$GARAGE layout apply --version 1

echo "Creating buckets and keys..."
for BUCKET in ${GARAGE_BUCKETS:-my-bucket}; do
  if $GARAGE bucket info "$BUCKET" > /dev/null 2>&1; then
    echo "Bucket '$BUCKET' already exists, skipping."
  else
    $GARAGE bucket create "$BUCKET"

    # Let Garage generate the credentials automatically
    KEY_INFO=$($GARAGE key create "$BUCKET-key")

    # Extract Access Key ID and Secret from the output
    S3_ACCESS_KEY_ID=$(echo "$KEY_INFO" | awk '/Key ID:/ {print $3}')
    S3_SECRET_ACCESS_KEY=$(echo "$KEY_INFO" | awk '/Secret key:/ {print $3}')

    $GARAGE bucket allow --read --write --owner "$BUCKET" --key "$BUCKET-key"

    echo ""
    echo "========================================="
    echo " Bucket:            $BUCKET"
    echo " Access Key ID:     $S3_ACCESS_KEY_ID"
    echo " Secret Access Key: $S3_SECRET_ACCESS_KEY"
    echo "========================================="
    echo ""

    for i in $(seq -w 1 ${NODE_COUNT}); do

      echo "Set S3 credentials in pgbackrest.conf on node${i} ..."

      sed -i \
          -e "s|{{ S3_ACCESS_KEY_ID }}|${S3_ACCESS_KEY_ID}|g" \
          -e "s|{{ S3_SECRET_ACCESS_KEY }}|${S3_SECRET_ACCESS_KEY}|g" \
          ./run/node${i}/pgbackrest.conf
    done

  fi
done

echo "Done! Garage is ready."