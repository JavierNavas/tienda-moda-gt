# Imagen de la tienda (versión VULNERABLE a propósito para el proyecto).
# Las malas prácticas de este archivo son intencionales: se detectan en la Fase 4 (Checkov / Trivy).
FROM wordpress:php7.4-apache

# Configuración PHP insegura (errores visibles, versión expuesta)
COPY php-inseguro.ini /usr/local/etc/php/conf.d/zz-inseguro.ini

# Plugins (versiones con CVE conocidos) y archivos de diagnóstico olvidados en la raíz web
ADD plugins/ /usr/src/wordpress/wp-content/plugins/
ADD web-extra/ /usr/src/wordpress/

EXPOSE 80
