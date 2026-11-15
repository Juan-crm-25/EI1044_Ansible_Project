# Cómo contribuir

## Flujo de trabajo

1. `git switch main && git pull`
2. Una rama por tarea: `git switch -c feature/<tarea>`
3. Commits pequeños con prefijo: `common:`, `webserver:`, `database:`, `backup:`, `lab:`, `docs:`, `ci:`.
4. Antes de subir: lint y pruebas (ver abajo).
5. `git push -u origin feature/<tarea>` y abrir la Pull Request con la plantilla.
   No hay revisor: el autor la rellena y la fusiona; sirve para dejar explicado qué cambió y por qué.
6. Tras fusionar: `git switch main && git pull` y borrar la rama.

## Variables

- Dentro de un rol, **todas** las variables empiezan por el nombre completo del rol
  (`common_`, `webserver_`, `database_`, `backup_`). `ansible-lint` lo exige, y también
  a las que se crean con `register` o `set_fact`.
- Las variables compartidas entre roles van en `inventory/group_vars/all/main.yml`. Los valores
  están en `database_*` y se exponen como `db_host`, `db_port`, `db_name`, `db_user` y
  `db_password`, que son las que usan el resto de roles (por ejemplo `backup_db_name: "{{ db_name }}"`).
  Fuera de los roles no se aplica la regla del prefijo.
- Una variable se define en un solo sitio, para no tener valores contradictorios.
- Los valores de grupo van en `inventory/group_vars/<grupo>/main.yml`.

## Secretos

- Nunca en claro en el repositorio. `.vault_pass` y `lab/ssh/*` están en `.gitignore`.
- Los secretos (`backup_restic_password`, `database_password`) van en
  `inventory/group_vars/all/vault.yml`, siempre cifrado: debe empezar por
  `$ANSIBLE_VAULT;1.1;AES256`. Comprobarlo con `head -1` antes de `git add`.
- La contraseña del Vault se comparte por un canal privado. Cada uno la guarda en su `.vault_pass`.
- Para editar el Vault: `ansible-vault edit inventory/group_vars/all/vault.yml`.

## Definición de "hecho"

- Funciona sobre un laboratorio limpio (`make clean` y `make up`).
- Es idempotente: la segunda ejecución da `changed=0` (salvo `backup.yml` y `restore.yml`).
- `--check --diff` también da `changed=0`.
- Pasa `yamllint` y `ansible-lint`.
- El README del rol está actualizado.

## Cómo probar un rol

    ansible-playbook playbooks/test_<rol>.yml
    ansible-playbook playbooks/test_<rol>.yml
    ansible-playbook playbooks/test_<rol>.yml --check --diff

## Lint

    make lint

Mientras haya playbooks vacíos, se pasan las rutas concretas en lugar del repositorio entero.

## Errores típicos de lint

- Módulos con nombre completo: `ansible.builtin.copy`, no `copy`.
- `become: true` junto a cada `become_user`.
- `changed_when` en `command` y `shell`.
- Permisos entre comillas: `mode: "0644"`.
- Nombres de tarea que empiezan por mayúscula.
- En los módulos de PostgreSQL, `login_db` y no `db`.
- Los servicios no arrancan solos al instalar paquetes en el laboratorio: arrancarlos
  explícitamente con `ansible.builtin.service`.

## Saltos de línea (Windows/WSL)

Los ficheros deben tener saltos de línea de Linux (LF). Con Git en Windows o WSL, configurar
`git config --global core.autocrlf input`; con CRLF, `yamllint` falla y los scripts de las plantillas
no funcionan en los contenedores.
