#!/bin/bash
# Azure App Service startup script for AjudadoraBot

set -e

echo "Starting AjudadoraBot App Service initialization..."

# Create data directory for SQLite database
mkdir -p /home/data
chmod 755 /home/data

# Mount Azure File Share for database persistence (if configured)
if [ ! -z "$AZURE_FILES_MOUNT_PATH" ] && [ ! -z "$AZURE_FILES_CONNECTION_STRING" ]; then
    echo "Mounting Azure File Share for database persistence..."
    mkdir -p /mnt/database
    # Note: Azure App Service handles file share mounting automatically via configuration
    # This section is for manual mounting if needed
fi

# Set database path for SQLite
export DATABASE_PATH="/home/data/ajudadorabot.db"

# Create database directory if it doesn't exist
if [ ! -f "$DATABASE_PATH" ]; then
    echo "Database file not found. It will be created on first run."
fi

# Set proper permissions for the application
chmod -R 755 /home/site/wwwroot

echo "App Service initialization completed successfully."

# The .NET application will be started automatically by the App Service runtime