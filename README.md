# EI1044_Ansible_Project

Automatización con **Ansible** de una pequeña infraestructura web con copias de seguridad, sobre un laboratorio local de contenedores Docker.

| Máquina    | Función                                        |
|------------|------------------------------------------------|
| `web01`    | Servidor web **nginx** con página generada con plantillas Jinja2 |
| `db01`     | Base de datos **PostgreSQL** (usuario, base de datos y datos de ejemplo) |
| `backup01` | Repositorio de copias de seguridad con **restic** |

Las copias van cifradas, con retención de **7 diarias, 4 semanales y 6 mensuales**, incluyen un volcado de la base de datos (`pg_dump`) y se ejecutan de forma programada. El playbook `restore.yml` restaura y verifica que la web y la base de datos vuelven a funcionar.

> **Fuera de alcance** (posibles ampliaciones): firewall, fail2ban, hardening de SSH, Molecule, monitorización, nube/Terraform.

---

## Equipo y reparto

> 🚧 **Pendiente:** completar con los nombres del equipo.

| Parte | Responsable |
|-------|-------------|
| Rol `common` + coordinación (repo, inventario, `site.yml`, Vault, lint) | _Pendiente_ |
| Rol `webserver` | _Pendiente_ |
| Rol `database` | _Pendiente_ |
| Rol `backup` | Juan Carmona |
| `restore.yml` | Los cuatro (cada uno su parte de verificación) |

---

## Requisitos

### Nodo de control

Un sistema **Linux** (probado en **Ubuntu**) con Python 3 y `pipx` o `venv`.

- Clonar el repositorio en una carpeta propia del usuario (por ejemplo, `~/`). Ansible **ignora** el `ansible.cfg` si la carpeta tiene permisos de escritura para todos (por ejemplo, `/tmp` o discos externos y de otros sistemas montados).
- **Docker Engine** con el plugin **Docker Compose** (`docker compose`), y el usuario en el grupo `docker` (`sudo usermod -aG docker $USER` y volver a iniciar sesión).

### Versiones de las herramientas

Las versiones están fijadas en [`requirements.txt`](requirements.txt) y deben ser las mismas para todo el equipo:

| Herramienta    | Versión | Notas                     |
|----------------|---------|---------------------------|
| `ansible`      | 14.x    | Incluye `ansible-core` 2.21.x |
| `ansible-lint` | 26.x    |                           |
| `yamllint`     | 1.x     |                           |

---

## Instalación

En un Ubuntu recién instalado, primero:

```bash
sudo apt install pipx python3-venv
pipx ensurepath        # añade ~/.local/bin al PATH (abrir terminal nueva)
```

**Opción A: pipx** (cada herramienta en su propio entorno aislado):

```bash
pipx install --include-deps 'ansible==14.*'
pipx install 'ansible-lint==26.*'
pipx install 'yamllint==1.*'
```

**Opción B: entorno virtual del proyecto:**

```bash
python3 -m venv .venv
source .venv/bin/activate        # en cada terminal nueva
pip install -r requirements.txt
```

Comprobación (desde la carpeta del proyecto):

```bash
ansible --version                # debe mostrar core 2.21.x
ansible-config dump --only-changed -t all   # opciones leídas de ansible.cfg
```

---

## Configuración del proyecto

| Fichero          | Para qué sirve |
|------------------|----------------|
| `ansible.cfg`    | Configuración común de Ansible: inventario, ruta de roles, usuario remoto `ansible`, salida en YAML y optimizaciones de SSH (pipelining, reutilización de conexiones). |
| `requirements.txt` | Versiones de las herramientas del nodo de control. |
| `.gitignore`     | Evita subir secretos, entornos de Python, cachés y ficheros de editores y del sistema operativo. |

> ⚠️ **Solo laboratorio:** `ansible.cfg` desactiva la comprobación de claves de host SSH (`host_key_checking = False`), porque los contenedores se recrean a menudo y cambian de clave. En un entorno real no se haría.

### Secretos

- **Nunca** se suben a Git la contraseña de Ansible Vault (`.vault_pass`) ni las claves SSH del laboratorio (`lab/ssh/*`).
- La contraseña de Vault se comparte por un canal privado del equipo.
- 🚧 **Pendiente:** configuración de Ansible Vault (`vault.yml` cifrado + `vault.yml.example`).

---

## Laboratorio

Tres contenedores Docker con Ubuntu 22.04, systemd y SSH, que se comportan como
servidores reales. La imagen se construye con `lab/Dockerfile` (a partir de
`geerlingguy/docker-ubuntu2204-ansible`) y las máquinas se definen en `lab/docker-compose.yml`.

| Máquina    | Grupo            | SSH (127.0.0.1) | Otros puertos | Volumen de datos |
|------------|------------------|-----------------|---------------|------------------|
| `web01`    | `webservers`     | 2201            | 8080 → 80     | —                |
| `db01`     | `databases`      | 2202            |               | `db_data` → `/var/lib/postgresql` |
| `backup01` | `backup_servers` | 2203            |               | `restic_repo` → `/srv/restic` |

