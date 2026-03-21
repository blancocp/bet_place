---
name: Mezclar cambios Claude
overview: "Validar cambios locales (UI Polla, leaderboard, combos, PubSub sync) y mezclar siguiendo el workflow del repo: crear feature branch `dev-015-*` desde el estado actual, rebase sobre `development`, correr precommit y crear commit con estilo del proyecto."
todos:
  - id: validate-diff
    content: Revisar diff completo y validar consistencia (leaderboard, combos, UI, PubSub) antes de git operations
    status: completed
  - id: precommit
    content: Correr `mix precommit` y corregir fallos si aparecen
    status: completed
  - id: branch-rebase
    content: Crear `dev-015-*` desde estado actual y rebase sobre `origin/development`
    status: completed
  - id: commit
    content: Stage de archivos relevantes y crear commit `[dev-015] ...`
    status: completed
  - id: pr
    content: Push y crear PR a `development`
    status: completed
isProject: false
---

## Objetivo
- Integrar los cambios locales actuales (5 archivos) en una rama feature y dejarlos listos para PR a `development`, asegurando compilación/tests y evitando commits directos a `main`.

## Estado actual detectado
- Rama actual: `main`.
- Cambios locales sin commit:
  - `lib/bet_place/api/sync_worker.ex`
  - `lib/bet_place_web/live/admin/game_event_show_live.ex`
  - `lib/bet_place/betting.ex`
  - `lib/bet_place_web/live/bettor/game_event_show_live.ex`
  - `lib/bet_place_web/live/bettor/my_tickets_live.ex`
- Ya existe migración + schema para `polla_combination_selections`:
  - `priv/repo/migrations/20260315172009_add_polla_combination_selections.exs`
  - `lib/bet_place/betting/polla_combination_selection.ex`
- El scoring ya usa `preload(:polla_combination_selections)` en `lib/bet_place/betting/settlement.ex`.

## Validaciones antes de mezclar
- Confirmar que los cambios compilan y tests pasan:
  - `mix compile --warnings-as-errors`
  - `mix test`
  - `mix precommit`
- Revisar que no haya regresiones obvias:
  - Leaderboard muestra E/Pt por carrera (una fila por combinación).
  - Drawer "Mis tickets" y `/mis-tickets` muestran combos con detalle por válida usando `polla_combination_selections`.
  - La UI de selección en Polla muestra 6 filas y botones cuadrados consistentes.

## Estrategia de git (la que seleccionaste)
- Crear rama feature desde el estado actual (manteniendo los cambios) y rebasearla sobre `development`:
  - `git switch -c dev-015-polla-resultados-combos`
  - `git fetch origin`
  - `git rebase origin/development`

## Mezcla (commit)
- Staging solo de los 5 archivos modificados.
- Commit con estilo del repo:
  - Título: `[dev-015] Polla: resultados, combos y UI por posiciones`
  - Cuerpo corto explicando el porqué (leaderboard + detalle combos + UI de selección + refresh admin sync).

## PR
- Push de la rama y creación de PR hacia `development`.

```mermaid
flowchart TD
  mainLocal[main con cambios locales] --> featureBranch[dev-015-* creada]
  featureBranch --> rebaseDev[rebase sobre origin/development]
  rebaseDev --> precommit[compilar/format/test]
  precommit --> commit[commit dev-015]
  commit --> pr[PR a development]
```