# Especificación técnica y arquitectura

Documento de referencia del laboratorio. Describe qué se eligió, qué tecnología usa y cómo está
construida la tienda **hoy** (versión vulnerable). Sirve como base para la Fase 1 y la Fase 2 del
informe del proyecto.

---

## 1. Opción elegida

**Opción B del proyecto: CMS / E-Commerce Web.**

Un **CMS** (Content Management System, o gestor de contenidos) es un programa que permite crear y
administrar un sitio web sin programarlo desde cero. **WordPress** es el CMS más usado del mundo.
Sobre WordPress se instala **WooCommerce**, un complemento que lo convierte en tienda en línea con
productos, carrito, pedidos y pagos.

| Aspecto | Decisión |
|---|---|
| Escenario | Tienda en línea de ropa, **Tienda Moda GT** |
| CMS | WordPress 6.1 |
| E-Commerce | WooCommerce 7.9 |
| Lenguaje | PHP 7.4 |
| Servidor web | Apache 2.4 |
| Base de datos | MariaDB 10.6 |
| Despliegue | Contenedores Docker, en `127.0.0.1` (local) |

Se eligió esta opción porque WordPress es de código abierto, su ecosistema de complementos es su
principal punto débil. Eso permite demostrar el OWASP Web Top 10 con vulnerabilidades reales.

---

## 2. Arquitectura actual en producción (as-is, vulnerable)

Así estaría desplegada la tienda **en un entorno real de producción** antes de aplicar seguridad.
Tal como pide la Opción B, la aplicación corre **en contenedores Docker**, pero sobre un solo
servidor en la nube que expone todo a internet sin controles. Este es el diagrama **actual** que pide
el entregable de la Fase 1.

```mermaid
flowchart TB
    subgraph USUARIOS["Usuarios"]
        direction LR
        WEB["Cliente web<br/>(navegador)"]
        MOV["Cliente movil<br/>(navegador)"]
        OPS["Administrador / gerente"]
    end

    DNS["DNS y dominio<br/>tiendamodagt.com"]

    subgraph HOST["Servidor Cloud - un solo equipo (VPS Linux), sin firewall"]
        direction TB
        subgraph DOCKER["Docker - 3 contenedores SEPARADOS en la misma red interna"]
            direction TB
            WPC["CONTENEDOR 1 - Web<br/>wordpress:php7.4-apache<br/>Apache 2.4 + PHP 7.4<br/>WordPress 6.1 + WooCommerce 7.9<br/>6 plugins con CVE"]
            DB[("CONTENEDOR 2 - Base de datos<br/>mariadb:10.6<br/>BD tienda, sin cifrado<br/>productos, clientes, pedidos")]
            PMA["CONTENEDOR 3 - Administracion<br/>phpmyadmin:latest<br/>gestor de la BD"]
        end
        MEDIA["Volumen Docker<br/>wp-content/uploads<br/>imagenes y comprobantes"]
        SSH["Acceso SSH al servidor<br/>sshd, puerto 22"]
    end

    subgraph EXT["Servicios externos"]
        direction LR
        PAY["NeoNet (VisaNet Guatemala)<br/>pasarela de pago con tarjeta"]
        MAIL["SMTP<br/>correos de pedidos"]
    end

    WEB -->|"HTTP/TCP 80 sin TLS"| WPC
    MOV -->|"HTTP/TCP 80 sin TLS"| WPC
    WEB -.->|"DNS UDP 53"| DNS
    WPC -->|"red interna Docker, MySQL/TCP 3306"| DB
    PMA -->|"MySQL/TCP 3306"| DB
    WPC -->|"lectura y escritura"| MEDIA
    WPC -->|"HTTPS/TCP 443"| PAY
    WPC -->|"SMTP/TCP 587"| MAIL
    OPS -->|"HTTP/TCP 8081"| PMA
    OPS -->|"SSH/TCP 22"| SSH

    classDef app fill:#eef2ff,stroke:#3730a3,color:#1e1b4b;
    classDef db fill:#fff7ed,stroke:#9a3412,color:#7c2d12;
    classDef ext fill:#f1f5f9,stroke:#475569,color:#1e293b;
    class WPC,PMA,MEDIA,SSH app;
    class DB db;
    class PAY,MAIL ext;
```

