<!--
Título de la PR: "<rol>: <resumen>"   (p. ej. "backup: inicializar repositorio restic")
Rellena la plantilla antes de fusionar tú mismo la PR: repasa lo que has hecho y
deja la explicación que quedará en el historial.
Los comentarios como este no se ven en la PR publicada.
-->

## Qué cambia
<!-- Resumen breve: qué ficheros o tareas, y para qué. -->

## Por qué
<!-- Decisiones tomadas y alternativas descartadas. Si hay issue: "Closes #N". -->

## Parte afectada
- [ ] Base del proyecto / rol `common`
- [ ] Rol `webserver`
- [ ] Rol `database`
- [ ] Rol `backup`
- [ ] `restore.yml`
- [ ] Laboratorio (`lab/`)
- [ ] Documentación

## Cómo se ha probado
<!-- Comandos ejecutados y resultado. Pega el PLAY RECAP de la segunda ejecución. -->
```
ansible-playbook playbooks/test_<rol>.yml --check --diff
ansible-playbook playbooks/test_<rol>.yml    # 1.ª ejecución
ansible-playbook playbooks/test_<rol>.yml    # 2.ª ejecución → changed=0
```

## Checklist de "hecho"
<!-- Si algo no aplica a esta PR, escríbelo: "- [x] N/A: no hay playbook". -->
- [ ] Funciona sobre un laboratorio limpio (recreado desde cero)
- [ ] Idempotente: la segunda ejecución da `changed=0`
- [ ] `yamllint .` y `ansible-lint` sin errores
- [ ] Variables con el prefijo del rol (`web_`, `db_`, `backup_`)
- [ ] Sin secretos en claro (contraseñas en Vault; ni `.vault_pass` ni claves SSH)
- [ ] README del rol actualizado
