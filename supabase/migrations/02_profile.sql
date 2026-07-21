-- ==========================================================
-- 02_profiles.sql
-- Run order: 3 of 6
-- Requires: 00_shared_functions.sql, 01_users.sql
-- Supabase roles expected: anon, authenticated, service_role
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

COMMENT ON TABLE public.profiles IS
'Public-facing profile data. Auto-created for every user via trg_create_profile. Clients are read-only; writes should happen through Edge Functions using service_role.';

-- ==========================================================
-- Indexes
-- ==========================================================

-- Optional fuzzy-search index on display_name.
CREATE EXTENSION IF NOT EXISTS pg_trgm;

CREATE INDEX IF NOT EXISTS idx_profiles_display_name_trgm
    ON public.profiles USING gin (display_name gin_trgm_ops);

CREATE INDEX IF NOT EXISTS idx_profiles_joined_at
    ON public.profiles (joined_at DESC);

CREATE INDEX IF NOT EXISTS idx_profiles_follower_count
    ON public.profiles (follower_count DESC);

-- ==========================================================
-- updated_at trigger
-- Requires public.set_updated_at() from 00_shared_functions.sql
-- ==========================================================

DROP TRIGGER IF EXISTS trg_profiles_updated_at ON public.profiles;

CREATE TRIGGER trg_profiles_updated_at
BEFORE UPDATE ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- ==========================================================
-- Unique username generator
-- Race-condition hardened using transaction advisory locks.
-- No pgcrypto dependency.
-- ==========================================================

CREATE OR REPLACE FUNCTION public.generate_unique_username()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
DECLARE
    base_username TEXT;
    candidate_username TEXT;
    i INTEGER;
    max_attempts INTEGER := 50;
BEGIN
    -- Normalize explicit username if one is supplied.
    NEW.username := lower(btrim(COALESCE(NEW.username, '')));

    -- If caller/edge function supplied a username, keep it.
    -- Constraints + UNIQUE index validate it.
    IF NEW.username <> '' THEN
        PERFORM pg_advisory_xact_lock(
            hashtext('profiles.username'),
            hashtext(NEW.username)
        );

        RETURN NEW;
    END IF;

    -- 25 chars total: 'user_' + 20 UUID hex chars.
    -- Fits username length <= 30.
    base_username := 'user_' || substring(replace(NEW.id::text, '-', '') FROM 1 FOR 20);

    -- Try deterministic candidates first.
    FOR i IN 0..max_attempts LOOP
        IF i = 0 THEN
            candidate_username := base_username;
        ELSE
            candidate_username :=
                left(base_username, 30 - char_length('_' || i::text))
                || '_'
                || i::text;
        END IF;

        -- Serialize concurrent attempts for the same username.
        PERFORM pg_advisory_xact_lock(
            hashtext('profiles.username'),
            hashtext(candidate_username)
        );

        IF NOT EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.username = candidate_username
        ) THEN
            NEW.username := candidate_username;
            RETURN NEW;
        END IF;
    END LOOP;

    -- Fallback: generate a pseudo-random candidate using built-in md5/random.
    FOR i IN 1..max_attempts LOOP
        candidate_username :=
            'user_' ||
            substring(
                md5(NEW.id::text || clock_timestamp()::text || random()::text)
                FROM 1 FOR 20
            );

        PERFORM pg_advisory_xact_lock(
            hashtext('profiles.username'),
            hashtext(candidate_username)
        );

        IF NOT EXISTS (
            SELECT 1
            FROM public.profiles p
            WHERE p.username = candidate_username
        ) THEN
            NEW.username := candidate_username;
            RETURN NEW;
        END IF;
    END LOOP;

    RAISE EXCEPTION 'Could not generate a unique username for profile %', NEW.id
        USING ERRCODE = 'unique_violation';
END;
$$;

REVOKE ALL ON FUNCTION public.generate_unique_username() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_generate_username ON public.profiles;

CREATE TRIGGER trg_generate_username
BEFORE INSERT ON public.profiles
FOR EACH ROW
EXECUTE FUNCTION public.generate_unique_username();

-- ==========================================================
-- Auto-create profile for every new user
-- SECURITY DEFINER is important because normal clients do not
-- have INSERT permission on public.profiles.
-- ==========================================================

CREATE OR REPLACE FUNCTION public.create_profile_for_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO public.profiles (
        id,
        username,
        display_name
    )
    VALUES (
        NEW.id,
        NULL,
        'New user'
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;

REVOKE ALL ON FUNCTION public.create_profile_for_user() FROM PUBLIC;

DROP TRIGGER IF EXISTS trg_create_profile ON public.users;

CREATE TRIGGER trg_create_profile
AFTER INSERT ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.create_profile_for_user();

-- ==========================================================
-- Helper for anonymous profile visibility
--
-- Using SECURITY DEFINER avoids requiring anon/authenticated
-- to have direct SELECT permission on public.users just so RLS
-- can check private_account.
-- ==========================================================

CREATE OR REPLACE FUNCTION public.profile_is_public(profile_user_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
STABLE
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
    SELECT COALESCE(
        (
            SELECT u.private_account IS NOT TRUE
            FROM public.users u
            WHERE u.id = profile_user_id
        ),
        FALSE
    );
$$;

REVOKE ALL ON FUNCTION public.profile_is_public(UUID) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.profile_is_public(UUID) TO anon, authenticated, service_role;

-- ==========================================================
-- Access control
--
-- Client behavior:
--   anon          -> SELECT public profiles only
--   authenticated -> SELECT all profiles
--
-- Edge function behavior:
--   service_role -> SELECT/INSERT/UPDATE/DELETE
--
-- Important:
--   Do not expose the service_role key to clients.
-- ==========================================================

ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;

REVOKE ALL ON public.profiles FROM PUBLIC;
REVOKE INSERT, UPDATE, DELETE ON public.profiles FROM anon, authenticated;

GRANT USAGE ON SCHEMA public TO anon, authenticated, service_role;

GRANT SELECT ON public.profiles TO anon, authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.profiles TO service_role;

DROP POLICY IF EXISTS profiles_select_public ON public.profiles;
DROP POLICY IF EXISTS profiles_select_anon_public ON public.profiles;
DROP POLICY IF EXISTS profiles_select_authenticated_all ON public.profiles;
DROP POLICY IF EXISTS profiles_service_role_all ON public.profiles;

-- Anonymous users can only read non-private profiles.
CREATE POLICY profiles_select_anon_public
    ON public.profiles
    FOR SELECT
    TO anon
    USING (
        public.profile_is_public(profiles.id)
    );

-- Authenticated users can read all profiles.
CREATE POLICY profiles_select_authenticated_all
    ON public.profiles
    FOR SELECT
    TO authenticated
    USING (
        TRUE
    );

-- Edge Functions using service_role can do everything.
-- Supabase service_role normally bypasses RLS, but this policy
-- keeps the intent explicit and helps in local/custom setups.
CREATE POLICY profiles_service_role_all
    ON public.profiles
    FOR ALL
    TO service_role
    USING (
        TRUE
    )
    WITH CHECK (
        TRUE
    );