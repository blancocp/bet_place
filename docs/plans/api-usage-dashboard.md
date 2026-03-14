# Dashboard de Uso de API + Auto-sync configurable

## Analisis: Migracion o no?

**No se necesito migracion.** La tabla `api_sync_logs` ya registra cada request/intento con:

- `synced_at` (fecha/hora UTC)
- `endpoint` (racecards / race / results)
- `status` (ok / error)
- `error_message` (incluye el 429 rate limit)

Se calcula todo con queries GROUP BY sobre esa tabla.

### Pros de usar la tabla existente

- Cero migraciones, cero complejidad adicional
- Los 377 registros historicos ya estaban ahi
- Desglose por endpoint y por status gratis
- Menos codigo que mantener

### Contras

- Si la tabla crece a millones de filas, los queries de agregacion serian lentos
- No aplica en nuestro caso: con la optimizacion, ~13-114 requests/dia = ~3,500/mes maximo

### Alternativa descartada

Crear una tabla `api_usage_daily` con resumen pre-calculado. Seria over-engineering para el volumen actual.

---

## Cambios implementados

### 1. Card de requests del dia en dashboard admin

En [lib/bet_place_web/live/admin/dashboard_live.ex](lib/bet_place_web/live/admin/dashboard_live.ex), card con:

```
Requests hoy: 7    (5 ok / 2 error)
Mes: 377 total
```

### 2. Funciones de consulta

En [lib/bet_place/api/api_sync_log.ex](lib/bet_place/api/api_sync_log.ex), queries para:

- `requests_today/0` y `requests_for_date/1` — requests de hoy (count, desglose ok/error)
- `requests_this_month/0` y `requests_for_month/2` — requests del mes actual
- `daily_history/1` — historico diario (ultimos N dias)
- `daily_history_for_month/2` — desglose diario con breakdown por endpoint

### 3. Vista de historial de requests

Nueva ruta admin `/admin/api-usage` en [lib/bet_place_web/live/admin/api_usage_live.ex](lib/bet_place_web/live/admin/api_usage_live.ex):

- Tabla de requests por dia (fecha, total, ok, errores, desglose por endpoint)
- Resumen del mes actual en cards superiores
- Navegar entre meses

### 4. Auto-sync: intervalo ajustado

En [lib/bet_place/api/sync_worker.ex](lib/bet_place/api/sync_worker.ex):

- `@results_interval` cambiado de 60s a 10 minutos
- El auto-sync de results ya usa el filtro por cursos activos
