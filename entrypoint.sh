#!/bin/bash

set -e

# Atualizar as dependências do Composer
composer install --no-interaction --prefer-dist --optimize-autoloader --no-dev

# Gerar a chave do Laravel
php artisan key:generate

# Limpar e cache das configurações do Laravel
php artisan config:cache

# Limpar e cache das rotas do Laravel
php artisan route:cache

# Limpar e cache das views do Laravel
php artisan view:cache

# Instalar as dependências do Node.js e compilar os assets
npm install
npm run production

# Iniciar o Supervisor
/usr/bin/supervisord -n -c /etc/supervisor/conf.d/supervisord.conf
