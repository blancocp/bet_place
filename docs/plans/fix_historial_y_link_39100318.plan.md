---
name: Fix historial y link
overview: Corregir el crash de `/historial` (BettingHistoryLive) causado por acceso a `combo.points`, y confirmar el acceso al botón Historial desde `/eventos`.
todos:
  - id: fix-betting-history-points
    content: Actualizar BettingHistoryLive para usar combo.total_points en lugar de combo.points
    status: completed
  - id: verify-historial
    content: Compilar/tests y verificar navegación /eventos -> /historial
    status: completed
isProject: false
---

## Objetivo
- Hacer que `/historial` funcione sin errores.
- Asegurar que el botón “Historial” exista y apunte a `/historial` desde `/eventos`.

## Diagnóstico
- La ruta existe: `/historial` → `Bettor.BettingHistoryLive`.
- El crash mostrado (`KeyError key :points not found`) viene de [`lib/bet_place_web/live/bettor/betting_history_live.ex`](lib/bet_place_web/live/bettor/betting_history_live.ex) al intentar acceder a `combo.points`.
- En el modelo actual, `PollaCombination` usa `total_points` (y `is_winner`, `prize_amount`).

## Cambios
- En [`lib/bet_place_web/live/bettor/betting_history_live.ex`](lib/bet_place_web/live/bettor/betting_history_live.ex):
  - Reemplazar `combo.points` por `combo.total_points` en el render.
  - Ajustar las condiciones `:if={combo.points}` a `:if={not is_nil(combo.total_points)}`.
  - Mantener el resto de la UI igual (arreglo mínimo).

## Validación
- `mix compile --warnings-as-errors`
- `mix test`
- Smoke test manual:
  - Entrar a `/eventos` y usar el botón **Historial**.
  - Confirmar que `/historial` renderiza sin error.
