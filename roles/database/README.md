# Rol `database`

Servidor de base de datos **PostgreSQL**: instala el servidor, crea un usuario, una base de datos
y una tabla de ejemplo, y opcionalmente carga unos datos de ejemplo conocidos.

Es la base sobre la que trabaja el rol [`backup`](../backup/README.md), que copia esta base de datos,
y el playbook `restore.yml`, que la restaura y comprueba que los datos de ejemplo han vuelto.

## Qué hace

| Fichero de tareas | Qué hace |
|-------------------|----------|
| `tasks/main.yml` | Instala PostgreSQL, lo arranca, y crea el usuario, la base de datos (vacía) y la tabla |
| `tasks/sample_data.yml` | Inserta 3 filas de ejemplo. Solo se ejecuta si `database_load_sample_data` es `true` |

Orden de ejecución: paquetes → servicio → usuario → base de datos → tabla → (datos de ejemplo).

## Requisitos

- Ubuntu 22.04 (PostgreSQL 14). Probado con ansible-core 2.21.
- La colección `community.postgresql` (fijada en [`requirements.yml`](../../requirements.yml)).
  Viene incluida en el paquete `ansible`.
- Acceso a los repositorios de paquetes de Ubuntu desde `db01`.

## Variables

Todas están en [`defaults/main.yml`](defaults/main.yml). Como el rol se ejecuta en **db01**, para
cambiarlas hay que usar `inventory/group_vars/databases/main.yml`.

El prefijo es el **nombre del rol** (`database_`), porque así lo exige `ansible-lint`.

| Variable | Valor por defecto | Para qué sirve |
|----------|-------------------|----------------|
| `database_name` | `app` | Nombre de la base de datos. El rol `backup` copia esta base de datos (`backup_db_name`) |
| `database_user` | `appuser` | Usuario de PostgreSQL, dueño de la base de datos y de la tabla |
| `database_password` | `password` (**temporal**) | Contraseña del usuario. Ver *Secretos* |
| `database_encoding` | `UTF8` | Codificación de la base de datos |
| `database_table` | `clientes` | Tabla de ejemplo |
| `database_load_sample_data` | `false` | Si es `true`, carga las 3 filas de ejemplo |
| `database_packages` | `postgresql`, `python3-psycopg2`, `acl` | Paquetes que se instalan |

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

## Secretos

> 🚧 **Pendiente (Vault):** `database_password` tiene ahora un valor en claro (`password`) solo
> para el laboratorio. Debe pasar a Ansible Vault, igual que `backup_restic_password`:
> definirla cifrada en `inventory/group_vars/all/vault.yml`, añadirla a `vault.yml.example` y
> **eliminar** el valor de `defaults/main.yml`.

## Uso

**Aplicar el rol** y comprobar que los datos de ejemplo están:

```bash
ansible-playbook playbooks/test_database.yml
```

Es idempotente: la segunda ejecución da `changed=0`. `--check --diff` solo tiene sentido **después**
de aplicarlo una vez: sobre un laboratorio vacío falla, porque unas tareas dependen de paquetes que
instalan otras.

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
systemctl status postgresql
```

## Decisiones de diseño

- **Servicio arrancado de forma explícita** (`state: started`): en el laboratorio los servicios no
  arrancan solos al instalarse (`policy-rc.d`).
- **`become_user: postgres`**: PostgreSQL solo deja administrar al usuario del sistema `postgres`
  (autenticación *peer*). Por eso se instala `acl`, que Ansible necesita para ese cambio de usuario.
- **`pg_hba.conf` no se toca**: el rol `backup` ejecuta `pg_dump` como `postgres` por autenticación
  *peer*, y no debe desactivarse.
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
| db01 | Usuario `appuser`, base de datos `app` y tabla `clientes` (con 3 filas si se cargaron los datos de ejemplo) |
