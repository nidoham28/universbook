-- ==========================================================
-- 05_auth.sql
-- Run order: 6 of 6 (LAST — depends on users/profiles/creators/consumers
-- all existing, since inserting into public.users fans out to
-- trg_create_profile, trg_create_consumer, trg_users_to_creators)
-- Requires: 01_users.sql, 02_profiles.sql, 03_creators.sql, 04_consumers.sql
-- ==========================================================

-- ==========================================================
-- Create public.users row when auth.users is created
-- ==========================================================

CREATE OR REPLACE FUNCTION public.handle_new_auth_user()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    INSERT INTO public.users (
        id,
        email,
        auth_provider,
        email_verified
    )
    VALUES (
        NEW.id,
        NEW.email,
        COALESCE(
            NEW.raw_app_meta_data->>'provider',
            'email'
        ),
        NEW.email_confirmed_at IS NOT NULL
    )
    ON CONFLICT (id) DO NOTHING;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_handle_new_auth_user ON auth.users;

CREATE TRIGGER trg_handle_new_auth_user
AFTER INSERT ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.handle_new_auth_user();

-- ==========================================================
-- Keep email / email_verified in sync after signup.
-- Previously these were only set once at insert time — a later
-- email change or verification in auth.users was never reflected
-- in public.users.
-- ==========================================================

CREATE OR REPLACE FUNCTION public.sync_auth_user_changes()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public, pg_temp
AS $$
BEGIN
    UPDATE public.users
    SET
        email = NEW.email,
        email_verified = NEW.email_confirmed_at IS NOT NULL
    WHERE id = NEW.id;

    RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_sync_auth_user_changes ON auth.users;

CREATE TRIGGER trg_sync_auth_user_changes
AFTER UPDATE OF email, email_confirmed_at ON auth.users
FOR EACH ROW
EXECUTE FUNCTION public.sync_auth_user_changes();