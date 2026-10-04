# Flujo n8n: CONEXION API-WHATSAPP (optimizado)

Archivos:

- `CONEXION_API-WHATSAPP.optimizado.json`: flujo listo para importar en n8n.
- `migracion.sql`: cambios en la base de datos. Ejecútalo **antes** de activar el flujo.

## Problemas del flujo original

| # | Problema | Efecto |
|---|----------|--------|
| 1 | 4 consultas por mensaje (upsert lead, insert con subconsulta, `COUNT(*)`, insert del bot) | 4 viajes a la BD por mensaje |
| 2 | `COUNT(*)` sobre `messages` en cada mensaje para saber si el bot ya saludó | Se vuelve más lento a medida que crece la tabla |
| 3 | Condición de carrera: si el cliente manda 2 mensajes seguidos, ambos ven `COUNT = 0` | Saludo duplicado |
| 4 | No se guarda el `wamid` de WhatsApp | Meta reintenta webhooks y los mensajes se guardan duplicados |
| 5 | Solo lee `entry[0].changes[0].messages[0]` | Si Meta agrupa varios mensajes en un webhook, se pierden |
| 6 | Solo procesa `type = text` | Audios, imágenes, botones y respuestas de listas no se guardan |
| 7 | `time = NOW()` | Se guarda la hora de procesamiento, no la del mensaje |
| 8 | `name = EXCLUDED.name` siempre | Si llega sin nombre, se borra el que ya estaba |
| 9 | Cada webhook de estado (sent/delivered/read) crea una ejecución guardada en n8n | La BD de n8n en el VPS crece sin control; normalmente es lo que más espacio ocupa |
| 10 | El nodo de verificación (GET) estaba desconectado | No se puede volver a verificar el webhook en Meta |

## Qué cambia

1. **Nodo Code "Normalizar mensajes"**: recorre todos los mensajes del payload y saca 1 item por mensaje con `wa_message_id`, `phone`, `nombre_cliente`, `tipo`, `mensaje_cliente` y `ts`. Los webhooks de estado devuelven 0 items, así que la ejecución termina sin tocar la BD.
2. **1 sola consulta "Guardar lead y mensaje"** (CTE): hace el upsert del lead, inserta el mensaje con `ON CONFLICT (wa_message_id) DO NOTHING` y reclama el saludo de forma atómica con `leads.welcome_sent_at`. Devuelve `enviar_bienvenida` (true/false).
3. **Sin `COUNT(*)`**: la marca `welcome_sent_at` en `leads` lo reemplaza. Como Postgres bloquea la fila del lead durante el upsert, dos mensajes simultáneos no pueden reclamar el saludo los dos.
4. **Respuesta del bot**: se guarda con el `lead_id` que ya devolvió la consulta anterior (sin subconsulta) y con el `wamid` que devuelve la API de WhatsApp. El envío reintenta 3 veces si falla.
5. **`last_message` solo se actualiza si el mensaje es más reciente**, y el nombre solo se sobrescribe si llega con valor.
6. **Verificación GET** reconectada y validando `hub.verify_token`.
7. **Ajustes del flujo**: `saveDataSuccessExecution: none` (las ejecuciones exitosas no se guardan; las fallidas sí, para depurar).

Antes: 4 consultas por mensaje de texto. Ahora: 1 consulta por mensaje del cliente, más 1 solo cuando se envía el saludo.

## Bot de terrenos

El bot avanza por etapas guardadas en `leads.bot_stage` y solo habla de terrenos:

| Etapa actual | Cliente escribe | Bot responde | Nueva etapa |
|---|---|---|---|
| (nuevo) | cualquier cosa | Bienvenida + "responde 1 o escribe *terrenos*" | `bienvenida` |
| (nuevo) | ya pide info ("quiero info de terrenos") | Saludo + info + "un asesor se comunicará" | `asesor` |
| `bienvenida` | 1 / terrenos / precio / sí... | Info + "un asesor se comunicará" | `asesor` |
| `bienvenida` | otro tema | "Solo podemos ayudarte con terrenos..." | `aclaracion` |
| `aclaracion` | cualquier cosa | (Info si la pide) + "un asesor se comunicará" | `asesor` |
| `asesor` | cualquier cosa | **Nada**: responde una persona | `asesor` |

- Los textos y las palabras clave se editan arriba del nodo **"Decidir respuesta"**. Completa `INFO_TERRENOS` con la información real; si queda vacío, solo se avisa que un asesor se comunicará.
- Para que el bot vuelva a atender a un cliente: `UPDATE public.leads SET bot_stage = NULL WHERE phone = '593...';`
- Para ver quién espera un asesor: `SELECT phone, name, last_message, last_message_time FROM public.leads WHERE bot_stage = 'asesor' ORDER BY last_message_time DESC;`

## Pasos para aplicarlo

1. Haz un respaldo: `pg_dump -t leads -t messages tu_bd > respaldo.sql`.
2. Ejecuta `migracion.sql` (es idempotente; marca como saludados a los leads que ya tienen un mensaje del bot).
3. En n8n, **desactiva** el flujo actual.
4. Importa `CONEXION_API-WHATSAPP.optimizado.json`. Revisa que las credenciales `Conexion base sup-vps` y `WhatsApp account` queden asignadas.
5. En el nodo **"Token valido?"**, cambia `CAMBIA_ESTE_TOKEN` por el Verify Token que configuraste en Meta.
6. Activa el flujo nuevo. Usa la misma ruta `whatsapp-webhook`, así que la URL configurada en Meta no cambia.

> Importante: en el nodo "Guardar lead y mensaje", **Query Batching** debe quedar en `Independently`. Cada mensaje tiene que ir en su propia transacción para que la lógica del saludo sea correcta.

## Recomendaciones para el VPS

Limpieza automática del historial de ejecuciones de n8n (variables de entorno del contenedor):

```env
EXECUTIONS_DATA_PRUNE=true
EXECUTIONS_DATA_MAX_AGE=168          # horas (7 días)
EXECUTIONS_DATA_PRUNE_MAX_COUNT=10000
```

Si n8n usa SQLite, agrega también `DB_SQLITE_VACUUM_ON_STARTUP=true` para recuperar espacio.

Para la conversación, al final de `migracion.sql` hay un `DELETE` opcional de retención (mensajes de más de 12 meses).

## Siguientes mejoras posibles

- **Validar la firma de Meta** (`X-Hub-Signature-256`) con el App Secret, para que nadie más pueda enviar datos falsos a tu webhook. Requiere activar *Raw Body* en el Webhook y permitir `crypto` en el nodo Code (`NODE_FUNCTION_ALLOW_BUILTIN=crypto`).
- La columna `messages.phone` es redundante con `lead_id`. Se mantiene por compatibilidad con tus paneles; se podría eliminar más adelante.
