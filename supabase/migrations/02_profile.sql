-- ==========================================================
-- 02_profiles.sql
-- Run order: 3 of 6
-- Requires: 00_shared_functions.sql, 01_users.sql
-- ==========================================================

CREATE TABLE IF NOT EXISTS public.profiles (
    id UUID PRIMARY KEY
        REFERENCES public.users(id)
        ON DELETE CASCADE,

    username TEXT NOT NULL UNIQUE,
    display_name TEXT NOT NULL DEFAULT 'New user',

    avatar_url TEXT,
    cover_url TEXT,

    bio TEXT NOT NULL DEFAULT '',

    birthday DATE,

    joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    follower_count INTEGER NOT NULL DEFAULT 0,
    following_count INTEGER NOT NULL DEFAULT 0,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT profiles_username_lowercase
        CHECK (username = lower(username)),

    CONSTRAINT profiles_username_length
        CHECK (char_length(username) BETWEEN 3 AND 30),

    CONSTRAINT profiles_username_format
        CHECK (username ~ '^[a-z0-9_]+$'),

    CONSTRAINT profiles_display_name_length
        CHECK (char_length(display_name) BETWEEN 1 AND 60),

    CONSTRAINT profiles_bio_length
        CHECK (char_length(bio) <= 500),

    CONSTRAINT profiles_birthday_valid
        CHECK (birthday IS NULL OR birthday <= CURRENT_DATE),

    CONSTRAINT profiles_follower_count_non_negative
        CHECK (follower_count >= 0),

    CONSTRAINT profiles_following_count_non_negative
        CHECK (following_count >= 0)
);

COMMENT ON TABLE public.profiles IS 'Public-facing profile data. Auto-created for every user via trg_create_profile. All writes happen via edge functions.';

-- Optional fuzzy-search index on display_name.
-- Delete both lines below if you don't need trigram search.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_profiles_display_name_trgm
    ON public.profiles USING gin (display_name gin_trgm_ops);

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;

CREATE TRIGGER trg_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- ==========================================================
-- Unique username generator (race-condition hardened)
-- ==========================================================

CREATE OR REPLACE FUNCTION public.generate_unique_username()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
DECLARE
    base_username TEXT;
    candidate_username TEXT;
    suffix INTEGER := 0;
    max_attempts INTEGER := 20;
BEGIN
    IF NEW.username IS NOT NULL AND NEW.username <> '' THEN
        RETURN NEW;
    END IF;

    base_username := 'user_' || substring(replace(NEW.id::text, '-', '') FROM 1 FOR 8);
    candidate_username := base_username;

    LOOP
        IF NOT EXISTS (
            SELECT 1 FROM public.profiles WHERE username = candidate_username
        ) THEN
            NEW.username := candidate_username;
            RETURN NEW;
        END IF;

        suffix := suffix + 1;
        IF suffix > max_attempts THEN
            -- Fallback for heavy concurrent-signup collisions.
            -- Requires: CREATE EXTENSION IF NOT EXISTS pgcrypto;
            candidate_username := base_username || '_' || substring(gen_random_uuid()::text FROM 1 FOR 6);
            NEW.username := candidate_username;
            RETURN NEW;
        END IF;

        candidate_username := base_username || suffix;
    END LOOP;
END;
$$;
-- NOTE: there is still a narrow race window between the EXISTS
-- check and the actual INSERT under very high concurrent signup
-- volume. profiles.username is UNIQUE, so a genuine collision
-- raises unique_violation on insert rather than corrupting data —
-- the calling edge function should catch that and retry.

DROP TRIGGER IF EXISTS trg_generate_username ON public.profiles;

CREATE TRIGGER trg_generate_username
BEFORE INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.generate_unique_username();

-- ==========================================================
-- Auto-create profile for every new user
-- ==========================================================

CREATE OR REPLACE FUNCTION public.create_profile_for_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO public.profiles (id, username, display_name)
    VALUES (NEW.id, NULL, 'New user')
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_create_profile ON public.users;

CREATE TRIGGER trg_create_profile
AFTER INSERT ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.create_profile_for_user();

-- ==========================================================
-- Access control — read-only for clients, writes via edge
-- functions (service_role) only.
-- ==========================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

REVOKE INSERT, UPDATE, DELETE ON public.profiles FROM anon, authenticated;
GRANT SELECT ON public.profiles TO anon, authenticated;

CREATE POLICY profiles_select_public
    ON public.profiles FOR SELECT
    USING (
        NOT EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = profiles.id AND u.private_account = TRUE
        )
        OR auth.uid() = id
    );