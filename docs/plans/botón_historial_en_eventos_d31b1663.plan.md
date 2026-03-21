---
name: Botón Historial en /eventos
overview: Agregar un botón en la cabecera de `/eventos` que navegue a `/historial` (Bettor.BettingHistoryLive).
todos:
  - id: add-history-button
    content: Agregar botón/link a /historial en Bettor.GameEventListLive render
    status: completed
isProject: false
---

## Objetivo

- En la vista de eventos (`/eventos`) mostrar un botón visible para ir al historial (`/historial`).

## Cambio

- Editar `[lib/bet_place_web/live/bettor/game_event_list_live.ex](lib/bet_place_web/live/bettor/game_event_list_live.ex)` en `render/1`:
  - Reemplazar el header actual (solo título) por un contenedor `flex` con:
    - Título `Eventos disponibles`
    - Botón/link `Historial` usando `<.link navigate={~p"/historial"}>` y estilo `btn btn-ghost btn-sm` (o `btn-outline` si prefieres más prominente).

## Validación

- `mix compile --warnings-as-errors`
- Smoke test: entrar a `/eventos` y verificar que el botón lleva a `/historial`.