> **Son tres contenedores independientes**, cada uno su propia caja. WordPress y la base de datos
> **no** están juntos: se comunican por la red interna de Docker (puerto 3306). La debilidad no es que
> estén juntos, sino que los tres corren en **el mismo servidor sin segmentación**.

### Protocolos y puertos de comunicación

Cómo se comunica cada parte en producción, de origen a destino:

| # | Origen | Destino | Protocolo / puerto | Cifrado |
|---|---|---|---|---|
| 1 | Cliente (web / móvil) | DNS | DNS, UDP 53 | — |
| 2 | Cliente (web / móvil) | Contenedor web | HTTP, TCP 80 | **No (sin TLS)** |
| 3 | Contenedor web | Base de datos | MySQL, TCP 3306 | No |
| 4 | Contenedor web | NeoNet (VisaNet GT) | HTTPS, TCP 443 | Sí |
| 5 | Contenedor web | Servidor de correo | SMTP, TCP 587 | Según configuración |
| 6 | Administrador | phpMyAdmin | HTTP, TCP 8081 | **No (sin TLS)** |
| 7 | phpMyAdmin | Base de datos | MySQL, TCP 3306 | No |
| 8 | Administrador | Servidor (SSH) | SSH, TCP 22 | Sí |

> El problema de seguridad se ve de inmediato: el tráfico de los clientes y de la administración
> (filas 2 y 6) viaja en **HTTP sin cifrar**. En el rediseño seguro todo pasa a **HTTPS con TLS 1.3**
> a través del API Gateway, y los puertos internos (3306, 8081, 22) dejan de estar expuestos.

### Detalle de cada componente

| Componente | Tecnología / imagen | Puerto | Función | Estado de seguridad |
|---|---|---|---|---|
| Contenedor web | `wordpress:php7.4-apache` | 80 → 8080 | Sirve la tienda (WordPress + WooCommerce) | Plugins con CVE, errores PHP visibles |
| Base de datos | `mariadb:10.6` | 3306 | Guarda productos, clientes y pedidos | Sin cifrado en reposo |
| phpMyAdmin | `phpmyadmin:latest` | 8081 | Administrar la base de datos | Accesible desde internet |
| Volumen uploads | `wp-content/uploads` | — | Imágenes y comprobantes subidos | Permite ejecutar archivos subidos |
| Acceso SSH | `sshd` | 22 | Entrar al servidor | Abierto a 0.0.0.0/0 |
| NeoNet (VisaNet GT) | API externa | 443 | Procesar pagos con tarjeta | Claves en configuracion |
| SMTP | Servidor de correo | 587 | Enviar correos de pedidos | — |

> **Sobre la base de datos (decisión de diseño).** En el mundo real se usan las dos formas. Las
> tiendas pequeñas o los despliegues económicos sí corren la base de datos **en un contenedor en el
> mismo servidor**, como en este diagrama *as-is*. Es común, pero se considera mala práctica: la base
> de datos queda en el mismo host que la web, sin respaldos administrados ni cifrado. Los despliegues
> maduros usan un **servicio administrado** (AWS RDS, Google Cloud SQL, Azure Database), que separa la
> base de datos, la cifra, la respalda y la mantiene aislada de internet. Por eso el **rediseño
> seguro** (sección 3) mueve la base de datos a un servicio administrado y cifrado con KMS.

> **Sobre la pasarela de pago.** En Guatemala **Stripe no opera**, así que una tienda real usa una
> pasarela local: **NeoNet (antes VisaNet Guatemala)** o Recurrente para tarjeta, más transferencia
> bancaria y pago contra entrega. Por eso el diagrama de producción muestra NeoNet. En el laboratorio
> se mantiene instalado el plugin de Stripe por una razón distinta: tiene un **CVE público
> (CVE-2023-34000)** que sirve para demostrar una vulnerabilidad de IDOR en la Fase 3. Es un
> componente de prueba, no la pasarela del escenario de producción.

