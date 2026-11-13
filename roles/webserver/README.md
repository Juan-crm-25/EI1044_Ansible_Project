# Rol `webserver`

Servidor web **nginx** con **PHP-FPM**. Publica un sitio generado con plantillas
**Jinja2** y una página de prueba (`clientes.php`) que lee la tabla `clientes` de la
base de datos PostgreSQL de **db01**.

## Qué hace

```
 Navegador                  web01                                       db01
 ┌───────────┐   :8080   ┌─────────────────────────────────┐  :5432  ┌────────────────┐
 │ 127.0.0.1 │──────────►│ nginx ── .html ─► /var/www/     │         │ PostgreSQL     │
 └───────────┘  (Docker) │   └── .php ─► PHP-FPM ──────────┼────────►│ BD app         │
                         │       lee /etc/proyecto/db.ini  │ usuario │ tabla clientes │
                         └─────────────────────────────────┘   app   └────────────────┘
                                                          (solo SELECT)
```

| Tarea (`tasks/main.yml`) | Qué hace |
|--------------------------|----------|
| Instalar nginx y PHP | `nginx`, `php-fpm` y `php-pgsql` (extensión de PostgreSQL para PHP) |
| Arrancar nginx y PHP-FPM | De forma explícita: en el laboratorio los servicios no arrancan solos al instalarse |
| Crear la carpeta de la web y copiar la portada | `index.html` generado con `templates/index.html.j2` |
| Copiar la configuración del sitio y activarlo | `templates/site.conf.j2` en `sites-available` y enlace en `sites-enabled` |
| Desactivar el sitio por defecto de nginx | Evita que dos sitios reclamen el `default_server` del puerto 80 |
| Copiar los datos de conexión con la BD | `templates/db.ini.j2` en `/etc/proyecto/db.ini`, **fuera** de la carpeta pública |
| Copiar la página de clientes | `templates/clientes.php.j2` |

Los cambios en la configuración de nginx avisan a los **handlers**, que primero la
**validan** (`nginx -t`) y solo después **recargan** nginx.

## Requisitos

- Ubuntu 22.04 (probado en los contenedores del laboratorio).
- Para `clientes.php`: una base de datos en **db01** que acepte conexiones desde web01
  (ver *Lo que necesita del rol `database`*).
- Probado con ansible-core 2.21, nginx 1.18 y PHP 8.1.

## Variables

Todas están en [`defaults/main.yml`](defaults/main.yml) y se pueden cambiar en
`inventory/group_vars/webservers/main.yml`.

| Variable | Valor por defecto | Para qué sirve |
|----------|-------------------|----------------|
| `webserver_site_name` | `proyecto` | Nombre del sitio (fichero de nginx y carpeta de configuración) |
| `webserver_port` | `80` | Puerto de nginx dentro de web01 (Docker lo publica en el 8080) |
| `webserver_root` | `/var/www/proyecto` | Carpeta pública de la web |
| `webserver_title` | `Proyecto Ansible - EI1044` | Título de las páginas |
| `webserver_php_version` | `8.1` | Versión de PHP (da nombre al servicio y al socket) |
| `webserver_php_fpm_socket` | `/run/php/php8.1-fpm.sock` | Socket entre nginx y PHP-FPM |
| `webserver_db_config` | `/etc/proyecto/db.ini` | Fichero con los datos de conexión |
| `webserver_db_host` / `_port` / `_name` / `_user` | `db_host` / `db_port` / `db_name` / `db_user` | Conexión con la BD: por defecto, las variables compartidas de `group_vars/all` |
| `webserver_db_password` | `db_password` (**obligatoria**) | Contraseña del usuario de la BD. Ver *Secretos* |

## Secretos

La contraseña de la base de datos (`db_password`) está **cifrada con Ansible Vault** en
`inventory/group_vars/all/vault.yml`. Ansible la descifra sola en cada ejecución con el
fichero `.vault_pass` de la raíz del proyecto (indicado en `ansible.cfg` y fuera de Git).
Es la **misma** contraseña que usa el rol `database` para crear el usuario, así que la web
y la base de datos no pueden quedar desincronizadas.

> !! No pases contraseñas con `-e`: las variables `-e` tienen la máxima prioridad en
> Ansible y **sustituirían** a las del Vault.

## Uso

```bash
ansible-playbook playbooks/test_webserver.yml
```

El playbook aplica primero el rol `database` en db01, con los datos de ejemplo
(`database_load_sample_data: true`), y después este rol en web01. Es idempotente: la
segunda ejecución da `changed=0`. Después:

- Portada: <http://127.0.0.1:8080>
- Clientes: <http://127.0.0.1:8080/clientes.php> (código **200** con la tabla; **500** si no
  puede leer la base de datos)

## Qué deja instalado en web01

| Ruta | Qué es |
|------|--------|
| `/var/www/proyecto/index.html` | Portada |
| `/var/www/proyecto/clientes.php` | Página que lee la tabla `clientes` |
| `/etc/nginx/sites-available/proyecto.conf` | Configuración del sitio (enlazada en `sites-enabled`) |
| `/etc/proyecto/db.ini` (`0640`, `root:www-data`) | Datos de conexión con la BD |

## Decisiones de diseño

- **Contraseña fuera de la carpeta pública**: si PHP fallara, nginx no podría servir
  `db.ini` como texto. Solo pueden leerlo root y PHP-FPM (`www-data`), y la tarea usa
  `no_log` para que la contraseña no aparezca en la salida de Ansible.
- **Usuario de aplicación, no el administrador**: la web se conecta con `appuser`, nunca
  con `postgres`, y solo desde la red del laboratorio.
- **Validar antes de recargar**: el handler ejecuta `nginx -t` antes del `reload`; si la
  configuración tiene errores, nginx sigue funcionando con la anterior.
- **`reload` y no `restart`**: aplica la configuración sin cortar las conexiones abiertas.
- **Errores sin información interna**: `@pg_connect` evita que PHP muestre la cadena de
  conexión, y la página responde **500** para que las comprobaciones automáticas detecten
  el fallo.
- **`htmlspecialchars`** en los datos mostrados (prevención de XSS) y `connect_timeout`
  para que la página no se quede colgada si db01 no responde.
- **Sin dependencias en `meta`**: la base de datos está en otra máquina; el orden entre
  máquinas lo decide `site.yml`, no el rol.

## Relación con los otros roles

- **`database`** (db01): crea la base de datos `db_name`, el usuario `db_user` con la
  contraseña `db_password` y la tabla `clientes`, y acepta conexiones desde web01
  (`listen_addresses` y una regla `scram-sha-256` en `pg_hba.conf`).
- **`restore.yml`**: tras restaurar una copia, su último play pide `clientes.php` y
  comprueba que responde **200** y muestra los clientes de ejemplo.
- **`site.yml`**: aplica este rol a `webservers` **después** del rol `database`.

## Posibles mejoras

- **Usuario de solo lectura para la web**: hoy `appuser` es dueño de la tabla, así que
  podría modificarla. Un usuario aparte con solo `SELECT` aplicaría mejor el principio de
  mínimo privilegio.
