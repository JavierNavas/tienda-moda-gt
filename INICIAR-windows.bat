@echo off
cd /d "%~dp0"
cls
echo =================================================
echo    Tienda Moda GT  -  Laboratorio de Seguridad
echo =================================================
echo.
docker info >nul 2>&1
if errorlevel 1 (
  echo Docker no esta corriendo.
  echo Abre "Docker Desktop", espera a que diga "Running" y vuelve a ejecutar este archivo.
  echo.
  pause
  exit /b 1
)
echo 1/3  Construyendo y encendiendo los contenedores...
docker compose up -d --build
if errorlevel 1 ( echo Fallo al iniciar. & pause & exit /b 1 )
echo.
echo 2/3  Instalando la tienda (solo la primera vez, puede tardar unos minutos)...
docker compose run --rm wpcli sh /setup/instalar_tienda.sh
echo.
echo 3/3  Aplicando idioma, imagenes y estilo...
docker compose run --rm wpcli sh /setup/mejorar_tienda.sh
echo.
echo =================================================
echo   LISTO.
echo   Tienda:      http://127.0.0.1:8080
echo   Admin:       http://127.0.0.1:8080/wp-admin   (admin / admin123)
echo   phpMyAdmin:  http://127.0.0.1:8081
echo =================================================
timeout /t 2 >nul
start http://127.0.0.1:8080
pause
