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

## 2. Cómo está construida hoy (versión vulnerable)

El laboratorio levanta **tres contenedores** Docker que se comunican entre sí en una red local. Todo
queda publicado solo en `127.0.0.1`, nunca en internet.

```mermaid
flowchart LR
    U["Cliente / Atacante<br/>(navegador)"]
    A["Administrador"]

    subgraph HOST["Equipo local — Docker (127.0.0.1)"]
        direction TB
        subgraph WPC["Contenedor: wordpress (puerto 8080)"]
            WP["Apache 2.4 + PHP 7.4<br/>WordPress 6.1 + WooCommerce 7.9<br/>6 plugins con CVE conocidos"]
            EXP["Archivos expuestos a proposito:<br/>info.php · adminer.php · respaldo_tienda.sql"]
        end
        PMA["Contenedor: phpMyAdmin<br/>(puerto 8081)"]
        DB[("Contenedor: MariaDB 10.6<br/>base de datos 'tienda'<br/>clientes · pedidos · pagos")]
    end

    U -->|"HTTP 8080"| WP
    A -->|"HTTP 8081"| PMA
    WP -->|"SQL 3306"| DB
    PMA -->|"SQL 3306"| DB
    EXP -.->|"fuga de informacion"| DB

    classDef vuln fill:#f8d7da,stroke:#a3262a,color:#58151c;
    classDef db fill:#d1e7dd,stroke:#0f5132,color:#0a3622;
    class WP,EXP vuln;
    class DB db;
```

### Flujo de datos

1. El cliente abre la tienda en el navegador por el **puerto 8080**.
2. Apache ejecuta el código PHP de WordPress y WooCommerce.
3. WordPress consulta la base de datos **MariaDB** por el puerto 3306 para leer productos, usuarios
   y pedidos.
4. El administrador gestiona la base de datos por **phpMyAdmin** en el puerto 8081.

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
flowchart LR
    U["Cliente<br/>(web / movil)"]

    subgraph CLOUD["Nube (AWS o equivalente)"]
        direction TB
        WAF["CDN + WAF<br/>(Cloudflare / AWS WAF)<br/>bloquea OWASP Top 10"]
        GW["API Gateway<br/>TLS 1.3 en transito"]
        IAM["Servicio de identidad<br/>(IAM / Cognito / Auth0)<br/>menor privilegio + MFA"]

        subgraph VPC["Red privada (VPC) — subredes aisladas"]
            direction TB
            APP["WordPress + WooCommerce<br/>actualizado y endurecido"]
            DB[("Base de datos administrada<br/>cifrada AES-256 con KMS")]
        end
    end

    U -->|"HTTPS"| WAF --> GW
    GW -->|"valida token"| IAM
    GW --> APP
    APP -->|"TLS"| DB
    IAM -.->|"autoriza"| GW

    classDef sec fill:#d1e7dd,stroke:#0f5132,color:#0a3622;
    class WAF,GW,IAM,DB sec;
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
| Configuración de pagos (Stripe) | Información | Base de datos | Alta | Alta | Media |
| Código de WordPress y plugins | Software | Contenedor wordpress | Media | Alta | Alta |
| Base de datos MariaDB | Software | Contenedor db | Alta | Alta | Alta |
| Servidor Apache / PHP | Servicios | Contenedor wordpress | Media | Media | Alta |

> C = Confidencialidad, I = Integridad, D = Disponibilidad. Valoración: Alta / Media / Baja.
> Esta tabla se amplía en el informe con propietario, custodio, criticidad calculada y justificación.
