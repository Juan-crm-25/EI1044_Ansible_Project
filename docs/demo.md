# Guion de la demo: perder db01 y recuperarla

Requisitos: laboratorio levantado y `site.yml` aplicado **con los datos de ejemplo** (los 3
clientes que verifica `restore.yml`). El rol `database` no los carga por defecto:

```bash
ansible-playbook site.yml -e database_load_sample_data=true
```

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
4. Se reconstruye con Ansible, **sin** `-e database_load_sample_data=true`:
   ```bash
   ansible-playbook site.yml
   ```
   Si se pusiera, el rol `database` volvería a cargar los 3 clientes y la verificación del
   paso 5 pasaría aunque la restauración no hiciera nada. Sin él, la base de datos queda vacía
   y los datos solo pueden volver desde la copia.
5. Se recuperan los datos y se verifica que la web y la BD responden:
   ```bash
   ansible-playbook playbooks/restore.yml -e backup_restore_confirmar=true
   ```

Detalles del escenario en `roles/backup/README.md`.
