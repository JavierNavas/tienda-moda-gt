@echo off
cd /d "%~dp0"
echo Apagando la tienda (los datos se conservan)...
docker compose stop
echo Listo. Para volver a encenderla ejecuta INICIAR-windows.bat
pause
