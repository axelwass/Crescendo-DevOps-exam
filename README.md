# Crescendo-DevOps-exam

## Run Magnolia locally

Requirements: Docker Engine and the Docker Compose plugin.

1. Copy `.env.example` to `.env` and set strong values for `DB_USER`, `DB_PASSWORD`, and `MAGNOLIA_SUPERUSER_PASSWORD`. The local `.env` is ignored by Git:

   ```sh
   cp .env.example .env
   ```

2. From the repository root, start the services:

   ```sh
   docker compose --env-file .env -f docker/docker-compose.yml up --build
   ```

3. Open [http://localhost:8080](http://localhost:8080). Magnolia performs its first-run setup automatically; sign in with username `superuser` and the value of `MAGNOLIA_SUPERUSER_PASSWORD`.

Magnolia settings are kept in readable files under `docker/config/`. Static Magnolia properties are added to the webapp at image build time. At container startup, `envsubst` renders only the Jackrabbit XML template with the database connection details, then Magnolia initializes its repository against PostgreSQL.

To stop the services while retaining the database:

```sh
docker compose --env-file .env -f docker/docker-compose.yml down
```

## Additional considerations

Magnolia stores JCR workspace content and binaries in PostgreSQL in this configuration. Jackrabbit still uses the filesystem for repository metadata, workspace configuration, and Lucene search indexes. A named Docker volume (`magnolia-data`) persists that repository directory across container replacements. The Magnolia activation and password-manager key files are also configured inside this volume. Caches, temporary upload files, and container logs remain ephemeral; Docker exposes application output with `docker compose logs`.

This follows Magnolia's [database setup guidance](https://docs.magnolia-cms.com/product-docs/getting-started-with-magnolia/installing-magnolia/database-sizing-and-setup/) to store binaries in the database, and its [workspace configuration guidance](https://docs.magnolia-cms.com/performance-tuning/installation-and-configuration/workspace-configuration/) that distinguishes database-backed content from on-disk workspace configuration and indexes. [Jackrabbit's repository configuration docs](https://jackrabbit.apache.org/jcr/jackrabbit-configuration.html) describe the repository home as holding indexes and internal configuration; Magnolia notes that indexes can be regenerated.

Back up both the PostgreSQL database and `magnolia-data` for a complete recovery. Restore them together. Lucene indexes can be regenerated, but retaining the volume avoids a full reindex and preserves repository metadata and generated keys. The superuser password is written to a private temporary file inside the container for Magnolia's first-run bootstrap; it is only applied during initial setup. Changing it in `.env` after the database has been initialized does not change the existing account password.

`DB_PASSWORD` is also used only when PostgreSQL initializes a new data volume. If you change it later, update the existing PostgreSQL role password to match before restarting Magnolia; changing `.env` alone does not alter credentials stored in the persistent database.

The `down` command above removes containers but keeps both named volumes. `docker compose down -v` also deletes the database and Magnolia repository data.