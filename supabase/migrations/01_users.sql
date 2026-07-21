-- ==========================================================
-- 01_users.sql
-- Run order: 2 of 6
-- Requires: 00_shared_functions.sql
-- ==========================================================

CREATE TABLE IF NOT EXISTS public.users (
    id UUID PRIMARY KEY
        REFERENCES auth.users(id)
        ON DELETE CASCADE,

    email TEXT UNIQUE,

    is_creator BOOLEAN NOT NULL DEFAULT FALSE,
    is_admin BOOLEAN NOT NULL DEFAULT FALSE,
    private_account BOOLEAN NOT NULL DEFAULT FALSE,

    account_status TEXT NOT NULL DEFAULT 'active'
        CHECK (
            account_status IN (
                'active',
                'suspended',
                'banned',
                'deactivated'
            )
        ),

    auth_provider TEXT NOT NULL DEFAULT 'email'
        CHECK (
            auth_provider IN (
                'email',
                'google',
                'facebook',
                'apple'
            )
        ),

    email_verified BOOLEAN NOT NULL DEFAULT FALSE,

    last_login_at TIMESTAMPTZ,

    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

COMMENT ON TABLE public.users IS 'Core account row, 1:1 with auth.users. All writes happen via edge functions using the service_role key; clients get read-only access through RLS.';

CREATE INDEX IF NOT EXISTS idx_users_account_status
    ON public.users (account_status);

CREATE INDEX IF NOT EXISTS idx_users_is_creator
    ON public.users (id)
    WHERE is_creator = TRUE;

CREATE INDEX IF NOT EXISTS idx_users_is_admin
    ON public.users (id)
    WHERE is_admin = TRUE;

DROP TRIGGER IF EXISTS trg_users_updated_at ON public.users;

CREATE TRIGGER trg_users_updated_at
BEFORE UPDATE ON public.users
FOR EACH ROW
EXECUTE FUNCTION public.set_updated_at();

-- ==========================================================
-- Access control
-- Client roles (anon, authenticated) get SELECT only.
-- INSERT / UPDATE / DELETE are revoked at the grant level as
-- defense-in-depth, on top of RLS having no write policies.
-- All writes happen through edge functions using the
-- service_role key, which bypasses RLS entirely.
-- ==========================================================

ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

REVOKE INSERT, UPDATE, DELETE ON public.users FROM anon, authenticated;
GRANT SELECT ON public.users TO anon, authenticated;

CREATE POLICY users_select_own
    ON public.users FOR SELECT
    USING (auth.uid() = id);

CREATE POLICY users_select_admin
    ON public.users FOR SELECT
    USING (
        EXISTS (
            SELECT 1 FROM public.users u
            WHERE u.id = auth.uid() AND u.is_admin = TRUE
        )
    );

-- No INSERT/UPDATE/DELETE policies exist on this table, so with
-- RLS enabled, anon/authenticated cannot write under any
-- circumstance — even if a future grant re-adds write privileges,
-- RLS still defaults to deny with zero write policies present.