Las máquinas se ven entre sí por su nombre (`db01`, `web01`, `backup01`) dentro de la red de Docker.

### Puesta en marcha (una sola vez)

1. Crear la clave SSH del laboratorio. **El nombre debe ser exactamente este**, porque es el que usa el inventario:
   ```bash
   ssh-keygen -t ed25519 -C "ansible-lab" -f ~/.ssh/id_ed25519_ansible_lab -N ""
   cp ~/.ssh/id_ed25519_ansible_lab.pub lab/ssh/authorized_keys
   ```
2. Construir y levantar las máquinas:
   ```bash
   docker compose -f lab/docker-compose.yml up -d --build
   ```
3. Comprobar la conexión (debe dar `ok=3 changed=0 failed=0` en las tres):
   ```bash
   ansible-playbook playbooks/ping.yml
   ```

### Comandos habituales

| Comando | Qué hace |
|---------|----------|
| `docker compose -f lab/docker-compose.yml ps` | Estado de las máquinas |
| `docker compose -f lab/docker-compose.yml stop` / `start` | Parar / arrancar sin perder nada |
| `docker compose -f lab/docker-compose.yml down` | Destruir las máquinas (los volúmenes se conservan) |
| `docker compose -f lab/docker-compose.yml down -v` | Destruir máquinas **y volúmenes**: laboratorio limpio |
| `docker exec -it db01 bash` | Entrar en una máquina como root |
| `ssh -i ~/.ssh/id_ed25519_ansible_lab -p 2202 ansible@127.0.0.1` | Entrar por SSH como Ansible |

### ⚠️ Los servicios no arrancan solos al instalarse

La imagen de Ubuntu para Docker incluye `/usr/sbin/policy-rc.d` con `exit 101`, que impide
que los paquetes arranquen sus servicios al instalarse (nginx, PostgreSQL...). Los roles
deben arrancarlos explícitamente, por ejemplo con `ansible.builtin.service` y `state: started`.

### ⚠️ Concesiones solo de laboratorio

- **Contenedores `privileged`**: systemd lo necesita. Por eso el Dockerfile enmascara
  `systemd-binfmt`, que si no borraría las reglas `binfmt_misc` del anfitrión
  (por ejemplo, rompe la ejecución de `.exe` en WSL o de `qemu` en Linux).
- **Clave SSH sin passphrase**, para que Ansible no dependa de `ssh-agent`.
- **`host_key_checking = False`**, y las tres máquinas comparten claves de host.
- Los puertos se publican **solo en `127.0.0.1`**: el laboratorio no es accesible desde la red.

---

## Uso

### Copias de seguridad

```bash
# Aplicar el rol backup (de momento, con una BD de ejemplo y la contraseña de pruebas)
ansible-playbook playbooks/test_backup.yml -e @~/.ansible-lab-secrets.yml

# Lanzar una copia en el momento
ansible-playbook playbooks/backup.yml

# Restaurar la base de datos desde la copia más reciente (sobrescribe la BD actual)
ansible-playbook playbooks/restore.yml -e backup_restore_confirmar=true
```

Detalles (variables, secretos, escenario de la demo, comandos útiles y pendientes) en
[`roles/backup/README.md`](roles/backup/README.md).

> 🚧 **Pendiente.** Comandos para desplegar todo (`site.yml`) y las verificaciones de `restore.yml`
> de los roles `database` y `webserver`.

---

## Estructura del repositorio

```
proyecto-ansible/
├── ansible.cfg · site.yml · requirements.txt · requirements.yml
├── .gitignore · .yamllint · .ansible-lint · Makefile
├── .github/          plantilla de PR y CI (lint)
├── docs/             arquitectura, reparto y guion de la demo
├── lab/              Dockerfile y docker-compose del laboratorio
├── inventory/        hosts.yml y variables por grupo (group_vars)
├── playbooks/        ping, backup, restore y pruebas por rol
└── roles/
    ├── common/       configuración base de todas las máquinas
    ├── webserver/    nginx + plantillas
    ├── database/     PostgreSQL
    └── backup/       restic, pg_dump, retención y programación
```

---

## Forma de trabajo

- Cada tarea se hace en su propia rama (`feature/...`) y llega a `main` mediante una **Pull Request** que el propio autor rellena con la plantilla y fusiona. No hay revisor: la PR sirve para que cada uno repase lo que ha hecho y para dejar explicado en el historial qué cambió y por qué.
- Variables con prefijo por rol: `web_`, `db_`, `backup_`. Las compartidas, en `inventory/group_vars/all/main.yml`.
- Una tarea está **hecha** cuando funciona sobre un laboratorio limpio, es idempotente (`changed=0` en la segunda ejecución), pasa `yamllint` y `ansible-lint` y tiene el README del rol actualizado.
- 🚧 **Pendiente:** detalles en [`CONTRIBUTING.md`](CONTRIBUTING.md).
