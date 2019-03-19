---
title: "How to Wait for Container X Before Starting Y"
date: 2017-03-05T15:08:24+09:00
author: Peter Evans
description: "How to wait for container X before starting Y using docker-compose healthcheck"
keywords: ["docker", "docker compose", "container", "healthcheck", "dockerize"]
---

Since docker-compose [version 2.1 file format](https://docs.docker.com/compose/compose-file/compose-versioning/#version-21) the [healthcheck](https://docs.docker.com/compose/compose-file/#healthcheck) parameter has been introduced.
This allows a check to be configured in order to determine whether or not containers for a service are "healthy."

### How can I wait for container X before starting Y?

This is a common problem and in earlier versions of docker-compose requires the use of additional tools and scripts such as [wait-for-it](https://github.com/vishnubob/wait-for-it) and [dockerize](https://github.com/jwilder/dockerize).
Using the `healthcheck` parameter the use of these additional tools and scripts is often no longer necessary.

### Waiting for PostgreSQL to be "healthy"

A particularly common use case is a service that depends on a database, such as PostgreSQL.
We can configure docker-compose to wait for the PostgreSQL container to startup and be ready to accept requests before continuing.

The following healthcheck has been configured to periodically check if PostgreSQL is ready using the `pg_isready` command. See the documentation for the `pg_isready` command [here](https://www.postgresql.org/docs/9.4/static/app-pg-isready.html).
```yml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U postgres"]
  interval: 10s
  timeout: 5s
  retries: 5
```
If the check is successful the container will be marked as `healthy`. Until then it will remain in an `unhealthy` state.
For more details about the healthcheck parameters `interval`, `timeout` and `retries` see the documentation [here](https://docs.docker.com/engine/reference/builder/#healthcheck).

Services that depend on PostgreSQL can then be configured with the `depends_on` parameter as follows:
```yml
depends_on:
  postgres-database:
    condition: service_healthy
```

### Waiting for PostgreSQL before starting Kong

In this complete example docker-compose waits for the PostgreSQL service to be "healthy" before starting [Kong](https://getkong.org/), an open-source API gateway. It also waits for an additional ephemeral container to complete Kong's database migration process.

```yml
version: '2.1'

services:
  kong-database:
    image: postgres:9.5
    environment:
      - POSTGRES_USER=kong
      - POSTGRES_DB=kong
    healthcheck:
      test: ["CMD-SHELL", "pg_isready -U postgres"]
      interval: 10s
      timeout: 5s
      retries: 5

  kong-migration:
    image: kong
    depends_on:
      kong-database:
        condition: service_healthy
    environment:
      - KONG_DATABASE=postgres
      - KONG_PG_HOST=kong-database
    command: kong migrations up

  kong:
    image: kong
    restart: always
    depends_on:
      kong-database:
        condition: service_healthy
      kong-migration:
        condition: service_started
    links:
      - kong-database:kong-database
    ports:
      - 8000:8000
      - 8443:8443
      - 8001:8001
      - 8444:8444
    environment:
      - KONG_DATABASE=postgres
      - KONG_PG_HOST=kong-database
      - KONG_PG_DATABASE=kong
      - KONG_ADMIN_LISTEN=0.0.0.0:8001
```

Test it out with:
```
docker-compose up -d
```
Wait until all services are running:

![Demo](/img/docker-compose-healthcheck-demo.gif)

Test by querying Kong's admin endpoint:
```
curl http://localhost:8001/
```

Sample code can be found at [https://github.com/peter-evans/docker-compose-healthcheck](https://github.com/peter-evans/docker-compose-healthcheck)
