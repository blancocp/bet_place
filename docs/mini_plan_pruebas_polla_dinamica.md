# Mini plan de pruebas: Polla dinamica

## Objetivo
Validar que el valor de ticket por evento y la mecanica de Polla dinamica funcionen correctamente de punta a punta.

## Preparacion
- Ejecutar migraciones: `mix ecto.migrate`
- Levantar app: `mix phx.server`
- Tener un admin y un bettor habilitados.

## Prueba 1: Creacion de evento
- Crear un evento de tipo Polla.
- Cargar `Valor del ticket` distinto a 100 (ejemplo: 150).
- Activar checkbox `Polla dinamica`.
- Definir ventana dinamica en 1, 2 o 3 minutos.
- Verificar que el evento se crea sin errores y muestra indicador de dinamica.

## Prueba 2: Apuesta inicial
- Entrar como bettor y abrir el evento.
- Seleccionar ejemplares en las 6 validas.
- Confirmar apuesta.
- Verificar:
  - El total pagado usa el `ticket_value` del evento.
  - Se descuenta saldo correctamente.
  - El ticket queda en estado activo.

## Prueba 3: Activacion de ventana dinamica
- Confirmar/scorear la 4ta valida del evento.
- Verificar que se habilita la ventana dinamica.
- Confirmar visualmente que aparece opcion para editar 5ta y 6ta.

## Prueba 4: Edicion 5ta/6ta dentro de ventana
- Abrir `Mis tickets`.
- Usar `Editar 5ta/6ta` en un ticket activo.
- Cambiar seleccion de 5ta y/o 6ta valida y guardar.
- Verificar:
  - Se actualizan combinaciones del ticket.
  - No se alteran selecciones de 1ra a 4ta.

## Prueba 5: Cierre de ventana
- Esperar vencimiento de `dynamic_closes_at`.
- Intentar editar nuevamente.
- Verificar que:
  - Ya no se permite guardar cambios.
  - Se muestra mensaje de ventana cerrada.

## Criterio de aceptacion
- El valor por ticket es configurable por evento.
- La Polla dinamica solo permite editar 5ta y 6ta.
- La edicion solo ocurre dentro de la ventana (maximo 3 minutos).
