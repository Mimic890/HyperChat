#!/usr/bin/env bash
# Creates PostgreSQL databases for enabled services.
# Runs automatically on first postgres container startup.
# Only creates DBs when the corresponding password env var is set.
set -e

# ── Bridges ──────────────────────────────────────────────────────────────────
for bridge in telegram whatsapp discord signal; do
    upper=$(echo "$bridge" | tr '[:lower:]' '[:upper:]')
    pw_var="BRIDGE_${upper}_DB_PASSWORD"
    pw=$(eval echo "\${${pw_var}:-}")
    if [ -n "$pw" ]; then
        echo "Creating database for mautrix_${bridge}..."
        psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
            CREATE USER mautrix_${bridge} WITH PASSWORD '${pw}';
            CREATE DATABASE mautrix_${bridge}
                ENCODING 'UTF8'
                LC_COLLATE = 'C'
                LC_CTYPE   = 'C'
                TEMPLATE   = template0
                OWNER      = mautrix_${bridge};
EOSQL
        echo "  ✓ mautrix_${bridge}"
    fi
done

# ── MAS ──────────────────────────────────────────────────────────────────────
if [ -n "${MAS_DB_PASSWORD:-}" ]; then
    echo "Creating database for MAS..."
    psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL
        CREATE USER mas WITH PASSWORD '${MAS_DB_PASSWORD}';
        CREATE DATABASE mas
            ENCODING 'UTF8'
            LC_COLLATE = 'C'
            LC_CTYPE   = 'C'
            TEMPLATE   = template0
            OWNER      = mas;
EOSQL
    echo "  ✓ mas"
fi

echo "Database initialization complete."
