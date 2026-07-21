-- ==========================================================
-- 03_creators.sql
-- Run order: 4 of 6
-- Requires: 00_shared_functions.sql, 01_users.sql
-- ==========================================================

CREATE TABLE IF NOT EXISTS public.creators (
    id UUID PRIMARY KEY
        REFERENCES public.users(id)
        ON DELETE CASCADE,

    tagline TEXT NOT NULL DEFAULT '',

    is_verified BOOLEAN NOT NULL DEFAULT FALSE,

    badge TEXT NOT NULL DEFAULT 'none'
        CHECK (badge IN ('none', 'verified', 'pro', 'featured')),

    creator_story_sum INTEGER NOT NULL DEFAULT 0,
    creator_like_sum INTEGER NOT NULL DEFAULT 0,
    creator_reading_sum INTEGER NOT NULL DEFAULT 0,

    creator_rating_sum INTEGER NOT NULL DEFAULT 0,
    creator_rating_count INTEGER NOT NULL DEFAULT 0,

    creator_rating_average NUMERIC(3,2)
        GENERATED ALWAYS AS (
            CASE
                WHEN creator_rating_count = 0 THEN NULL
                ELSE ROUND(
                    creator_rating_sum::NUMERIC / creator_rating_count,
                    2
                )
            END
        ) STORED,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT creators_tagline_length
        CHECK (char_length(tagline) <= 200),

    CONSTRAINT creators_story_sum_non_negative
        CHECK (creator_story_sum >= 0),

    CONSTRAINT creators_like_sum_non_negative
        CHECK (creator_like_sum >= 0),

    CONSTRAINT creators_reading_sum_non_negative
        CHECK (creator_reading_sum >= 0),

    CONSTRAINT creators_rating_sum_non_negative
        CHECK (creator_rating_sum >= 0),

    CONSTRAINT creators_rating_count_non_negative
        CHECK (creator_rating_count >= 0)
);

COMMENT ON TABLE public.creators IS 'Extra data for users with is_creator = true. Row lifecycle managed by trg_users_to_creators. All writes happen via edge functions.';

CREATE INDEX IF NOT EXISTS idx_creators_badge
    ON public.creators (badge);

CREATE INDEX IF NOT EXISTS idx_creators_rating_average
    ON public.creators (creator_rating_average DESC NULLS LAST);

DROP TRIGGER IF EXISTS trg_creators_updated_at ON public.creators;

CREATE TRIGGER trg_creators_updated_at
BEFORE UPDATE ON public.creators
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- ==========================================================
-- Auto-create/delete creator record based on users.is_creator
-- ==========================================================

CREATE OR REPLACE FUNCTION public.sync_users_to_creators()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    IF NEW.is_creator THEN
        INSERT INTO public.creators (id)
        VALUES (NEW.id)
        ON CONFLICT (id) DO NOTHING;
    ELSE
        DELETE FROM public.creators
        WHERE id = NEW.id;
    END IF;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_users_to_creators ON public.users;

CREATE TRIGGER trg_users_to_creators
AFTER INSERT OR UPDATE OF is_creator
ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.sync_users_to_creators();

-- ==========================================================
-- Access control — read-only for clients, writes via edge
-- functions (service_role) only.
-- ==========================================================

ALTER TABLE public.creators ENABLE ROW LEVEL SECURITY;

REVOKE INSERT, UPDATE, DELETE ON public.creators FROM anon, authenticated;
GRANT SELECT ON public.creators TO anon, authenticated;

CREATE POLICY creators_select_public
    ON public.creators FOR SELECT
    USING (TRUE);