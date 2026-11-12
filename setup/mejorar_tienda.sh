#!/bin/sh
# Mejora visual de la tienda: imágenes reales, tema, limpieza y páginas correctas.
# Ejecutar:  docker compose run --rm wpcli sh /setup/mejorar_tienda.sh
set -e

echo "==> Idioma español"
wp language core install es_ES --activate >/dev/null 2>&1 || true
wp language plugin install woocommerce es_ES >/dev/null 2>&1 || true
wp site switch-language es_ES >/dev/null 2>&1 || true

echo "==> Imágenes reales en cada producto"
for sku in CAM-001 BLU-002 JEA-003 CHA-004 SUD-005 VES-006 TEN-007 GOR-008 CIN-009 MOC-010; do
  PID=$(wp post list --post_type=product --meta_key=_sku --meta_value="$sku" --field=ID 2>/dev/null)
  [ -z "$PID" ] && continue
  if [ -f "/setup/imagenes/$sku.jpg" ]; then
    AID=$(wp media import "/setup/imagenes/$sku.jpg" --porcelain 2>/dev/null)
    wp post meta update "$PID" _thumbnail_id "$AID" >/dev/null
    echo "   $sku -> producto $PID, imagen $AID"
  fi
done

echo "==> Página de búsqueda con el shortcode correcto"
BUS=$(wp post list --post_type=page --name=buscar-en-el-catalogo --field=ID 2>/dev/null)
[ -n "$BUS" ] && wp post update "$BUS" --post_content='<p>Busca por nombre, precio o categoría:</p>[advanced-search]' >/dev/null

echo "==> Borrar contenido de ejemplo de WordPress"
for name in sample-page hello-world privacy-policy; do
  ID=$(wp post list --post_type=any --name="$name" --field=ID 2>/dev/null)
  [ -n "$ID" ] && wp post delete $ID --force >/dev/null 2>&1 || true
done

echo "==> Tema Storefront (el oficial de WooCommerce)"
wp theme install storefront --activate >/dev/null 2>&1 || echo "   (sin internet para el tema: se queda el actual)"
wp option update blogname "Tienda Moda GT" >/dev/null

echo "==> Menú de navegación"
wp menu create "Principal" >/dev/null 2>&1 || true
for pair in "Inicio:/" "Tienda:shop" "Mi cuenta:my-account" "Carrito:cart"; do :; done
SHOP=$(wp option get woocommerce_shop_page_id 2>/dev/null)
CART=$(wp option get woocommerce_cart_page_id 2>/dev/null)
ACC=$(wp option get woocommerce_myaccount_page_id 2>/dev/null)
wp menu item add-post principal "$SHOP" --title="Tienda" >/dev/null 2>&1 || true
wp menu item add-post principal "$CART" --title="Carrito" >/dev/null 2>&1 || true
wp menu item add-post principal "$ACC"  --title="Mi cuenta" >/dev/null 2>&1 || true
wp menu location assign principal primary >/dev/null 2>&1 || true

echo "==> Portada = tienda, con productos destacados"
wp option update show_on_front page >/dev/null
wp option update page_on_front "$SHOP" >/dev/null
for sku in CAM-001 TEN-007 CHA-004 VES-006; do
  PID=$(wp post list --post_type=product --meta_key=_sku --meta_value="$sku" --field=ID 2>/dev/null)
  [ -n "$PID" ] && wp post term add "$PID" product_visibility featured >/dev/null 2>&1 || true
done

echo ""
echo "Listo. Abrir http://127.0.0.1:8080  (Cmd+Shift+R para refrescar sin caché)"
