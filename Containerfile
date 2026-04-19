FROM rockylinux/rockylinux:10.1-ubi

# Build arguments for package versions
ARG PGDG_REPO="https://download.postgresql.org/pub/repos/yum/reporpms/EL-10-x86_64/pgdg-redhat-repo-latest.noarch.rpm"
ARG PG_MAJOR="18"
ARG OTELCOL_CONTRIB_VERSION="0.150.1"

# Install all packages
RUN dnf -y update --setopt install_weak_deps=false && \
    dnf install -y 'dnf-command(config-manager)' && \
    dnf config-manager --set-enabled crb && \
    dnf install -y epel-release && \
    dnf install -y libssh2 awscli2 hostname wget zstd jq && \
    dnf install -y ${PGDG_REPO} && \
    dnf config-manager --set-disabled pgdg17 pgdg16 pgdg15 pgdg14 && \
    dnf config-manager --set-enabled pgdg-rhel10-extras && \
    dnf install -y \
        postgresql${PG_MAJOR} \
        postgresql${PG_MAJOR}-server \
        postgresql${PG_MAJOR}-contrib \
        pgaudit_${PG_MAJOR} \
        credcheck_${PG_MAJOR} \
        pgbouncer \
        pgbackrest \
        etcd \
        patroni \
        patroni-etcd \
        python3-json-logger && \
    dnf clean all && \
    rm -rf /var/cache/yum

# Install Open Telemtry Collector (contrib)
RUN wget https://github.com/open-telemetry/opentelemetry-collector-releases/releases/download/v${OTELCOL_CONTRIB_VERSION}/otelcol-contrib_${OTELCOL_CONTRIB_VERSION}_linux_amd64.rpm && \
    dnf install -y otelcol-contrib_${OTELCOL_CONTRIB_VERSION}_linux_amd64.rpm && \
    rm -f ./otelcol-contrib_${OTELCOL_CONTRIB_VERSION}_linux_amd64.rpm

# Setup etcd
RUN mkdir -m 700 -p /var/lib/etcd/{certs,etcddata,etcdwal} && \
    mkdir -m 750 -p /var/log/etcd && \
    touch /var/log/etcd/etcd.log && \
    chmod 640 /var/log/etcd/etcd.log && \
    chown -R etcd:etcd /var/log/etcd

#COPY ./build/node1/etcd-certs/* /var/lib/etcd/certs/
COPY ./build/node1/etcd.conf /etc/etcd/etcd.conf

RUN chown -R etcd:etcd /var/lib/etcd/{certs,etcddata,etcdwal}

# Setup Postgres & co.
RUN mkdir -m 700 -p /var/lib/pgsql/${PG_MAJOR}/wal && \
    mkdir -m 700 -p /var/lib/pgsql/{certs,pgbackrest,pgbackrest_spool,pgbackrest_lock} && \
    mkdir -m 750 -p /var/log/postgres && \
    chmod 750 /var/log/{patroni,pgbackrest,pgbouncer,postgres} && \
    chown -R postgres:postgres /var/log/{patroni,postgres}

#COPY ./build/node1/pg-certs/* /var/lib/pgsql/certs/
COPY ./build/node1/pgbackrest.conf /etc/pgbackrest.conf
COPY ./build/node1/patroni.yml /etc/patroni/patroni.yml
COPY ./build/node1/pgbouncer.ini /etc/pgbouncer/pgbouncer.ini
COPY ./build/node1/userlist.txt /etc/pgbouncer/userlist.txt
COPY ./build/node1/postgres_init.sh /var/lib/pgsql/postgres_init.sh
COPY ./build/node1/postgres_init.sql /var/lib/pgsql/postgres_init.sql

RUN chown -R postgres:postgres /var/lib/pgsql/* && \
    chown postgres:postgres /etc/pgbackrest.conf && \
    chown postgres:postgres /etc/patroni/patroni.yml && \
    chown pgbouncer:pgbouncer /etc/pgbouncer/pgbouncer.ini /etc/pgbouncer/userlist.txt && \
    chmod 600 /etc/pgbouncer/userlist.txt && \
    chmod 750 /var/lib/pgsql/postgres_init.sh

# Setup Open Telemetry Collector
COPY ./build/node1/otelcol* /etc/otelcol-contrib/
RUN usermod -a -G etcd,postgres,pgbouncer otelcol-contrib

VOLUME [ "/sys/fs/cgroup" ]

EXPOSE 2379/tcp
EXPOSE 2380/tcp
EXPOSE 2381/tcp
EXPOSE 5432/tcp
EXPOSE 6432/tcp
EXPOSE 8008/tcp
EXPOSE 8900/tcp
EXPOSE 8901/tcp
EXPOSE 8902/tcp

ENTRYPOINT ["/sbin/init"]
