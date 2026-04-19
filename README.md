# otel-poc

This repository contains the OpenTelemetry Collector proof of concept for PostgreSQL with Patroni, etcd and pgbackrest. All required components and their configuration are built into a container image which features systemd. Just exec into the container and play around with the services and their output.

> [!warning]
> 
> This project is for demo purposes and should not be considered battle-tested or production ready!
>
> All changes within the container are ephemeral.

## Requirements

Docker is required to jump start this project. Follow the installation steps in [Docker's documentation](https://www.docker.com/products/docker-desktop/).

## Run the container

The first step is to built the container and start it up. Make the `init.sh` executable and run it. It creates via `docker compose` the container image and starts all containers afterwards.

```bash
chmod +x init.sh
./init.sh
```

Use the following commands to manage the container.

```bash
docker compose up -d                        # Run all containers
docker compose up -d --build                # Build image and run container
docker compose ps                           # See status of all containers
docker compose down                         # Remove all containers
```

Log in to the container as root.

```bash
docker exec node1 bash
```

Start all services.

```bash
systemctl start etcd
systemctl start patroni
systemctl start pgbouncer
systemctl start otelcol-contrib
```

> [!note]
>
> All credentials used in the different containers follow the pattern:
> username = password
>
> Example:
> Username: postgres
> Password: postgres

## Display metrics

All metrics can be displayed via `http`.

| Metrics | URL |
| --- | --- |
| etcd | http://localhost:2381/metrics |
| Patroni | http://localhost:8008/metrics |
| PostgreSQL | http://localhost:8900/metrics |
| Pgbouncer | http://localhost:8901/metrics |
| pgbackrest | http://localhost:8902/metrics |

## Display logs

Logs are collected from Postgres, Patroni, pgbackrest, Pgbouncer and etcd. To keep this container self-contained, all log entries are outputted through one pipeline to a JSON file.

```bash
tail -f /tmp/otel-logs.json
```

The JSON content in the file is not formatted, so `jq` is available in the container.

```bash
cat /tmp/otel-logs.json | jq .
```

## Presentation

> [!note]
> 
> The content of this POC was presented at [PGConf.DE 2026](https://pgconf.de) with the title [One Collector to Rule Them All: Unified Observability for PostgreSQL Platforms](https://www.postgresql.eu/events/pgconfde2026/schedule/session/7734-one-collector-to-rule-them-all-unified-observability-for-postgresql-platforms/) on 22.04.2026.

The presentation is built with [Quarto](https://quarto.org/). Follow these steps to install it and its dependencies. In addition, there is an extension for VSCode available.

```bash
export QUARTO_VERSION="1.9.37"
wget "https://github.com/quarto-dev/quarto-cli/releases/download/v${QUARTO_VERSION}/quarto-${QUARTO_VERSION}-linux-amd64.tar.gz"
sudo tar -C /opt -xvzf "./quarto-${QUARTO_VERSION}-linux-amd64.tar.gz"
sudo ln -s "/opt/quarto-${QUARTO_VERSION}/bin/quarto" /usr/local/bin/quarto
```
