# Rol `database`

Servidor de base de datos **PostgreSQL**: instala el servidor, lo deja aceptando conexiones de la
web por la red, crea un usuario, una base de datos y una tabla de ejemplo, y opcionalmente carga
unos datos de ejemplo conocidos.

Es la base sobre la que trabajan el rol [`webserver`](../webserver/README.md), cuya página
`clientes.php` lee esta base de datos desde web01, el rol [`backup`](../backup/README.md), que la
copia, y el playbook `restore.yml`, que la restaura y comprueba que los datos de ejemplo han vuelto.

```
 web01 (clientes.php) ──── TCP :5432, usuario appuser, contraseña ────► db01 (PostgreSQL, BD app)
 backup01 ◄──── pg_dump como postgres (local, peer) ──── db01
```

## Qué hace

| Fichero de tareas | Qué hace |
|-------------------|----------|
| `tasks/main.yml` | Comprueba la contraseña, instala PostgreSQL, lo configura para la red, lo arranca, y crea el usuario, la base de datos (vacía) y la tabla |
| `tasks/sample_data.yml` | Inserta 3 filas de ejemplo. Solo se ejecuta si `database_load_sample_data` es `true` |

Orden de ejecución: comprobar contraseña → paquetes → escuchar por la red → regla de `pg_hba.conf`
→ arrancar el servicio → usuario → base de datos → tabla → (datos de ejemplo).

La configuración de red se escribe **antes** de arrancar PostgreSQL: así la lee al iniciarse y no
hace falta reiniciarlo (por eso el rol no tiene handlers).

## Requisitos

- Ubuntu 22.04 (PostgreSQL 14). Probado con ansible-core 2.21.
- La colección `community.postgresql` (fijada en [`requirements.yml`](../../requirements.yml)).
  Viene incluida en el paquete `ansible`.
- Acceso a los repositorios de paquetes de Ubuntu desde `db01`.
- La variable compartida `db_password` (ver *Secretos*).

## Variables

Todas están en [`defaults/main.yml`](defaults/main.yml). Como el rol se ejecuta en **db01**, para
cambiarlas hay que usar `inventory/group_vars/databases/main.yml`.

El prefijo es el **nombre del rol** (`database_`), porque así lo exige `ansible-lint`.

| Variable | Valor por defecto | Para qué sirve |
|----------|-------------------|----------------|
| `database_name` | `app` | Nombre de la base de datos. El rol `backup` copia esta base de datos (`backup_db_name`) |
| `database_user` | `appuser` | Usuario de PostgreSQL, dueño de la base de datos y de la tabla. La web se conecta con él |
| `database_password` | `{{ db_password }}` | Contraseña del usuario: la misma que usa la web. Ver *Secretos* |
| `database_encoding` | `UTF8` | Codificación de la base de datos |
| `database_table` | `clientes` | Tabla de ejemplo |
| `database_load_sample_data` | `false` | Si es `true`, carga las 3 filas de ejemplo |
| `database_packages` | `postgresql`, `python3-psycopg2`, `acl` | Paquetes que se instalan |
| `database_pg_version` | `14` | Versión de PostgreSQL. Forma la ruta `/etc/postgresql/<versión>/main/` |
| `database_listen_addresses` | `"*"` | Direcciones en las que escucha PostgreSQL (por defecto solo escucharía en `localhost`) |
| `database_allowed_network` | `samenet` | Desde qué red se permite conectar por TCP: la subred del laboratorio, donde está web01 |

### Variables compartidas (`inventory/group_vars/all/main.yml`)

El rol `webserver` se conecta con estas variables, comunes a todo el proyecto. Deben coincidir con
las del rol:

| Variable compartida | Valor | Debe coincidir con |
|---------------------|-------|--------------------|
| `db_host` | `db01` | La máquina donde se aplica este rol |
| `db_port` | `5432` | El puerto por defecto de PostgreSQL (el rol no lo cambia) |
| `db_name` | `app` | `database_name` |
| `db_user` | `appuser` | `database_user` (la regla de `pg_hba.conf` solo deja entrar a este usuario) |
| `db_password` | (secreta) | La usa directamente `database_password` |

