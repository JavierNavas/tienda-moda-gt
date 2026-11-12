#!/bin/sh
# Instala y llena la tienda vulnerable "Tienda Moda GT".
# Se ejecuta dentro del contenedor wpcli:
#   docker compose run --rm wpcli sh /setup/instalar_tienda.sh
set -e
URL="http://localhost:8080"

echo "==> Esperando la base de datos..."
i=0
until wp db check >/dev/null 2>&1; do
  i=$((i+1)); [ $i -gt 30 ] && echo "La base de datos no responde" && exit 1
  sleep 2
done

if wp core is-installed 2>/dev/null; then
  echo "La tienda ya está instalada. Para reinstalar: docker compose down -v"
  exit 0
fi

echo "==> Instalando WordPress"
wp core install --url="$URL" --title="Tienda Moda GT" \
  --admin_user=admin --admin_password=admin123 \
  --admin_email=admin@tiendamoda.local --skip-email
wp option update blogdescription "Ropa y accesorios con envío a toda Guatemala"
wp option update timezone_string "America/Guatemala"
wp option update users_can_register 1
wp option update default_role customer || true
wp rewrite structure "/%postname%/"

echo "==> Activando WooCommerce y configurando la tienda"
wp plugin activate woocommerce
wp option update woocommerce_default_country "GT:GU"
wp option update woocommerce_currency "GTQ"
wp option update woocommerce_store_address "6a. Avenida 10-25, Zona 1"
wp option update woocommerce_store_city "Guatemala"
wp option update woocommerce_enable_myaccount_registration yes
wp option update woocommerce_enable_guest_checkout yes
wp option update woocommerce_onboarding_profile '{"skipped":true}' --format=json || true
wp option update woocommerce_task_list_hidden yes || true
wp option update woocommerce_coming_soon no || true
wp wc tool run install_pages --user=admin >/dev/null

echo "==> Usuarios y roles"
wp user create gerente gerente@tiendamoda.local --role=shop_manager --user_pass=gerente123 --first_name=Laura --last_name=Méndez
wp user create editor editor@tiendamoda.local --role=editor --user_pass=editor123 --first_name=Carlos --last_name=Ruiz
wp user create cliente1 ana.lopez@correo.local --role=customer --user_pass=cliente123 --first_name=Ana --last_name=López
wp user create cliente2 jorge.perez@correo.local --role=customer --user_pass=123456 --first_name=Jorge --last_name=Pérez

echo "==> Productos"
crear() { wp wc product create --user=admin --name="$1" --regular_price="$2" --sku="$3" \
  --manage_stock=true --stock_quantity="$4" --status=publish --porcelain >/dev/null; }
crear "Camisa Oxford manga larga" 225.00 CAM-001 40
crear "Blusa de lino" 189.00 BLU-002 25
crear "Jeans corte recto" 320.00 JEA-003 60
crear "Chaqueta impermeable" 545.00 CHA-004 15
crear "Sudadero con capucha" 275.00 SUD-005 35
crear "Vestido casual" 299.00 VES-006 20
crear "Tenis deportivos" 610.00 TEN-007 30
crear "Gorra bordada" 95.00 GOR-008 80
crear "Cincho de cuero" 140.00 CIN-009 50
crear "Mochila urbana" 385.00 MOC-010 18

echo "==> Métodos de pago"
wp option update woocommerce_bacs_settings '{"enabled":"yes","title":"Transferencia bancaria"}' --format=json
wp option update woocommerce_cod_settings '{"enabled":"yes","title":"Pago contra entrega"}' --format=json
wp option update woocommerce_stripe_settings '{"enabled":"yes","title":"Tarjeta de crédito (Stripe)","testmode":"yes","test_publishable_key":"pk_test_laboratorio000000000000","test_secret_key":"sk_test_laboratorio000000000000","upe_checkout_experience_enabled":"no"}' --format=json

echo "==> Plugins (versiones con CVE conocidos)"
wp plugin activate woocommerce-gateway-stripe themify-wc-product-filter \
  iwp-client social-warfare wp-advanced-search wp-file-upload

echo "==> Pedidos de clientes"
P1=$(wp wc product list --user=admin --sku=CAM-001 --field=id)
P2=$(wp wc product list --user=admin --sku=JEA-003 --field=id)
P3=$(wp wc product list --user=admin --sku=TEN-007 --field=id)
C1=$(wp user get cliente1 --field=ID)
C2=$(wp user get cliente2 --field=ID)
pedido() { wp wc shop_order create --user=admin --customer_id="$1" --status="$2" \
  --payment_method=bacs --payment_method_title="Transferencia bancaria" \
  --billing="$3" --shipping="$3" --line_items="[{\"product_id\":$4,\"quantity\":$5}]" --porcelain; }
B1='{"first_name":"Ana","last_name":"López","address_1":"12 Calle 4-56, Zona 10","city":"Guatemala","state":"GU","postcode":"01010","country":"GT","email":"ana.lopez@correo.local","phone":"5555-1234"}'
B2='{"first_name":"Jorge","last_name":"Pérez","address_1":"3a. Avenida 8-20, Zona 3","city":"Quetzaltenango","state":"QZ","postcode":"09001","country":"GT","email":"jorge.perez@correo.local","phone":"5555-9876"}'
pedido "$C1" completed "$B1" "$P1" 2 >/dev/null
pedido "$C1" pending   "$B1" "$P2" 1 >/dev/null
pedido "$C2" processing "$B2" "$P3" 1 >/dev/null
pedido "$C2" pending   "$B2" "$P1" 3 >/dev/null

echo "==> Páginas con funciones de los plugins"
wp post create --post_type=page --post_status=publish --post_title="Envíe su comprobante de pago" \
  --post_content='Suba la foto o PDF de su transferencia. [wordpress_file_upload]' >/dev/null
wp post create --post_type=page --post_status=publish --post_title="Buscar en el catálogo" \
  --post_content='[wp-advanced-search]' >/dev/null

echo "==> Respaldo olvidado en la raíz web (hallazgo intencional)"
wp db export /var/www/html/respaldo_tienda.sql >/dev/null

echo ""
echo "Tienda lista: $URL"
echo "  admin / admin123        (administrador)"
echo "  gerente / gerente123    (gestor de tienda)"
echo "  cliente1 / cliente123   (cliente)"
echo "  cliente2 / 123456       (cliente)"