**Sobre los contenedores:** en producción los tres contenedores (web, base de datos y phpMyAdmin)
corren sobre un mismo servidor con Docker. **En el laboratorio son exactamente los mismos**, pero en
tu equipo (`127.0.0.1`). Por eso lo que se encuentra en el laboratorio aplica igual a producción.
Kubernetes no se usa aquí, bastaría solo si la tienda creciera a varios servidores.

**Debilidades de esta arquitectura (as-is):** tráfico en **HTTP sin cifrar**, un **solo servidor sin
segmentación** (los contenedores comparten el mismo host y red), **sin WAF ni firewall**, herramientas
de administración (**phpMyAdmin y SSH**) accesibles desde internet, plugins de terceros **sin
actualizar** y base de datos **sin cifrado en reposo**. Estas debilidades se detallan en la tabla de
las 7 capas y se tratan en el modelo de amenazas STRIDE/DREAD.

### Flujo de datos (producción)

1. El cliente (web o móvil) entra por el dominio **sin cifrado (HTTP)**, cualquiera en la red puede
   leer el tráfico.
2. El servidor Apache ejecuta WordPress y WooCommerce, con plugins que tienen CVE conocidos.
3. La base de datos MySQL vive en **el mismo servidor**, sin cifrado ni aislamiento.
4. El administrador y cualquier atacante llegan a **phpMyAdmin** y al **respaldo** directamente desde
   internet. El puerto **SSH** queda abierto a todo el mundo.

### Entorno de laboratorio (cómo se emula esta arquitectura)

No se despliega en la nube real. Se **emula la misma topología** con tres contenedores Docker en
`127.0.0.1`, para poder atacarla sin riesgo. El mapeo es directo:

| En producción (diagrama de arriba) | En el laboratorio (Docker) |
|---|---|
| Servidor web Apache + PHP | Contenedor `wordpress` → `http://127.0.0.1:8080` |
| MySQL en el servidor | Contenedor `db` (MariaDB 10.6) |
| phpMyAdmin expuesto | Contenedor `phpmyadmin` → `http://127.0.0.1:8081` |
| Respaldo y archivos expuestos | `respaldo_tienda.sql`, `info.php`, `adminer.php` |

### Por qué esta arquitectura es insegura

| Debilidad | Capa afectada (7 capas) |
|---|---|
| Plugins desactualizados con CVE públicos | Aplicación — Implementación |
| Versiones de PHP y Apache visibles en las cabeceras | Perímetro de aplicación |
| Errores de PHP mostrados al usuario | Aplicación — Código |
| Gestor de base de datos y respaldo accesibles desde la web | Datos |
| Enumeración de usuarios por la API REST | Aplicación — Autenticación |
| Sin WAF, sin cifrado en tránsito (solo HTTP), sin segmentación de red | Perímetro / Red |
| Base de datos en el mismo equipo, sin aislamiento | Host / Red interna |

Estas debilidades son el punto de partida. A continuación se propone el **rediseño seguro**.

---

## 3. Arquitectura rediseñada segura (propuesta para el informe)

Esta es la arquitectura objetivo. Cumple lo que pide la rúbrica: flujo del cliente hasta la base de
datos con **API Gateway**, **servicio de identidad (IAM)**, **WAF** y **almacenamiento cifrado**.

