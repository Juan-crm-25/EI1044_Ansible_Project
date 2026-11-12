# Rol `backup`

Copias de seguridad **cifradas** de la base de datos PostgreSQL con [restic](https://restic.net/),
con retención de **7 diarias, 4 semanales y 6 mensuales** y programación diaria con systemd.

Solo se copian los **datos** (la base de datos). La web y la configuración no se copian:
Ansible puede regenerarlas en cualquier momento desde el repositorio.

## Qué hace

El rol se aplica a **db01** y prepara también **backup01** mediante `delegate_to` (modelo *push*):

```
 db01                                          backup01
 ┌──────────────────────────────┐              ┌───────────────────────┐
 │ 1. pg_dump (como postgres)   │              │                       │
 │ 2. restic CIFRA el volcado ──┼─── SFTP ────►│ /srv/restic (repo)    │
 │ 3. restic forget --prune     │   (SSH)      │ solo datos cifrados   │
 │ 4. restic check              │              │                       │
 └──────────────────────────────┘              └───────────────────────┘
   temporizador systemd: todos los días a las 03:00 (Europe/Madrid)
```

| Fichero de tareas | Qué hace |
|-------------------|----------|
| `tasks/main.yml` | Comprueba que existe la contraseña e importa el resto |
| `tasks/restic.yml` | Instala restic, prepara backup01 (usuario y directorio), la confianza SSH, la contraseña y el `restic init` |
| `tasks/db_dump.yml` | Instala el script de copia (`templates/backup.sh.j2`) |
| `tasks/schedule.yml` | Instala y activa el servicio y el temporizador de systemd |
| `tasks/restore.yml` | Restauración. **No** la ejecuta el rol: la llama `playbooks/restore.yml` |

## Requisitos

- **db01** con PostgreSQL en marcha y la base de datos a copiar (rol `database`).
- **backup01** accesible **por su nombre** desde db01 (en el laboratorio, la red de Docker).
- Acceso a **Internet** desde db01: restic se descarga de GitHub.
- La contraseña de Ansible Vault en `.vault_pass` (ver el README general).
- Las colecciones de [`requirements.yml`](../../requirements.yml) (el rol usa `community.general`
  y `ansible.posix`). Vienen incluidas en el paquete `ansible`.
- Probado con ansible-core 2.21, Ubuntu 22.04, PostgreSQL 14 y restic 0.19.1.

## Variables

Todas están en [`defaults/main.yml`](defaults/main.yml). Como el rol se ejecuta en **db01**, para
cambiarlas hay que usar `inventory/group_vars/databases/main.yml` (no `backup_servers`).

| Variable | Valor por defecto | Para qué sirve |
|----------|-------------------|----------------|
| `backup_restic_password` | — (**obligatoria**) | Contraseña de cifrado del repositorio. Ver *Secretos* |
| `backup_repo_host` | `backup01` | Máquina del repositorio |
| `backup_repo_user` | `restic` | Usuario de SFTP en esa máquina |
| `backup_repo_path` | `/srv/restic` | Ruta del repositorio (volumen `restic_repo` en el laboratorio) |
| `backup_repo_url` | `sftp:restic@backup01:/srv/restic` | Se construye con las tres anteriores |
| `backup_restic_version` | `0.19.1` | Versión de restic que se descarga |
| `backup_restic_bin` | `/usr/local/bin/restic` | Dónde se instala restic |
| `backup_restic_arch_map` | `x86_64: amd64`, `aarch64: arm64` | Traducción de la arquitectura al nombre de la descarga |
| `backup_db_name` | `"{{ database_name }}"` | Base de datos que se copia: la del rol `database` |
| `backup_script` | `/usr/local/sbin/backup-db.sh` | Ruta del script de copia |
| `backup_keep_daily` / `_weekly` / `_monthly` | `7` / `4` / `6` | Retención |
| `backup_schedule` | `*-*-* 03:00:00 Europe/Madrid` | Cuándo se hace la copia (formato `OnCalendar` de systemd) |
| `backup_restore_snapshot` | `latest` | Copia a restaurar: la más reciente o el identificador de un snapshot |
| `backup_restore_confirmar` | `false` | Hay que ponerla a `true` para restaurar (sobrescribe la BD) |

## Secretos

`backup_restic_password` **no tiene valor por defecto a propósito**: si falta, el rol falla.
Está cifrada en Ansible Vault, en `inventory/group_vars/all/vault.yml`. Ansible la descifra
sola con la contraseña de `.vault_pass`.

> ⚠️ Sin esta contraseña **todas las copias son irrecuperables**. Hay que guardar una copia de
> ella fuera del repositorio.

> ⚠️ **No pases contraseñas con `-e`**: `-e` tiene más prioridad que el Vault y la sustituiría.
> El repositorio quedaría con otra contraseña y las copias dejarían de poder abrirlo.

## Uso

**Aplicar el rol** (junto con el rol `database`, que crea la base de datos que se copia):

```bash
ansible-playbook playbooks/test_backup.yml
```

Es idempotente: la segunda ejecución da `changed=0`. `--check --diff` solo tiene sentido
**después** de aplicarlo una vez: sobre un laboratorio vacío falla, porque unas tareas
dependen de paquetes que instalan otras.

**Lanzar una copia en el momento** (el mismo servicio que usa el temporizador):

```bash
ansible-playbook playbooks/backup.yml
```

Muestra el registro de la copia y termina con el identificador del snapshot. Es un **playbook
de acción**: cada ejecución hace una copia, así que **siempre da `changed=1`**. No es un fallo
de idempotencia.

**Restaurar la base de datos** desde la copia más reciente, o desde una concreta:

```bash
ansible-playbook playbooks/restore.yml -e backup_restore_confirmar=true
ansible-playbook playbooks/restore.yml -e backup_restore_confirmar=true -e backup_restore_snapshot=a29046bf
```

Sin `backup_restore_confirmar=true` se niega, porque **sobrescribe** la base de datos. La
restauración se hace en una sola transacción (`pg_restore --single-transaction`): si algo falla,
la base de datos queda como estaba. Antes hay que haber aplicado el rol `backup` en db01
(con `site.yml`).

**Escenario de la demo: perder db01 y recuperarla**

```bash
ansible-playbook playbooks/backup.yml                    # 1. copia reciente
docker compose -f lab/docker-compose.yml rm -sf db01     # 2. desastre: se pierde db01...
docker volume rm ansible-lab_db_data                     #    ...con sus datos (el repo de backup01 sobrevive)
docker compose -f lab/docker-compose.yml up -d db01      # 3. db01 nueva y vacía
ansible-playbook site.yml                                # 4. reconstruir (hoy: playbooks/test_backup.yml)
ansible-playbook playbooks/restore.yml -e backup_restore_confirmar=true   # 5. recuperar los datos
```

Al volver a aplicar el rol, la db01 nueva se conecta al **mismo repositorio** (el `restic init`
se salta porque ya existe) y su clave SSH nueva **sustituye** a la de la máquina perdida en
backup01 (`exclusive: true`).

**Comandos útiles en db01** (como root):

```bash
set -a; . /etc/restic/restic.env; set +a   # cargar el acceso al repositorio
restic snapshots --tag postgres            # listar las copias
restic dump latest /app.dump | pg_restore --list   # ver el contenido de la última
systemctl list-timers backup-db.timer      # próxima ejecución
journalctl -u backup-db.service            # registro de las copias
systemctl status backup-db.service         # 'failed' si la última copia falló
```

## Qué deja instalado

| Máquina | Ruta | Qué es |
|---------|------|--------|
| db01 | `/usr/local/bin/restic` | Binario de restic |
| db01 | `/etc/restic/password` (0600) | Contraseña del repositorio |
| db01 | `/etc/restic/restic.env` (0600) | `RESTIC_REPOSITORY` y `RESTIC_PASSWORD_FILE` |
| db01 | `/usr/local/sbin/backup-db.sh` (0700) | Script de copia |
| db01 | `/etc/systemd/system/backup-db.{service,timer}` | Servicio y temporizador |
| db01 | `/root/.ssh/id_ed25519_restic`, `config`, `known_hosts` | Acceso SSH a backup01 |
| db01 | `/var/cache/restic` | Caché de restic (se puede borrar) |
| backup01 | usuario `restic` | Dueño del repositorio; su clave solo permite SFTP |
| backup01 | `/srv/restic` (0700) | Repositorio restic (formato v2, cifrado) |

## Decisiones de diseño

- **Modelo *push***: db01 cifra **antes de enviar**, así que backup01 nunca ve los datos sin
  cifrar, y PostgreSQL no tiene que abrirse a la red.
- **Clave SSH solo para SFTP** (`restrict,command="/usr/lib/openssh/sftp-server"` en
  `authorized_keys`): con ella no se puede abrir una terminal ni hacer túneles (mínimo privilegio).
- **Huella de backup01 leída con `slurp`** (no con `ssh-keyscan` por la red) y registrada en
  `known_hosts`: la conexión de las copias sí verifica con quién habla.
- **restic oficial con versión fijada** y descarga verificada con `SHA256SUMS`.
- **`restic backup --stdin-from-command`**: si `pg_dump` falla no se guarda el snapshot, y no
  queda ninguna copia sin cifrar en el disco de db01.
- **`pg_dump --format=custom --compress=0`**: restic ya comprime y, sin la compresión de
  `pg_dump`, deduplica entre copias (en una prueba, la copia del día siguiente ocupó 1,2 MiB en
  vez de 5,8 MiB).
- **Temporizador de systemd** con `Persistent=true` (si la máquina estaba apagada, hace la copia
  al arrancar) y zona horaria en `OnCalendar` (las 03:00 españolas aunque la máquina esté en UTC).
- **`CacheDirectory=restic`**: systemd no define `$HOME` y restic necesita una caché.

## Integración con otras partes

El rol `backup` depende de lo que hacen otras partes del proyecto. **Si alguna de estas cosas
cambia, las copias o la restauración pueden dejar de funcionar.**

| De | Qué necesita el rol `backup` |
|----|------------------------------|
| Rol `database` | Que defina `database_name` (la usa `backup_db_name`), arranque PostgreSQL y cree la base de datos: `pg_restore` restaura **dentro** de ella |
| Rol `database` | Que mantenga la autenticación *peer* local del usuario `postgres` en `pg_hba.conf`: `pg_dump` y `pg_restore` la usan |
| Rol `database` | Que los datos de PostgreSQL estén en `/var/lib/postgresql` (el volumen `db_data` del laboratorio) |
| Vault | `backup_restic_password` en `inventory/group_vars/all/vault.yml` |
| `playbooks/restore.yml` | Después de restaurar, las verificaciones de los roles `database` (los clientes de ejemplo) y `webserver` (la web los muestra) |
| `site.yml` | Reconstruye db01 antes de restaurar. Mientras no esté en `main`, se usa `playbooks/test_backup.yml` |
