CREATE TABLE public.users (
id                      UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,

    -- Auth / Account
    email                   TEXT UNIQUE,
    is_creator              BOOLEAN NOT NULL DEFAULT FALSE,
    is_admin                BOOLEAN NOT NULL DEFAULT FALSE,
    private_account         BOOLEAN NOT NULL DEFAULT FALSE,     -- NEW
    account_status          TEXT NOT NULL DEFAULT 'active'
                                CHECK (account_status IN ('active','suspended','banned','deactivated')),
    auth_provider           TEXT NOT NULL DEFAULT 'email'
                                CHECK (auth_provider IN ('email','google','facebook','apple')),
    email_verified          BOOLEAN NOT NULL DEFAULT FALSE,
    last_login_at           TIMESTAMPTZ,

    -- Profile Data
    username                TEXT NOT NULL UNIQUE,
    display_name            TEXT NOT NULL,
    avatar_url              TEXT,
    bio                     TEXT NOT NULL DEFAULT '',

    -- Creator Data
    creator_tagline         TEXT NOT NULL DEFAULT '',
    creator_is_verified     BOOLEAN NOT NULL DEFAULT FALSE,
    creator_badge           TEXT NOT NULL DEFAULT 'none'
                                CHECK (creator_badge IN ('none','verified','pro','featured')),
    creator_total_stories   INT NOT NULL DEFAULT 0,
    creator_total_likes     INT NOT NULL DEFAULT 0,
    creator_total_reading   INT NOT NULL DEFAULT 0,
    creator_total_rating    INT NOT NULL DEFAULT 0,
    creator_total_times     INT NOT NULL DEFAULT 0,

    -- Consumer Data
    preferred_lang          TEXT NOT NULL DEFAULT 'bn'
                                CHECK (preferred_lang IN ('bn','en','both')),
    mature_content_enabled  BOOLEAN NOT NULL DEFAULT FALSE,
    favorite_categories     INT[] NOT NULL DEFAULT '{}',
    default_theme           TEXT NOT NULL DEFAULT 'light'
                                CHECK (default_theme IN ('light','dark','sepia')),
    total_stories_read      INT NOT NULL DEFAULT 0,
    total_chapters_read     INT NOT NULL DEFAULT 0,
    total_reading_minutes   INT NOT NULL DEFAULT 0,
    reading_streak_days     INT NOT NULL DEFAULT 0,
    longest_streak_days     INT NOT NULL DEFAULT 0,
    last_read_date          DATE,

    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT users_username_lowercase CHECK (username = lower(username)),
    CONSTRAINT users_username_length CHECK (char_length(username) BETWEEN 3 AND 30),
    CONSTRAINT users_username_format CHECK (username ~ '^[a-z0-9_]+$'),
    CONSTRAINT users_display_name_length CHECK (char_length(display_name) BETWEEN 1 AND 60)
);

CREATE TABLE public.profiles (
id                UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
username          TEXT NOT NULL UNIQUE,
display_name      TEXT NOT NULL,
avatar_url        TEXT,
cover_url         TEXT,                    -- NEW
bio               TEXT NOT NULL DEFAULT '',
birthday          DATE,                    -- NEW
joined_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),   -- NEW
follower_count    INT NOT NULL DEFAULT 0,  -- NEW
following_count   INT NOT NULL DEFAULT 0,  -- NEW
created_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),
updated_at        TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    CONSTRAINT profiles_username_lowercase CHECK (username = lower(username)),
    CONSTRAINT profiles_username_length CHECK (char_length(username) BETWEEN 3 AND 30),
    CONSTRAINT profiles_username_format CHECK (username ~ '^[a-z0-9_]+$')
);

CREATE TABLE public.creators (
id                    UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
tagline               TEXT NOT NULL DEFAULT '',
is_verified           BOOLEAN NOT NULL DEFAULT FALSE,
badge                 TEXT NOT NULL DEFAULT 'none'
CHECK (badge IN ('none','verified','pro','featured')),
total_stories         INT NOT NULL DEFAULT 0,
total_likes           INT NOT NULL DEFAULT 0,     -- NEW
total_reading         INT NOT NULL DEFAULT 0,     -- NEW
total_rating          INT NOT NULL DEFAULT 0,     -- NEW
total_times           INT NOT NULL DEFAULT 0      -- NEW
);

CREATE TABLE public.consumers (
id                      UUID PRIMARY KEY REFERENCES public.users(id) ON DELETE CASCADE,
preferred_lang          TEXT NOT NULL DEFAULT 'bn'
CHECK (preferred_lang IN ('bn','en','both')),
mature_content_enabled  BOOLEAN NOT NULL DEFAULT FALSE,
favorite_categories     INT[] NOT NULL DEFAULT '{}',
default_theme           TEXT NOT NULL DEFAULT 'light'
CHECK (default_theme IN ('light','dark','sepia')),
total_stories_read      INT NOT NULL DEFAULT 0,
total_chapters_read     INT NOT NULL DEFAULT 0,
total_reading_minutes   INT NOT NULL DEFAULT 0,
reading_streak_days     INT NOT NULL DEFAULT 0,
longest_streak_days     INT NOT NULL DEFAULT 0,
last_read_date          DATE
);