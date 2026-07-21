-- ==========================================================
-- 00_shared_functions.sql
-- Run order: 1 of 6
-- Requires: nothing
-- ==========================================================
-- Shared updated_at trigger function, reused by every table.
-- ==========================================================

CREATE OR REPLACE FUNCTION public.set_updated_at()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$;