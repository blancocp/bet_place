# Guia QA: Seeders Curados + Simulacion de API

Esta guia permite validar rapidamente el flujo de datos curados, simulacion de resultados y liquidacion de juegos (incluyendo VS) sin depender de la API externa.

## 1) Credenciales de prueba

- Clave comun para los 3 usuarios: `12345678`

### Admin
- Email: `admin@betplace.local`
- Username: `admin`
- Cedula actual en DB: `990620030`
- Saldo inicial esperado: `1000.00`

### Bettor 1
- Email: `bettor1@betplace.local`
- Username: `juan.perez`
- Cedula: `24567890`
- Saldo inicial esperado: `1000.00`

### Bettor 2
- Email: `bettor2@betplace.local`
- Username: `maria.gomez`
- Cedula: `27890123`
- Saldo inicial esperado: `1000.00`

## 2) Comandos operativos

Ejecutar desde la raiz del proyecto:

```bash
scripts/reset_and_seed.sh
mix phx.server
```

Para aplicar resultados del dia por script:

```bash
scripts/seed_results_today.sh
```

Alternativa manual desde UI admin:
- Boton: `Simular resultados (seed)` en el dashboard admin.

## 3) Flujo de validacion recomendado

1. Ejecutar `scripts/reset_and_seed.sh`.
2. Verificar que existen:
   - 3 usuarios semilla con perfil completo.
   - Metodos de pago de usuario y del sistema.
   - Carreras del dia sin posiciones finales.
3. Iniciar app con `mix phx.server`.
4. Iniciar sesion como bettors y registrar apuestas (incluyendo VS Macho/Hembra).
5. Aplicar resultados:
   - por script `scripts/seed_results_today.sh`, o
   - por boton admin `Simular resultados (seed)`.
6. Verificar liquidacion y efectos en UI:
   - Saldos actualizados.
   - Historial/tickets actualizados.
   - Estado de apuestas VS actualizado.

## 4) Checklist funcional VS

- [ ] Seleccion de bloque Macho/Hembra visible y operativa.
- [ ] Modal de confirmacion de apuesta VS antes de debitar saldo.
- [ ] Debito de saldo al confirmar la apuesta.
- [ ] Caso valido: gana el bloque con mejor llegada entre sus representantes.
- [ ] Caso refund: ambos bloques quedan 6to+ (sin top 5) -> reintegro total.
- [ ] Caso void/refund: 1 vs 1 y uno retirado -> juego sin efecto y reintegro.
- [ ] Caso retiro parcial en bloques multiples -> continua con ejemplares restantes.
- [ ] Payout configurable por carrera aplicado correctamente al confirmar.

## 5) Resultado esperado final

- El flujo completo (seed base -> apuestas -> seed resultados -> settlement) debe ser repetible.
- No debe requerir API externa para validar escenarios de negocio.
- Las vistas deben reflejar los cambios de saldo y estado de jugadas correctamente.

