-- Migración: varias agencias, cada una con su propio número de WhatsApp.
-- Requiere haber ejecutado antes migracion.sql.
-- Ejecutar todo junto (el editor SQL de Supabase lo hace en una transacción)
-- y justo después importar los flujos nuevos: el flujo anterior deja de
-- funcionar porque usa ON CONFLICT (phone).

-- 1) Líneas / agencias. Los textos vacíos usan los textos por defecto del bot.
--    {nombre} y {agencia} se reemplazan en bienvenida.
CREATE TABLE IF NOT EXISTS public.whatsapp_lineas (
  phone_number_id text PRIMARY KEY,           -- id del número en Meta (no el teléfono)
  agencia         text NOT NULL,
  telefono        text,                       -- solo informativo, ej. 593989574272
  bienvenida      text,
  info_terrenos   text,
  bot_activo      boolean NOT NULL DEFAULT true,
  created_at      timestamptz NOT NULL DEFAULT NOW()
);

-- Número actual. Cambia el nombre de la agencia si quieres.
INSERT INTO public.whatsapp_lineas (phone_number_id, agencia)
VALUES ('1259319843939123', 'Agencia principal')
ON CONFLICT (phone_number_id) DO NOTHING;

-- 2) Cada lead y cada mensaje saben por qué línea llegaron.
ALTER TABLE public.leads    ADD COLUMN IF NOT EXISTS phone_number_id text;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS phone_number_id text;

UPDATE public.leads    SET phone_number_id = '1259319843939123' WHERE phone_number_id IS NULL;
UPDATE public.messages SET phone_number_id = '1259319843939123' WHERE phone_number_id IS NULL;

ALTER TABLE public.leads ALTER COLUMN phone_number_id SET NOT NULL;

-- 3) Un lead por (cliente, agencia) en lugar de uno por cliente.
--    Quita la restricción/índice único que había solo sobre phone.
DO $$
DECLARE
  r record;
  phone_att smallint;
BEGIN
  SELECT attnum INTO phone_att FROM pg_attribute
  WHERE attrelid = 'public.leads'::regclass AND attname = 'phone';

  FOR r IN SELECT conname FROM pg_constraint
           WHERE conrelid = 'public.leads'::regclass AND contype = 'u'
             AND conkey = ARRAY[phone_att] LOOP
    EXECUTE format('ALTER TABLE public.leads DROP CONSTRAINT %I', r.conname);
  END LOOP;

  FOR r IN SELECT c.relname FROM pg_index i JOIN pg_class c ON c.oid = i.indexrelid
           WHERE i.indrelid = 'public.leads'::regclass AND i.indisunique
             AND NOT i.indisprimary AND i.indkey::text = phone_att::text LOOP
    EXECUTE format('DROP INDEX public.%I', r.relname);
  END LOOP;
END $$;

CREATE UNIQUE INDEX IF NOT EXISTS leads_phone_linea_key
  ON public.leads (phone, phone_number_id);

-- 4) Para que cada agencia liste rápido sus leads en el CRM.
CREATE INDEX IF NOT EXISTS leads_linea_last_message_idx
  ON public.leads (phone_number_id, last_message_time DESC);

-- Agregar las otras agencias (phone_number_id está en Meta → WhatsApp →
-- Configuración de la API, o en WhatsApp Manager → Números de teléfono):
--
-- INSERT INTO public.whatsapp_lineas (phone_number_id, agencia, telefono, info_terrenos) VALUES
--   ('PHONE_NUMBER_ID_2', 'Agencia Norte', '5939...', E'🏡 *Terrenos en ...*\n• Medidas: ...\n• Precio desde: ...'),
--   ('PHONE_NUMBER_ID_3', 'Agencia Sur',   '5939...', '...');