```mermaid
flowchart TB
    subgraph CLIENTES["Clientes"]
        direction LR
        WEB["Navegador web"]
        MOV["App / navegador movil"]
    end

    subgraph EDGE["Borde (internet)"]
        direction TB
        CDN["CDN (Cloudflare / CloudFront)<br/>cache + anti-DDoS"]
        WAF["WAF<br/>reglas OWASP Top 10<br/>(SQLi, XSS, bots)"]
    end

    subgraph CLOUD["Nube (AWS o equivalente)"]
        direction TB
        GW["API Gateway<br/>TLS 1.3 en transito<br/>rate limiting"]
        IAM["Identidad: IAM / Cognito / Auth0<br/>MFA + menor privilegio<br/>roles: admin, gerente, cliente"]
        SEC["Secrets Manager / KMS<br/>claves y llaves de cifrado"]

        subgraph VPC["Red privada (VPC)"]
            direction TB
            subgraph PUB["Subred publica"]
                LB["Balanceador de carga"]
            end
            subgraph SAPP["Subred privada - aplicacion"]
                APP["WordPress + WooCommerce<br/>actualizado y endurecido<br/>solo HTTPS, sin phpMyAdmin"]
            end
            subgraph SDATA["Subred privada - datos"]
                DB[("Base de datos administrada (RDS)<br/>cifrada AES-256 con KMS<br/>sin acceso desde internet")]
                BK["Respaldos cifrados<br/>bucket privado"]
            end
        end

        SIEM["SIEM + Monitoreo<br/>(CloudWatch / Wazuh)<br/>logs y alertas"]
    end

    PAY["Pasarela de pago<br/>NeoNet (VisaNet Guatemala)"]

    WEB -->|"HTTPS"| CDN
    MOV -->|"HTTPS"| CDN
    CDN --> WAF --> GW
    GW -->|"valida token"| IAM
    GW --> LB --> APP
    APP -->|"TLS"| DB
    APP -->|"token seguro"| PAY
    APP -->|"lee claves"| SEC
    DB --> BK
    APP -.->|"envia logs"| SIEM
    GW -.->|"envia logs"| SIEM
    IAM -.->|"autoriza"| GW

    classDef sec fill:#d1e7dd,stroke:#0f5132,color:#0a3622;
    classDef edge fill:#cfe2ff,stroke:#084298,color:#052c65;
    class GW,IAM,SEC,APP,DB,BK,LB,SIEM sec;
    class CDN,WAF edge;
```

| Control que se agrega | Qué resuelve de la versión vulnerable |
|---|---|
| WAF | Bloquea SQLi, XSS y los ataques del OWASP Top 10 |
| API Gateway + TLS 1.3 | Cifra el tránsito, centraliza el acceso, oculta los servicios internos |
| IAM con menor privilegio y MFA | Evita el acceso no autorizado y la enumeración de usuarios |
| Base de datos administrada y cifrada (KMS) | Protege los datos en reposo, la aísla de la web |
| Red privada (VPC) con subredes | Separa la aplicación de la base de datos, no quedan en el mismo plano |

---

## 4. Componentes del repositorio

| Archivo / carpeta | Función |
|---|---|
| `docker-compose.yml` | Define los tres contenedores y la red local |
| `Dockerfile` | Construye la imagen de la tienda con los plugins vulnerables |
| `php-inseguro.ini` | Configuración PHP insegura intencional (errores visibles) |
| `plugins/` | WooCommerce y los seis plugins con CVE |
| `web-extra/` | Archivos expuestos a propósito (`info.php`, `adminer.php`) |
| `setup/instalar_tienda.sh` | Crea usuarios, productos y pedidos |
| `setup/mejorar_tienda.sh` | Idioma, imágenes, tema y limpieza |

---

## 5. Inventario rápido de activos (borrador para la Fase 1)

| Activo | Tipo | Ubicación | C | I | D |
|---|---|---|---|---|---|
| Datos de clientes (nombre, dirección, correo) | Información | Base de datos | Alta | Alta | Media |
| Pedidos y su historial | Información | Base de datos | Alta | Alta | Media |
| Credenciales de usuarios | Información | Base de datos | Alta | Alta | Alta |
| Configuración de pagos (pasarela) | Información | Base de datos | Alta | Alta | Media |
| Código de WordPress y plugins | Software | Contenedor wordpress | Media | Alta | Alta |
| Base de datos MariaDB | Software | Contenedor db | Alta | Alta | Alta |
| Servidor Apache / PHP | Servicios | Contenedor wordpress | Media | Media | Alta |

> C = Confidencialidad, I = Integridad, D = Disponibilidad. Valoración: Alta / Media / Baja.
> Esta tabla se amplía en el informe con propietario, custodio, criticidad calculada y justificación.
