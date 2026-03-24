# otel-poc

This repository contains the OpenTelemetry poc for PostgreSQL with Patroni, etcd and pgbackrest.

## Requirements

This poc requires the installation of [Docker](https://www.docker.com/products/docker-desktop/). Follow the steps in Docker's documentation to install it.

## Container Image Build

> The container image is built automatically as the first step defined in the Docker Compose file; however, the manual steps are described here for completeness.

Run the build command on the `Containerfile`.

```bash
docker build -f Containerfile -t localhost/rocky10-pg .
```

By default, this will install PostgreSQL 18 along with all related packages. To override specific versions, change the arguments in the `Containerfile`.

Once the build completes successfully, verify the image is available locally.

```bash
docker images | grep rocky10-pg
```

In addition, run the image and check it out.

```bash
docker run -d --rm \
  --name rocky10-pg1 \
  --privileged \
  --cgroupns=host \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  localhost/rocky10-pg
```

## Run the demo

This repository already contains a `docker-compose.yml` file which which includes 3 containers. You can use the following commands to operate the vms via vagrant.

```bash
docker compose up -d                        # Run all containers
docker compose up -d --build                # Build image and run all containers
docker compose exec node1 bash              # Log into one container
docker compose ps                           # See status of all containers
docker compose down                         # Remove all containers
```

