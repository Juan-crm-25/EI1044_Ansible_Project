# Rol common

Configuración base de todas las máquinas: paquetes, zona horaria, sincronización de hora y locale.

## Qué hace

- Instala los paquetes base de `common_packages`.
- Fija la zona horaria (`/etc/localtime` y `/etc/timezone`).
- Genera el locale y lo deja como valor por defecto del sistema.
- Instala `chrony`. Solo lo arranca fuera de contenedores, porque en el laboratorio
  los contenedores comparten el reloj del anfitrión.

## Variables (`defaults/main.yml`)

| Variable | Por defecto | Descripción |
|----------|-------------|-------------|
| `common_timezone` | `Europe/Madrid` | Zona horaria del sistema |
| `common_locale` | `es_ES.UTF-8` | Locale del sistema |
| `common_packages` | ver fichero | Paquetes base |

## Uso

    ansible-playbook playbooks/test_common.yml

## Notas

- Los contenedores del laboratorio arrancan en UTC; este rol los pone en hora española.
  La programación de las copias (rol backup) ya lleva su propia zona horaria.
- Idempotente: la segunda ejecución da `changed=0`.
