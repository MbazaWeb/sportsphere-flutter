-- Auth tables for VPS-native auth system
CREATE TABLE IF NOT EXISTS public.refresh_tokens (
  id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id    text NOT NULL REFERENCES public."User"(id) ON DELETE CASCADE,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  created_at timestamptz NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS refresh_tokens_user_idx ON public.refresh_tokens(user_id);
CREATE INDEX IF NOT EXISTS refresh_tokens_expires_idx ON public.refresh_tokens(expires_at);

CREATE TABLE IF NOT EXISTS public.password_resets (
  id         text PRIMARY KEY DEFAULT gen_random_uuid()::text,
  user_id    text NOT NULL,
  token_hash text NOT NULL UNIQUE,
  expires_at timestamptz NOT NULL,
  used_at    timestamptz,
  created_at timestamptz NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS password_resets_user_idx ON public.password_resets(user_id);

-- Add passwordHash column to User if missing
ALTER TABLE public."User" ADD COLUMN IF NOT EXISTS "passwordHash" text;

-- Clean up expired tokens automatically (run periodically)
-- CREATE OR REPLACE FUNCTION clean_expired_tokens() RETURNS void AS $$
-- BEGIN
--   DELETE FROM public.refresh_tokens WHERE expires_at < NOW();
--   DELETE FROM public.password_resets WHERE expires_at < NOW();
-- END; $$ LANGUAGE plpgsql;