### Datos de ejemplo

Con `database_load_sample_data: true` la tabla `clientes (id, nombre, ciudad)` recibe estas filas:

| id | nombre | ciudad |
|----|--------|--------|
| 1 | Ana | Castelló |
| 2 | Luis | València |
| 3 | Marta | Alacant |

Son siempre las mismas: `restore.yml` las usa para comprobar que la restauración es correcta.

Por defecto **no se cargan**. Así, al reconstruir `db01` tras un desastre, la base de datos queda
**vacía** y los datos solo pueden volver desde la copia de seguridad (no desde este rol).

## Conexión por la red

Para que web01 pueda leer la base de datos, el rol hace dos cambios en la configuración de
PostgreSQL, sin editar los ficheros originales más de lo necesario:

| Qué | Dónde | Contenido |
|-----|-------|-----------|
| Escuchar por la red | `/etc/postgresql/14/main/conf.d/red.conf` (fichero propio) | `listen_addresses = '*'` |
| Permitir la conexión | Una línea añadida a `/etc/postgresql/14/main/pg_hba.conf` | `host app appuser samenet scram-sha-256` |

La regla es mínima: **un usuario, una base de datos, una red y con contraseña**. Cualquier otra
conexión por la red se rechaza (`no pg_hba.conf entry`). Las reglas locales que ya trae
`pg_hba.conf` no se tocan: el rol `backup` sigue usando `pg_dump` como `postgres` por *peer*.

## Secretos

La contraseña del usuario **no está en el rol**. `database_password` toma el valor de la variable
compartida `db_password`, la misma que usa la web; así los dos lados no pueden quedar
desincronizados. Si falta, el rol se detiene en su primera tarea con un mensaje claro (la tarea que
crea el usuario lleva `no_log`, y sin esta comprobación el error saldría oculto).

Mientras no exista el Vault, para probar se usa el fichero de secretos **fuera del repositorio**:

```bash
echo 'db_password: "root"' >> ~/.ansible-lab-secrets.yml
```

El mismo fichero lo usa el rol `backup`: para la demo (`test_backup.yml`) debe tener
**las dos** contraseñas:

| Variable | Rol | Para qué |
|----------|-----|----------|
| `db_password` | `database` y `webserver` | Contraseña del usuario `appuser` |
| `backup_restic_password` | `backup` | Cifrado de las copias de seguridad |

> ⚠️ Añade las líneas con `>>`. Con `>` el fichero se sobrescribe y se pierde la otra
> contraseña. Para comprobarlo: `cat ~/.ansible-lab-secrets.yml`.

> 🚧 **Pendiente (Vault):** definir `db_password` cifrada en `inventory/group_vars/all/vault.yml`
> (Persona 1) y añadirla a `vault.yml.example`. El rol no necesita cambios: ya lee `db_password`.

## Uso

Todos los comandos llevan el fichero de secretos (`-e @~/.ansible-lab-secrets.yml`).

**Aplicar el rol** y comprobar que los datos de ejemplo están:

```bash
ansible-playbook playbooks/test_database.yml -e @~/.ansible-lab-secrets.yml
```

Es idempotente: la segunda ejecución da `changed=0`. `--check --diff` solo tiene sentido **después**
de aplicarlo una vez: sobre un laboratorio vacío falla, porque unas tareas dependen de paquetes que
instalan otras.

**Comprobar la conexión por la red** (como lo haría la web):

```bash
# Funciona: appuser, con contraseña, por la red → Ana, Luis y Marta
docker exec -e PGPASSWORD=root db01 bash -c 'psql -h $(hostname -I | cut -d" " -f1) -U appuser -d app -c "SELECT * FROM clientes;"'

# Se rechaza: cualquier otro usuario por la red → "no pg_hba.conf entry"
docker exec -e PGPASSWORD=root db01 bash -c 'psql -h $(hostname -I | cut -d" " -f1) -U postgres -d app -c "SELECT 1;"'
```

