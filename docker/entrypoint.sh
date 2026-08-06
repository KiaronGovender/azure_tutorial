#!/bin/sh
set -e

# Create required storage & bootstrap cache directories
mkdir -p /var/www/html/storage/framework/cache/data
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/storage/logs
mkdir -p /var/www/html/bootstrap/cache

# Fix directory ownership and permissions
chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Initialize SQLite database file if configured and not present
if [ "${DB_CONNECTION}" = "sqlite" ]; then
    DB_FILE="${DB_DATABASE:-/var/www/html/database/database.sqlite}"
    if [ ! -f "$DB_FILE" ]; then
        mkdir -p "$(dirname "$DB_FILE")"
        touch "$DB_FILE"
        chown www-data:www-data "$DB_FILE"
    fi
fi

# Run artisan setup tasks if this container acts as the app server
if [ "${CONTAINER_ROLE:-app}" = "app" ]; then
    if [ "${RUN_MIGRATIONS:-false}" = "true" ]; then
        echo "--> Running database migrations..."
        php artisan migrate --force
    fi

    if [ "${APP_ENV}" = "production" ]; then
        echo "--> Caching framework configurations..."
        php artisan config:cache
        php artisan route:cache
        php artisan view:cache
        php artisan event:cache
    else
        echo "--> Clearing framework caches for non-production environment..."
        php artisan config:clear
        php artisan route:clear
        php artisan view:clear
        php artisan cache:clear
    fi
fi

echo "--> Launching Supervisor process manager..."
exec /usr/bin/supervisord -c /etc/supervisor/conf.d/supervisord.conf
