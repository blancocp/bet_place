---
name: Vistas resultados Polla
overview: "Tres cambios de producto: (1) vista publica de resultados del evento con combinaciones y puntos de todos los usuarios; (2) vista \"mis combinaciones\" por ticket con detalle por carrera y resultado; (3) en Polla mostrar posiciones/numeros en lugar de nombre de caballo y jinete."
todos:
  - id: polla-positions-ui
    content: "Polla: mostrar solo program_number en seleccion y en Mis tickets (sin nombre caballo/jinete)"
    status: completed
  - id: my-combos-detail
    content: "Mis combinaciones: tarjetas por combo con cadena numeros, puntos, detalle por valida (1V..6V, resultado 1º/2º/3º/X)"
    status: completed
  - id: leaderboard-query
    content: "Betting: list_leaderboard_rows(event_id) con usuario, combo, E/Pt por carrera, total"
    status: completed
  - id: leaderboard-view
    content: "Evento finalizado: seccion Resultados con tabla leaderboard en GameEventShowLive"
    status: completed
isProject: false
---

# Vistas de resultados y combinaciones para la Polla

Referencia: captures del usuario (igaloenlinea / AGN App). No copiar estilo; implementar nuestra propia version del contenido.

---

## 1. Vista publica de resultados del evento (leaderboard)

**Objetivo:** Cualquier bettor puede ver la data del evento una vez finalizado: combinaciones y puntos de todos los usuarios.

**Contenido a mostrar:**

- Resumen: premio total (o bote), valor base del ticket, cantidad de tickets/combinaciones selladas.
- Tabla: una fila por **combinacion** (no por ticket; un usuario con 4 combos tiene 4 filas).
  - Columnas: Usuario | C1 (E, Pt) | C2 (E, Pt) | ... | CN (E, Pt) | Total.
  - **E** = numero del caballo elegido (program_number del runner seleccionado).
  - **Pt** = puntos de esa carrera para esa combinacion (1ro=5, 2do=3, 3ro=1, resto=0).
  - **Total** = suma de puntos de la combinacion.

**Implementacion:**

- **Ruta:** Reutilizar `/eventos/:id` (Bettor.GameEventShowLive). Cuando `event.status == :finished`, mostrar una seccion/tab "Resultados" (o vista principal si el evento esta finalizado) con la tabla anterior. Alternativa: ruta dedicada `/eventos/:id/resultados` si se prefiere URL explicita.
- **Contexto:** Nueva funcion en [lib/bet_place/betting.ex](lib/bet_place/betting.ex), por ejemplo `list_leaderboard_rows(game_event_id)` que devuelva una lista de mapas con `username`, `combination_index`, por cada carrera `race_N_selection` (program_number) y `race_N_points`, y `total_points`. Orden: `total_points` descendente.
  - Consulta: tickets del evento con preload `:user`, `polla_combinations: :polla_combination_selections`, y `polla_selections` (para tener `points_earned` por game_event_race_id + runner_id). Por cada combinacion, construir la fila uniendo combo_selections (program_number) con puntos del ticket (polla_selections por race/runner).
- **LiveView:** En [lib/bet_place_web/live/bettor/game_event_show_live.ex](lib/bet_place_web/live/bettor/game_event_show_live.ex), si evento finalizado, asignar `leaderboard_rows` y renderizar tabla (responsive: cabecera fija, columnas C1..CN con subcolumnas E/Pt). No mostrar formulario de apuestas cuando status es :finished.

---

## 2. Mis combinaciones como bettor

**Objetivo:** Ver "mis" combinaciones con detalle por carrera y resultado (posicion o X).

**Contenido a mostrar (por combinacion):**

- Tarjeta: usuario (o "Mis combinaciones" en contexto de un solo usuario), cadena de combinacion (ej. `3-8-7-7-4-4`), puntos totales, premio si aplica, estado.
- Expandible "Detalle por valida": por cada carrera (1V..6V), mostrar numero elegido y resultado: 1º / 2º / 3º / X (si no sumo puntos). In our data: `points_earned` 5 -> 1º, 3 -> 2º, 1 -> 3º, 0 -> X.

