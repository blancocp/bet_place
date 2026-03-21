---
name: API Usage Dashboard
overview: Agregar card de requests del dia en dashboard admin, vista de historial con resumen diario/mensual, y ajustar intervalo del auto-sync. Sin migracion necesaria.
todos:
  - id: api-queries
    content: Agregar funciones de consulta de uso de API en contexto (requests hoy, mes, historico diario)
    status: completed
  - id: dashboard-card
    content: Agregar card de requests del dia en el dashboard admin
    status: completed
  - id: usage-view
    content: Crear vista admin /admin/api-usage con historial diario y resumen mensual
    status: completed
  - id: usage-route
    content: Agregar ruta y link de navegacion para la vista de uso de API
    status: completed
  - id: autosync-interval
    content: Cambiar intervalo de auto-sync results de 60s a 10 minutos
    status: completed
  - id: precommit-final
    content: Ejecutar mix precommit y commit final
    status: completed
isProject: false
---

# Dashboard de Uso de API + Auto-sync configurable

## Analisis: Migracion o no?

**No se necesita migracion.** La tabla `api_sync_logs` ya registra cada request/intento con:

- `synced_at` (fecha/hora UTC)
- `endpoint` (racecards / race / results)
- `status` (ok / error)
- `error_message` (incluye el 429 rate limit)

Se puede calcular todo con queries GROUP BY sobre esa tabla.

### Pros de usar la tabla existente

- Cero migraciones, cero complejidad adicional
- Los 377 registros historicos ya estan ahi
- Desglose por endpoint y por status gratis
- Menos codigo que mantener

### Contras

- Si la tabla crece a millones de filas, los queries de agregacion serian lentos
- No aplica en nuestro caso: con la optimizacion, ~13-114 requests/dia = ~3,500/mes maximo

### Alternativa descartada

Crear una tabla `api_usage_daily` con resumen pre-calculado. Seria over-engineering para el volumen actual.

---

## Cambios a implementar

### 1. Card de requests del dia en dashboard admin

En [lib/bet_place_web/live/admin/dashboard_live.ex](lib/bet_place_web/live/admin/dashboard_live.ex), agregar un card dentro del grid de stats existente:

```
Requests hoy: 7    (5 ok / 2 error)
Mes: 377 total
```

### 2. Funciones de consulta

En un modulo nuevo o en el existente, queries para:

- Requests de hoy (count, desglose ok/error)
- Requests del mes actual
- Historico diario (ultimos 30 dias)

### 3. Vista de historial de requests

Nueva ruta admin `/admin/api-usage` con:

- Tabla de requests por dia (fecha, total, ok, errores, desglose por endpoint)
- Resumen del mes actual en un card superior
- Navegar entre meses

### 4. Auto-sync: intervalo configurable

En [lib/bet_place/api/sync_worker.ex](lib/bet_place/api/sync_worker.ex):

- Cambiar `@results_interval` de 60s a 10 minutos (600s)
- El auto-sync de results ya usa el filtro por cursos activos (implementado en dev-012)

---

## Sobre SSH/Cursor

Si, reinicia Cursor completamente (cerrar ventana + reabrir). El ControlMaster de SSH necesita que la primera conexion se haga despues de que el config este cargado. Si Cursor ya tenia una sesion abierta, no toma los cambios del config.