# Guion de la demo: perder db01 y recuperarla

Requisitos: laboratorio levantado, `site.yml` aplicado y la base de datos con datos de ejemplo.

1. Copia reciente:
   ```bash
   ansible-playbook playbooks/backup.yml
   ```
2. Se pierde db01 con sus datos (comprobar el nombre del volumen con `docker volume ls`):
   ```bash
   docker compose -f lab/docker-compose.yml rm -sf db01
   docker volume rm ansible-lab_db_data
   ```
3. Aparece una db01 nueva y vacía:
   ```bash
   docker compose -f lab/docker-compose.yml up -d db01
   ```
4. Se reconstruye con Ansible:
   ```bash
   ansible-playbook site.yml
   ```
5. Se recuperan los datos y se verifica que la web y la BD responden:
   ```bash
   ansible-playbook playbooks/restore.yml -e backup_restore_confirmar=true
   ```

Detalles del escenario en `roles/backup/README.md`.
