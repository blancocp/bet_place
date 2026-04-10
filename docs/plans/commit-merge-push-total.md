# Commit, merge y push a development/main

## Alcance confirmado

- Rama actual con cambios pendientes.
- Destino: `development` y `main`.

## Pasos

- Revisar estado de git para identificar cambios staged/unstaged y archivos nuevos.
- Revisar diff completo para validar qué entra al commit (incluyendo la nueva guía en `docs`).
- Revisar últimos commits para mantener estilo de mensaje (`[dev-NNN] ...`).
- Crear un commit único y coherente con todos los cambios funcionales pendientes.
- Cambiar a `development`, mezclar la rama de trabajo y resolver conflictos si aparecen.
- Hacer push de `development` a remoto.
- Cambiar a `main`, mezclar `development` y resolver conflictos si aparecen.
- Hacer push de `main` a remoto.
- Verificar estado final limpio y reportar resumen de commits/merges realizados.

## Validación final

- `git status` sin cambios pendientes en las ramas destino.
- Confirmar hashes de merge commit (si aplica) y ramas remotas actualizadas.
