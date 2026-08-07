# ==============================================================================
# Stage 1: Build Application Dependencies & Frontend Assets
# ==============================================================================
FROM php:8.4-cli-alpine AS builder

WORKDIR /app

# Copy Composer & PHP extension installer binaries
COPY --from=composer:latest /usr/bin/composer /usr/bin/composer
COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Install system dependencies, Node.js, npm, git, unzip, and essential PHP extensions
RUN apk add --no-cache \
    nodejs \
    npm \
    git \
    unzip \
    libzip-dev \
    icu-dev \
    && install-php-extensions \
    bcmath \
    intl \
    zip \
    pdo_sqlite

# Copy dependency manifests
COPY composer.json composer.lock package.json package-lock.json ./

# Install PHP dependencies without running scripts
RUN composer install --no-dev --no-scripts --no-autoloader --prefer-dist

# Install Node dependencies
RUN npm ci

# Copy full application codebase (required for Wayfinder route compilation & Vite build)
COPY . .

# Generate optimized Composer autoloader without running artisan scripts during build
RUN composer dump-autoload --optimize --no-dev --no-scripts

# Build frontend static assets via Vite
RUN npm run build

# Remove node_modules to keep staging clean
RUN rm -rf node_modules

# ==============================================================================
# Stage 2: Production Application Runtime (Nginx + PHP-FPM + Supervisor)
# ==============================================================================
FROM php:8.4-fpm-alpine AS final

WORKDIR /var/www/html

# Install PHP Extension Installer helper
COPY --from=ghcr.io/mlocati/php-extension-installer /usr/bin/install-php-extensions /usr/local/bin/

# Install required PHP extensions & system utilities
RUN apk add --no-cache \
    nginx \
    supervisor \
    bash \
    curl \
    sqlite \
    postgresql-client \
    && install-php-extensions \
    pdo_mysql \
    pdo_pgsql \
    pdo_sqlite \
    opcache \
    zip \
    exif \
    pcntl \
    bcmath \
    gd \
    intl \
    redis

# Copy custom Nginx, PHP, and Supervisor configurations
COPY docker/nginx/nginx.conf /etc/nginx/nginx.conf
COPY docker/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf
COPY docker/php/php.ini $PHP_INI_DIR/conf.d/php.ini
COPY docker/php/opcache.ini $PHP_INI_DIR/conf.d/opcache.ini
COPY docker/supervisor/supervisord.conf /etc/supervisor/conf.d/supervisord.conf

# Copy application codebase (with vendor/ and public/build/) from builder stage
COPY --chown=www-data:www-data --from=builder /app /var/www/html

# Copy entrypoint script and grant execution permissions
COPY docker/entrypoint.sh /usr/local/bin/docker-entrypoint.sh
RUN chmod +x /usr/local/bin/docker-entrypoint.sh

# Ensure framework storage and cache directories have correct ownership & permissions
RUN mkdir -p /var/www/html/storage/framework/cache/data \
    /var/www/html/storage/framework/sessions \
    /var/www/html/storage/framework/views \
    /var/www/html/storage/logs \
    /var/www/html/bootstrap/cache \
    && chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache \
    && chmod -R 775 /var/www/html/storage /var/www/html/bootstrap/cache

# Expose HTTP port
EXPOSE 80

# Environment defaults
ENV APP_ENV=production \
    APP_DEBUG=false \
    CONTAINER_ROLE=app \
    RUN_MIGRATIONS=false \
    RUN_QUEUE_WORKER=false

ENTRYPOINT ["docker-entrypoint.sh"]
