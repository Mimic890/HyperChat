#!/usr/bin/env bash
# Creates one PostgreSQL database + user per bridge.
# Runs automatically on first postgres container startup.
# Bridge DB passwords come from environment variables passed in docker-compose.yml.
set -e

psql -v ON_ERROR_STOP=1 --username "$POSTGRES_USER" --dbname "$POSTGRES_DB" <<-EOSQL

    -- mautrix-telegram
    CREATE USER mautrix_telegram WITH PASSWORD '${BRIDGE_TELEGRAM_DB_PASSWORD}';
    CREATE DATABASE mautrix_telegram
        ENCODING 'UTF8'
        LC_COLLATE = 'C'
        LC_CTYPE   = 'C'
        TEMPLATE   = template0
        OWNER      = mautrix_telegram;

    -- mautrix-whatsapp
    CREATE USER mautrix_whatsapp WITH PASSWORD '${BRIDGE_WHATSAPP_DB_PASSWORD}';
    CREATE DATABASE mautrix_whatsapp
        ENCODING 'UTF8'
        LC_COLLATE = 'C'
        LC_CTYPE   = 'C'
        TEMPLATE   = template0
        OWNER      = mautrix_whatsapp;

    -- mautrix-discord
    CREATE USER mautrix_discord WITH PASSWORD '${BRIDGE_DISCORD_DB_PASSWORD}';
    CREATE DATABASE mautrix_discord
        ENCODING 'UTF8'
        LC_COLLATE = 'C'
        LC_CTYPE   = 'C'
        TEMPLATE   = template0
        OWNER      = mautrix_discord;

    -- mautrix-signal
    CREATE USER mautrix_signal WITH PASSWORD '${BRIDGE_SIGNAL_DB_PASSWORD}';
    CREATE DATABASE mautrix_signal
        ENCODING 'UTF8'
        LC_COLLATE = 'C'
        LC_CTYPE   = 'C'
        TEMPLATE   = template0
        OWNER      = mautrix_signal;

EOSQL

echo "Bridge databases created successfully."
