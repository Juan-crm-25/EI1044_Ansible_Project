# Reparto

| Persona | Parte | Contenido |
|---------|-------|-----------|
| Jose Manuel | common + coordinación | Rol common, `site.yml`, Vault, variables compartidas, lint y CI, Makefile, documentación y presentación |
| Paco | webserver | nginx, plantillas Jinja2, handlers, variables `webserver_*` |
| Joel | database | PostgreSQL, usuario, base de datos con datos de ejemplo, variables `database_*` |
| Juan Carmona | backup | restic, volcado de la BD, programación, retención, `backup.yml` y restauración, y la configuración inicial del laboratorio y del lint |
| Los cuatro | restore.yml | Cada uno escribe la verificación de su parte |

## Dependencias

- backup necesita de database el nombre de la BD y la forma de conexión (`database_name`, `database_user`...,
  expuestas como `db_name`, `db_user`...).
- backup necesita de common la zona horaria.
- backup necesita del Vault la contraseña de restic (`backup_restic_password`).
- Todos necesitan de `site.yml` y del lint de la parte de coordinación.
