# Atajos del proyecto. Cada comando empieza por ">" en lugar de un tabulador.
.RECIPEPREFIX := >
.DEFAULT_GOAL := help

COMPOSE := docker compose -f lab/docker-compose.yml
LINT_PATHS := roles/common roles/backup site.yml playbooks/backup.yml playbooks/restore.yml playbooks/test_backup.yml playbooks/test_common.yml

.PHONY: help up down clean ping site lint

help: ## Muestra esta ayuda
> @grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | sed 's/:.*## /\t/'

up: ## Levanta el laboratorio
> $(COMPOSE) up -d --build

down: ## Destruye las máquinas (conserva los volúmenes)
> $(COMPOSE) down

clean: ## Laboratorio limpio: borra máquinas y volúmenes
> $(COMPOSE) down -v

ping: ## Comprueba la conexión con las máquinas
> ansible-playbook playbooks/ping.yml

site: ## Despliega todo
> ansible-playbook site.yml

lint: ## Pasa yamllint y ansible-lint
> yamllint .
> ansible-lint $(LINT_PATHS)
