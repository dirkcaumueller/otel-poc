FROM rockylinux/rockylinux:10.1-ubi

# Build arguments for package versions
ARG PGDG_REPO=https://download.postgresql.org/pub/repos/yum/reporpms/EL-10-x86_64/pgdg-redhat-repo-latest.noarch.rpm
ARG PG_MAJOR=18

# Install all packages
RUN dnf -y update --setopt install_weak_deps=false && \
    dnf install -y 'dnf-command(config-manager)' && \
    dnf config-manager --set-enabled crb && \
    dnf install -y epel-release && \
    dnf install -y libssh2 && \
    dnf install -y ${PGDG_REPO} && \
    dnf config-manager --set-disabled pgdg17 pgdg16 pgdg15 pgdg14 && \
    dnf config-manager --set-enabled pgdg-rhel10-extras && \
    dnf install -y \
        postgresql${PG_MAJOR} \
        postgresql${PG_MAJOR}-server \
        postgresql${PG_MAJOR}-contrib \
        pgaudit_${PG_MAJOR} \
        pgbouncer \
        pgbackrest \
        etcd \
        patroni \
        patroni-etcd && \
    dnf clean all && \
    rm -rf /var/cache/yum

VOLUME [ "/sys/fs/cgroup" ]
CMD ["/usr/sbin/init"]
