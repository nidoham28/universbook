-- ==========================================================
-- 04_consumers.sql
-- Run order: 5 of 6
-- Requires: 00_shared_functions.sql, 01_users.sql
-- ==========================================================

CREATE TABLE IF NOT EXISTS public.consumers (
    id UUID PRIMARY KEY
        REFERENCES public.users(id)
        ON DELETE CASCADE,

    preferred_lang TEXT NOT NULL DEFAULT 'bn'
        CHECK (preferred_lang IN ('bn', 'en', 'both')),

    mature_content_enabled BOOLEAN NOT NULL DEFAULT FALSE,

    favorite_categories INTEGER[] NOT NULL DEFAULT '{}',

    default_theme TEXT NOT NULL DEFAULT 'light'
        CHECK (default_theme IN ('light', 'dark', 'sepia')),

    consumer_story_read_sum INTEGER NOT NULL DEFAULT 0,
    consumer_chapter_read_sum INTEGER NOT NULL DEFAULT 0,
    consumer_reading_minute_sum INTEGER NOT NULL DEFAULT 0,

    reading_streak_days INTEGER NOT NULL DEFAULT 0,
    longest_streak_days INTEGER NOT NULL DEFAULT 0,

    last_read_date DATE,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT consumers_story_read_sum_non_negative
        CHECK (consumer_story_read_sum >= 0),

    CONSTRAINT consumers_chapter_read_sum_non_negative
        CHECK (consumer_chapter_read_sum >= 0),

    CONSTRAINT consumers_reading_minute_sum_non_negative
        CHECK (consumer_reading_minute_sum >= 0),

    CONSTRAINT consumers_reading_streak_non_negative
        CHECK (reading_streak_days >= 0),

    CONSTRAINT consumers_longest_streak_non_negative
        CHECK (longest_streak_days >= 0)
);

COMMENT ON TABLE public.consumers IS 'Private reader preferences/stats. Auto-created for every new user via trg_create_consumer. All writes happen via edge functions.';

CREATE INDEX IF NOT EXISTS idx_consumers_favorite_categories
    ON public.consumers USING gin (favorite_categories);
-- NOTE: favorite_categories has no FK integrity to a categories
-- table. If you have (or add) a public.categories table, prefer a
-- junction table (consumer_id, category_id) with a real FK over
-- an int array.

DROP TRIGGER IF EXISTS trg_consumers_updated_at ON public.consumers;

CREATE TRIGGER trg_consumers_updated_at
BEFORE UPDATE ON public.consumers
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- ==========================================================
-- Auto-create consumer for every new user
-- ==========================================================

CREATE OR REPLACE FUNCTION public.create_consumer_for_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO public.consumers (id)
    VALUES (NEW.id)
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_consumer ON public.users;

CREATE TRIGGER trg_create_consumer
AFTER INSERT ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.create_consumer_for_user();

-- ==========================================================
-- Access control — read-only for clients, and only their own
-- row (this data is private, unlike profiles/creators).
-- Writes happen via edge functions (service_role) only.
-- ==========================================================

ALTER TABLE public.consumers ENABLE ROW LEVEL SECURITY;

REVOKE INSERT, UPDATE, DELETE ON public.consumers FROM anon, authenticated;
GRANT SELECT ON public.consumers TO anon, authenticated;

CREATE POLICY consumers_select_own
    ON public.consumers FOR SELECT
    USING (auth.uid() = id);