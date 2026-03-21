---
name: API Request Optimization
overview: Analisis del consumo de API, el comportamiento actual del sync, y plan de optimizacion para mantenerse dentro del plan BASIC de RapidAPI.
todos:
  - id: filter-sync
    content: Filtrar sync_results para solo descargar detalle de carreras de cursos con game_events activos
    status: completed
  - id: date-picker
    content: Agregar selector de fecha en el admin para sincronizar dias especificos
    status: completed
  - id: rate-limit
    content: Agregar delay interno entre requests de race detail para evitar 429s
    status: completed
  - id: selective-sync
    content: "(Opcional) Sync selectivo: solo descargar detalle de carreras que estan en game_event_races"
    status: pending
isProject: false
---

# Analisis y Optimizacion del Consumo de API

## Situacion actual

### Consumo historico (todo fue el 12 de marzo)

- **377 requests registrados** en `api_sync_logs`
- 304 exitosos, **73 errores 429** (rate limit por minuto)
- Los 429 **tambien cuentan como requests** en RapidAPI, asi que el consumo real fue ~377+
- Desglose: 359 race detail + 15 results + 3 racecards

### El problema central: los endpoints son GLOBALES

El endpoint `/racecards?date=2026-03-13` devuelve las carreras de **TODOS los hipodromos** del dia, no solo Aqueduct:

- Aqueduct: 8 carreras
- Charles Town: 8
- Colonial Downs: 8
- Fair Grounds: 9
- Gulfstream: 10
- Laurel Park: 8
- Mahoning Valley: 8
- Oaklawn Park: 10
- Santa Anita: 9
- Tampa Bay Downs: 9
- Turfway Park: 10
- **Total: 97 carreras**

Pero tu Polla 13 de Marzo **solo usa 6 carreras de Aqueduct**. El sync actual descarga detalles de las 97, desperdiciando ~93% de la cuota.

### Datos en la base de datos

- **12 marzo**: 84 carreras, resultados sincronizados, Polla 12 = Finalizado
- **13 marzo**: 97 carreras con metadata (de racecards), **0 resultados sincronizados**, todas en `status=scheduled`
- **14 marzo (hoy)**: 0 carreras sincronizadas

### Estado del plan RapidAPI BASIC

- Ya consumiste el 100% de la cuota (notificacion del proveedor)
- Los requests pueden ser **bloqueados** o generar **cobros extra**
- El rate limit por minuto tambien es un problema (10 req/min aprox)

---

## Que pasa si haces "Sync Resultados" HOY

El boton usa `Date.utc_today()`, o sea **2026-03-14** (hoy sabado). Esto significa:

1. **1 request** a `GET /results?date=2026-03-14`
2. Devuelve carreras de HOY (sabado = dia grande de carreras en USA, potencialmente 100+ carreras)
3. Por cada carrera finished: **1 request** a `GET /race/:id`
4. **Estimacion: 1 + 80-120 requests** si hay carreras terminadas hoy

**Pero esto NO te sirve** para la Polla 13 de Marzo, porque esas carreras fueron ayer. Necesitarias `sync_results("2026-03-13")`, que el boton actual no permite.

### Para sincronizar resultados del 13 de marzo

- 1 request a `/results?date=2026-03-13` (todas las carreras del 13)
- Filtra las finished -> probablemente las 97
- 97 requests a `/race/:id` -> trae detalles de CADA una
- **Total: 98 requests** (pero solo necesitas 6-8 de Aqueduct)

---

## Plan de optimizacion propuesto

### Cambio 1: Filtrar race detail por curso relevante (ahorro: ~90%)

En `sync_results/1`, despues de obtener la lista de carreras finished, filtrar para solo descargar detalle de las carreras que pertenecen a un hipódromo con game_events activos:

```
Antes:  97 race detail requests (todos los hipodromos)
Despues: 8 race detail requests (solo Aqueduct)
Total:   9 requests en vez de 98
```

Logica: consultar `game_events` con status `open` o `closed`, obtener sus `course_id`, y solo llamar `/race/:id` para carreras de esos cursos.

### Cambio 2: Sync por fecha especifica desde el admin

El boton actualmente solo sincroniza `Date.utc_today()`. Agregar opcion de seleccionar fecha para poder sincronizar dias anteriores (como el 13 de marzo).

### Cambio 3: Rate limiting interno (evitar 429s)

Agregar un delay de ~~7 segundos entre requests de race detail para no exceder el rate limit por minuto del plan BASIC (~~10/min). Esto evita los 73 errores 429 que desperdician cuota.

### Cambio 4 (opcional): Sync selectivo por race_id

El mas granular: solo hacer `/race/:id` para las carreras que estan en `game_event_races`. Para la Polla 13, eso seria exactamente 6 requests + 1 del results = **7 requests totales**.

---

## Recomendacion inmediata (sin tocar codigo)

Si quieres ver los resultados del 13 de marzo AHORA con minimo consumo, puedo ejecutar un script que:

1. Haga 1 request a `/results?date=2026-03-13`
2. Filtre solo los `id_race` de Aqueduct que estan en tu evento (144592-144597)
3. Haga 6 requests de detalle (solo esos 6)
4. **Total: 7 requests** en vez de 98

Pero si la API ya te bloqueo, ni siquiera esos 7 pasarian.

---

## Resumen de costos por operacion

- Sync Racecards hoy: **1 + ~100 requests** (todas las carreras de todos los hipodromos)
- Sync Resultados hoy (sin filtro): **1 + ~100 requests**
- Sync Resultados con filtro de curso: **1 + ~8-10 requests**
- Sync Resultados con filtro de game_event: **1 + 6 requests**

