# Stage 1: Build Frontend Assets
FROM node:20-alpine AS frontend-builder
WORKDIR /app
COPY package*.json ./
RUN npm install
COPY . .
RUN npm run build

# Stage 2: Production PHP/Nginx environment (UPDATED TO PHP 8.4)
FROM php:8.4-fpm-alpine
RUN docker-php-ext-install pdo pdo_mysql bcmath

# Install Nginx and Supervisor
RUN apk add --no-cache nginx supervisor

WORKDIR /var/www/html
COPY --from=frontend-builder /app /var/www/html

# Install Composer dependencies
RUN curl -sS https://getcomposer.org | php -- --install-dir=/usr/local/bin --filename=composer
RUN composer install --no-dev --optimize-autoloader

# Configure system directories and permissions
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache

EXPOSE 80
CMD ["php", "artisan", "serve", "--host=0.0.0.0", "--port=80"]
