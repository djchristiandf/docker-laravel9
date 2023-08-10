# Etapa 1: Instalar as dependências do sistema
FROM php:8.1-fpm AS base

RUN apt-get update && apt-get install -y \
    nginx \
    git \
    unzip \
    libpng-dev \
    libjpeg-dev \
    libfreetype6-dev \
    libonig-dev \
    libxml2-dev \
    libzip-dev \
    libpq-dev \
    unixodbc-dev \
    libgss3 \
    odbcinst \
    gnupg2 \
    libtool \
    libltdl-dev \
    libonig-dev \
    libjpeg-dev \
    libpng-dev \
    libfreetype6-dev && \
    rm -rf /var/lib/apt/lists/*

# Instalar o Composer
RUN curl -sS https://getcomposer.org/installer | php -- --install-dir=/usr/local/bin --filename=composer

# Adicionar o arquivo default.conf
COPY ./default.conf /etc/nginx/conf.d/default.conf

# Etapa 2: Instalar as extensões do PHP e copiar o código do projeto
FROM base AS php-extensions

RUN docker-php-ext-install \
    pdo_mysql \
    mbstring \
    exif \
    pcntl \
    bcmath \
    gd \
    zip \
    pdo_pgsql

RUN curl https://packages.microsoft.com/keys/microsoft.asc | tee /etc/apt/trusted.gpg.d/microsoft.asc && \
    curl https://packages.microsoft.com/config/ubuntu/20.04/prod.list > /etc/apt/sources.list.d/mssql-release.list && \
    apt-get update && ACCEPT_EULA=Y apt-get install -y libltdl-dev msodbcsql18 mssql-tools18 && \
    echo 'export PATH="$PATH:/opt/mssql-tools18/bin"' >> ~/.bashrc

COPY --from=base /usr/lib/x86_64-linux-gnu/libodbc* /usr/local/lib/
COPY --from=base /usr/lib/x86_64-linux-gnu/libltdl* /usr/local/lib/
RUN ldconfig

# Etapa 3: Instalar o Node.js e o npm
FROM php-extensions AS node

RUN apt-get update && apt-get install -y \
    curl \
    gnupg \
    && curl -sL https://deb.nodesource.com/setup_17.x | bash - \
    && apt-get install -y nodejs \
    && rm -rf /var/lib/apt/lists/*

# Etapa 4: Instalar e configurar o supervisor
FROM node AS supervisor

RUN apt-get update && apt-get install -y supervisor

COPY ./supervisord.conf /etc/supervisor/conf.d/supervisord.conf

CMD ["supervisord", "-c", "/etc/supervisor/conf.d/supervisord.conf"]

# Etapa 5: Copiar o código do projeto e definir as permissões corretas para os diretórios storage e bootstrap/cache
FROM supervisor AS laravel

WORKDIR /var/www/html

# Copiar o código do projeto e definir as permissões corretas
COPY ./laravel9 /var/www/html
RUN chown -R www-data:www-data /var/www/html/storage /var/www/html/bootstrap/cache && \
    chmod -R 755 /var/www/html/storage /var/www/html/bootstrap/cache

# Etapa 6: Executar os comandos Artisan e NPM e compilar os assets
FROM laravel AS assets

RUN composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev && \
    php artisan key:generate && \
    php artisan config:cache && \
    php artisan route:cache && \
    php artisan view:cache

COPY package*.json ./
RUN npm install
COPY . .
RUN npm run production

# Etapa 7: Configurar o servidor web
FROM laravel AS webserver

EXPOSE 80
CMD ["/usr/bin/supervisord", "-c", "/etc/supervisor/supervisord.conf"]
