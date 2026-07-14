# ============================================================
# Stage 1: Composer
# ============================================================
FROM composer:2 AS composer

WORKDIR /app

# Copy the entire application first
COPY . .

# Install dependencies
RUN composer install \
    --no-dev \
    --prefer-dist \
    --optimize-autoloader \
    --no-interaction

# Rebuild optimized autoloader
RUN composer dump-autoload --optimize


# ============================================================
# Stage 2: Build Frontend Assets
# ============================================================
FROM node:20-alpine AS frontend

WORKDIR /app

# Copy package files
COPY package*.json ./

RUN npm ci

# Copy application source
COPY . .

# Copy vendor so Vite can resolve Ziggy
COPY --from=composer /app/vendor ./vendor

# Build assets
RUN npm run build


# ============================================================
# Stage 3: Production Image
# ============================================================
FROM php:8.4-cli-alpine

# Install required PHP extensions
RUN docker-php-ext-install \
    pdo \
    pdo_mysql \
    bcmath

WORKDIR /var/www/html

# Copy application
COPY . .

# Copy Composer dependencies
COPY --from=composer /app/vendor ./vendor

# Copy built frontend assets
COPY --from=frontend /app/public/build ./public/build

# Set permissions
RUN mkdir -p \
    storage/framework/cache \
    storage/framework/sessions \
    storage/framework/views \
    storage/logs \
    bootstrap/cache

RUN chmod -R 775 storage bootstrap/cache

RUN chown -R www-data:www-data storage bootstrap/cache

EXPOSE 80

CMD ["php", "-S", "0.0.0.0:80", "-t", "public", "public/index.php"]

ENV TMPDIR=/tmp
RUN mkdir -p $TMPDIR && chmod 1777 $TMPDIR

RUN php artisan config:clear
RUN php artisan view:clear
RUN php artisan cache:clear

RUN php artisan about
RUN php artisan route:list
RUN whoamid

RUN php -r "echo realpath('storage/framework/views'), PHP_EOL;"
RUN php -r "var_dump(is_writable('storage/framework/views'));"