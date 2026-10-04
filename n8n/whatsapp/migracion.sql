-- Migración para el flujo "CONEXION API-WHATSAPP" optimizado.
-- Es aditiva e idempotente: se puede ejecutar varias veces sin romper nada.
-- Ejecutar ANTES de importar el nuevo flujo en n8n.

BEGIN;

-- 1) Marca de bienvenida en el lead: reemplaza el COUNT(*) sobre messages
--    que se hacía en cada mensaje entrante.
ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS welcome_sent_at timestamptz;

-- 2) Id del mensaje de WhatsApp (wamid) y tipo, para deduplicar los
--    reintentos de Meta y no perder mensajes que no son de texto.
ALTER TABLE public.messages
  ADD COLUMN IF NOT EXISTS wa_message_id text,
  ADD COLUMN IF NOT EXISTS msg_type      text NOT NULL DEFAULT 'text';

-- 3) Índices
--    Único por wamid (los NULL históricos no chocan entre sí).
CREATE UNIQUE INDEX IF NOT EXISTS messages_wa_message_id_key
  ON public.messages (wa_message_id);

--    Para leer el historial de una conversación (panel, CRM, IA, etc.).
CREATE INDEX IF NOT EXISTS messages_lead_id_time_idx
  ON public.messages (lead_id, time DESC);

-- 4) Backfill: los leads que ya recibieron el saludo del bot no deben
--    recibirlo de nuevo con el flujo nuevo.
UPDATE public.leads l
SET    welcome_sent_at = b.primera
FROM  (SELECT phone, MIN(time::timestamptz) AS primera
       FROM   public.messages
       WHERE  sender = 'bot'
       GROUP  BY phone) b
WHERE  l.phone = b.phone
  AND  l.welcome_sent_at IS NULL;

-- 5) Bot de terrenos: etapa de la conversación por lead.
--    NULL = nuevo | bienvenida | aclaracion | asesor (el bot ya no responde)
ALTER TABLE public.leads
  ADD COLUMN IF NOT EXISTS bot_stage text;

--    Las conversaciones que ya existían quedan con el asesor para que el
--    bot no interrumpa. Para reactivar el bot en un lead:
--      UPDATE public.leads SET bot_stage = NULL WHERE phone = '593...';
UPDATE public.leads l
SET    bot_stage = 'asesor'
WHERE  l.bot_stage IS NULL
  AND  EXISTS (SELECT 1 FROM public.messages m WHERE m.phone = l.phone);

COMMIT;

-- Opcional: si el índice antiguo (phone, sender) existía solo para el
-- COUNT(*) del flujo anterior, ya no hace falta. Revísalo con:
--   SELECT indexname, indexdef FROM pg_indexes WHERE tablename = 'messages';

-- Opcional (retención): borrar conversaciones de más de 12 meses.
--   DELETE FROM public.messages WHERE time < NOW() - INTERVAL '12 months';
