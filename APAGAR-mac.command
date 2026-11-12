#!/bin/sh
cd "$(dirname "$0")"
echo "Apagando la tienda (los datos se conservan)..."
docker compose stop
echo "Listo. Para volver a encenderla usa INICIAR-mac.command"
read -p "Enter para cerrar..."
