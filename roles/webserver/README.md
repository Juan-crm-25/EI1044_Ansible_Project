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

`db_password` no tiene valor por defecto: debe ir cifrada en Ansible Vault. Mientras no
exista, para probar se usa un fichero **fuera del repositorio**:

```bash
umask 077
[ -f ~/.ansible-lab-secrets.yml ] || echo '---' > ~/.ansible-lab-secrets.yml
printf 'db_password: "%s"\n' "$(openssl rand -base64 24)" >> ~/.ansible-lab-secrets.yml
```

## Uso

```bash
ansible-playbook playbooks/test_webserver.yml -e @~/.ansible-lab-secrets.yml
```

Es idempotente: la segunda ejecución da `changed=0`. Después:

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
- **Mínimo privilegio en la BD**: la web usa el usuario `app`, con permiso **solo de
  lectura** (`SELECT`) sobre `clientes`.
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

## Lo que necesita del rol `database`

`playbooks/test_webserver.yml` incluye un play **provisional** que prepara en db01 lo que
necesita la web. Cuando exista el rol `database`, debe encargarse de:

1. Crear la base de datos `db_name` y el usuario `db_user` con la contraseña `db_password`.
2. Darle a ese usuario permiso `SELECT` sobre la tabla `clientes` (con datos de ejemplo).
3. Aceptar conexiones por la red: `listen_addresses` y una regla en `pg_hba.conf` para
   `db_user` desde la red del laboratorio con `scram-sha-256`.

## Pendiente

- **Rol `database`**: sustituir el play provisional de `test_webserver.yml` por ese rol
  (marcado con `PENDIENTE (rol database)`).
- **Vault**: `db_password` cifrada en `inventory/group_vars/all/vault.yml`.
- **`restore.yml`**: play que verifique que la web responde tras una restauración.