Y desde el navegador, con el rol `webserver` aplicado: <http://127.0.0.1:8080/clientes.php>.

**Primer despliegue de la demo** (con datos de ejemplo):

```bash
ansible-playbook playbooks/test_backup.yml -e @~/.ansible-lab-secrets.yml -e database_load_sample_data=true
```

**Reconstruir db01** tras perderla (sin datos de ejemplo: la restauración los devuelve):

```bash
ansible-playbook playbooks/test_backup.yml -e @~/.ansible-lab-secrets.yml
ansible-playbook playbooks/restore.yml -e backup_restore_confirmar=true
```

**Comandos útiles en db01** (como root):

```bash
docker exec -it db01 bash
sudo -u postgres psql -d app -c 'SELECT * FROM clientes ORDER BY id;'
sudo -u postgres psql -c 'SHOW listen_addresses;'
systemctl status postgresql
```

## Decisiones de diseño

- **Servicio arrancado de forma explícita** (`state: started`): en el laboratorio los servicios no
  arrancan solos al instalarse (`policy-rc.d`).
- **Configuración de red antes de arrancar, sin handler**: `listen_addresses` solo se lee al
  arrancar. Como el fichero se escribe antes de la tarea que arranca el servicio, PostgreSQL ya
  escucha por la red al iniciarse. Si `db01` ya tuviera PostgreSQL en marcha de antes, hay que
  reconstruirla (como en la demo) o reiniciar el servicio una vez.
- **Fichero propio en `conf.d`** en vez de editar `postgresql.conf`: el `postgresql.conf` de Ubuntu
  ya incluye esa carpeta, y el cambio queda aislado y fácil de ver.
- **Regla de `pg_hba.conf` mínima** (`host`, un usuario, una base de datos, `samenet`,
  `scram-sha-256`): las reglas locales no se tocan, porque el rol `backup` ejecuta `pg_dump` como
  `postgres` por autenticación *peer*.
- **La web usa el dueño de la base de datos** (`appuser`): ya tiene permiso de lectura sobre la
  tabla, sin más tareas. Mejora posible: un usuario solo de lectura para la web.
- **Contraseña compartida** (`database_password: "{{ db_password }}"`): una sola contraseña para la
  web y la base de datos, sin valor en claro en el rol.
- **`become_user: postgres`**: PostgreSQL solo deja administrar al usuario del sistema `postgres`
  (autenticación *peer*). Por eso se instala `acl`, que Ansible necesita para ese cambio de usuario.
- **Base de datos creada con `template0` y locale `C.UTF-8`**: el clúster de un contenedor sin
  locale puede tener codificación `SQL_ASCII`, y entonces no se podría crear una base de datos
  `UTF8` desde la plantilla por defecto.
- **La base de datos se crea vacía**: `pg_restore` restaura **dentro** de ella.
- **Datos de ejemplo opcionales** (`database_load_sample_data`, desactivados por defecto): ver arriba.
- **Inserción idempotente** (`ON CONFLICT (id) DO NOTHING` y `changed_when` según las filas
  insertadas): la segunda ejecución no duplica datos ni da `changed`.
- **`no_log: true`** en la tarea del usuario: la contraseña no aparece en la salida de Ansible.
- **Los datos de PostgreSQL** están en `/var/lib/postgresql`, que es el volumen `db_data` del laboratorio.

## Qué deja instalado

| Máquina | Qué es |
|---------|--------|
| db01 | Paquetes `postgresql`, `python3-psycopg2` y `acl`; servicio `postgresql` activo y habilitado |
| db01 | `/etc/postgresql/14/main/conf.d/red.conf` y una regla nueva en `pg_hba.conf` |
| db01 | PostgreSQL escuchando en el puerto `5432` de todas las interfaces |
| db01 | Usuario `appuser`, base de datos `app` y tabla `clientes` (con 3 filas si se cargaron los datos de ejemplo) |
