#!/bin/sh
cd "$(dirname "$0")"
clear
echo "================================================="
echo "   Tienda Moda GT  -  Laboratorio de Seguridad"
echo "================================================="
echo ""
if ! docker info >/dev/null 2>&1; then
  echo "Docker no esta corriendo."
  echo "Abre 'Docker Desktop', espera a que diga 'Running' y vuelve a dar doble clic aqui."
  echo ""; read -p "Enter para cerrar..."; exit 1
fi
echo "1/3  Construyendo y encendiendo los contenedores..."
docker compose up -d --build || { echo "Fallo al iniciar."; read -p "Enter..."; exit 1; }
echo ""
echo "2/3  Instalando la tienda (solo la primera vez, puede tardar unos minutos)..."
docker compose run --rm wpcli sh /setup/instalar_tienda.sh
echo ""
echo "3/3  Aplicando idioma, imagenes y estilo..."
docker compose run --rm wpcli sh /setup/mejorar_tienda.sh
echo ""
echo "================================================="
echo "  LISTO. Abriendo la tienda en el navegador..."
echo "  Tienda:      http://127.0.0.1:8080"
echo "  Admin:       http://127.0.0.1:8080/wp-admin   (admin / admin123)"
echo "  phpMyAdmin:  http://127.0.0.1:8081"
echo "================================================="
sleep 2
open http://127.0.0.1:8080
read -p "Enter para cerrar esta ventana (la tienda sigue corriendo)..."