**Implementacion:**

- **Donde:** (a) Drawer "Mis tickets" dentro de `/eventos/:id` y (b) pagina `/mis-tickets` (MyTicketsLive).
- **Datos:** Para cada ticket, precargar `polla_combinations` con `polla_combination_selections` (y `runner` para program_number). Para puntos por (carrera, runner): usar `polla_selections` del mismo ticket (ya tenemos game_event_race_id, runner_id, points_earned). Construir en el LiveView o en un helper un mapa `%{ {ger_id, runner_id} => points_earned }` para buscar puntos por combo_selection.
- **UI:** Por ticket, listar combinaciones como tarjetas; cada tarjeta muestra cadena de numeros (ej. 3-8-7-7-4-4), total puntos, premio; boton o chevron para expandir y mostrar tabla/fila "Detalle por valida" (1V: num, resultado; 2V: ...). Orden de combinaciones por combination_index o por total_points desc.
- **Preload:** Ajustar `list_polla_tickets_for_user_and_event` y `list_polla_tickets_for_user` para incluir `polla_combinations: [polla_combination_selections: [:game_event_race, runner: []]]` y asegurar `polla_selections` con `game_event_race_id` y `runner_id` para el lookup de puntos.

---

## 3. Polla: mostrar posiciones (numeros) en lugar de nombre de caballo/jinete

**Objetivo:** En el juego de la polla, interfaz mas versatil mostrando todas las posiciones (numeros) en la misma vista, sin nombres de caballo ni jinete.

**Cambios:**

- **Seleccion de runners (evento abierto):** En [lib/bet_place_web/live/bettor/game_event_show_live.ex](lib/bet_place_web/live/bettor/game_event_show_live.ex), en la lista de runners de la Polla (aprox. lineas 398-412), dejar de mostrar `runner.horse.name` y `runner.jockey.name`. Mostrar solo el numero (program_number) en el circulo y el checkbox; opcionalmente mantener un grid de numeros compacto (1, 2, 3, ...) para elegir por posicion. Misma funcionalidad de toggle_runner; solo cambia el contenido visual.
- **Mis tickets (drawer y lista):** Donde hoy se muestra "C1: NombreCaballo" (ej. linea 708), mostrar "C1: 3" (program_number). En el detalle expandido de combinaciones (punto 2), ya se mostrara numero + resultado (1º/2º/3º/X); no mostrar nombre de caballo/jinete.
- **Pagina Mis apuestas:** En [lib/bet_place_web/live/bettor/my_tickets_live.ex](lib/bet_place_web/live/bettor/my_tickets_live.ex), si se muestra detalle de combinaciones por ticket, usar numeros (y cadena tipo 3-8-7-7-4-4) en lugar de nombres.

Nota: Para Horse vs Horse no se aplica este cambio; ahi se mantienen nombres de caballos (y jinetes si se muestran).

---

## Orden sugerido

1. Cambio 3 (posiciones en lugar de nombres) — rapido y desacoplado.
2. Cambio 2 (mis combinaciones con detalle por valida) — usa polla_combination_selections y polla_selections.
3. Cambio 1 (leaderboard publico) — nueva consulta y seccion cuando evento finalizado.

---

## Archivos a tocar

- [lib/bet_place/betting.ex](lib/bet_place/betting.ex): `list_leaderboard_rows/1`; preloads en `list_polla_tickets_for_user` y `list_polla_tickets_for_user_and_event` para combo_selections + runner.
- [lib/bet_place_web/live/bettor/game_event_show_live.ex](lib/bet_place_web/live/bettor/game_event_show_live.ex): condicional por status :finished para mostrar resultados; tabla leaderboard; drawer "Mis tickets" con tarjetas de combinaciones y detalle por valida; lista de runners en Polla solo con program_number.
- [lib/bet_place_web/live/bettor/my_tickets_live.ex](lib/bet_place_web/live/bettor/my_tickets_live.ex): listar combinaciones por ticket con cadena de numeros y detalle expandible (opcional enlace a evento para ver leaderboard completo).

