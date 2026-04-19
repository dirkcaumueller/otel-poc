#!/bin/bash

# Create all required objects in the postgres db
psql -d postgres -U postgres -f /var/lib/pgsql/postgres_init.sql

# Create the pgbackrest stanza and create a first backup
pgbackrest --config=/etc/pgbackrest.conf --stanza=db stanza-create
pgbackrest --config=/etc/pgbackrest.conf --stanza=db backup