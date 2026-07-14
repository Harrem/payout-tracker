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

# Copy the rest of the application
COPY . .

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
FROM php:8.4-fpm-alpine

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
RUN chown -R www-data:www-data \
    storage \
    bootstrap/cache

EXPOSE 80

CMD ["sh", "-c", "php artisan serve --host=0.0.0.0 --port=${PORT:-80}"]