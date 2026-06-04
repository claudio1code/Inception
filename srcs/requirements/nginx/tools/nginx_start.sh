#!/bin/bash

# Cria o diretório para os certificados se não existir
mkdir -p /etc/nginx/ssl

# Gera o certificado autoassinado usando TLSv1.3 se ele não existir
if [ ! -f /etc/nginx/ssl/inception.crt ]; then
    openssl req -x509 -nodes -days 365 -newkey rsa:4096 \
        -keyout /etc/nginx/ssl/inception.key \
        -out /etc/nginx/ssl/inception.crt \
        -subj "/C=BR/ST=SP/L=SaoPaulo/O=42SP/OU=Cadet/CN=clados-s.42.fr"
fi

# Executa o comando principal do NGINX passado pelo Dockerfile (foreground)
exec "$@"