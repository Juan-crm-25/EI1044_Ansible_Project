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

Cada miembro trabaja desde su portátil con **Windows + WSL2 (Ubuntu)**.

- Trabajar siempre dentro de WSL, en `~/`, **nunca en `/mnt/c/...`**: Ansible ignora el `ansible.cfg` en carpetas con permisos de escritura para todos.
- **Docker Desktop** con la integración WSL activada para la distro de Ubuntu (*Settings → Resources → WSL Integration*).

### Versiones de las herramientas

Las versiones están fijadas en [`requirements.txt`](requirements.txt) y deben ser las mismas para todo el equipo:

| Herramienta    | Versión | Notas                     |
|----------------|---------|---------------------------|
| `ansible`      | 14.x    | Incluye `ansible-core` 2.21.x |
| `ansible-lint` | 26.x    |                           |
| `yamllint`     | 1.x     |                           |

---

## Instalación

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
| `.gitignore`     | Evita subir secretos, entornos de Python, cachés y ficheros de editores o de WSL. |

> ⚠️ **Solo laboratorio:** `ansible.cfg` desactiva la comprobación de claves de host SSH (`host_key_checking = False`), porque los contenedores se recrean a menudo y cambian de clave. En un entorno real no se haría.

### Secretos

- **Nunca** se suben a Git la contraseña de Ansible Vault (`.vault_pass`) ni las claves SSH del laboratorio (`lab/ssh/*`).
- La contraseña de Vault se comparte por un canal privado del equipo.
- 🚧 **Pendiente:** configuración de Ansible Vault (`vault.yml` cifrado + `vault.yml.example`).

---

## Laboratorio

> 🚧 **Pendiente.** Contenedores Docker con systemd + SSH (`lab/Dockerfile`, `lab/docker-compose.yml`).

| Máquina    | Puerto SSH | Otros puertos |
|------------|-----------|---------------|
| `web01`    | 2201      | 8080 → 80     |
| `db01`     | 2202      |               |
| `backup01` | 2203      |               |

---

## Uso

> 🚧 **Pendiente.** Comandos para levantar el laboratorio, comprobar la conexión (`ansible all -m ping`), desplegar (`site.yml`), lanzar copias (`playbooks/backup.yml`) y restaurar (`playbooks/restore.yml`).

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

- `main` protegida: una rama por tarea (`feature/...`) y Pull Request con revisión cruzada.
- Variables con prefijo por rol: `web_`, `db_`, `backup_`. Las compartidas, en `inventory/group_vars/all/main.yml`.
- Una tarea está **hecha** cuando funciona sobre un laboratorio limpio, es idempotente (`changed=0` en la segunda ejecución), pasa `yamllint` y `ansible-lint` y tiene el README del rol actualizado.
- 🚧 **Pendiente:** detalles en [`CONTRIBUTING.md`](CONTRIBUTING.md).
