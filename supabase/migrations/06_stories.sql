-- ============================================================
-- Extensions
-- ============================================================
create extension if not exists "pgcrypto";

-- ============================================================
-- TABLE: stories
-- ============================================================
create table if not exists public.stories (
  id uuid primary key default gen_random_uuid(),
  creator uuid not null references auth.users (id) on delete cascade,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  title text not null,
  thumbnail text not null,
  page_count integer not null default 0,
  status text not null default 'draft'
    check (status in ('draft', 'private', 'public')),
  banned boolean not null default false,
  views_count integer not null default 0,
  likes_count integer not null default 0,
  category text not null,
  tags text[] not null default '{}',
  rating_sum numeric not null default 0,
  rating_time integer not null default 0,
  verified boolean not null default false,
  cost numeric not null default 0,
  is_paid boolean not null default false,
  search_queue boolean not null default false,
  related uuid[] not null default '{}'
);

-- A paid story must have a real price; a free story's cost stays at 0.
-- Backstop at the DB layer in case a row is ever written outside the
-- create-story edge function's validation.
alter table public.stories
  drop constraint if exists stories_paid_cost_check;
alter table public.stories
  add constraint stories_paid_cost_check
  check (not is_paid or cost > 0);

create index if not exists stories_creator_idx on public.stories (creator);
create index if not exists stories_status_idx on public.stories (status);
create index if not exists stories_category_idx on public.stories (category);
create index if not exists stories_search_queue_idx on public.stories (search_queue)
  where search_queue = true;

create or replace function public.set_stories_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists stories_set_updated_at on public.stories;
create trigger stories_set_updated_at
  before update on public.stories
  for each row
  execute function public.set_stories_updated_at();

-- Server-only columns on `stories` (banned, verified, counts, rating,
-- page_count, search_queue, related, creator, created_at) must never be
-- client-writable, even though owners are otherwise allowed to UPDATE
-- their own row (e.g. to publish a draft or edit the title). Requests
-- made with the service-role key (the edge functions) are exempt.
create or replace function public.protect_stories_server_columns()
returns trigger
language plpgsql
as $$
begin
  if auth.role() = 'service_role' then
    return new;
  end if;

  new.creator      := old.creator;
  new.created_at   := old.created_at;
  new.banned       := old.banned;
  new.verified     := old.verified;
  new.views_count  := old.views_count;
  new.likes_count  := old.likes_count;
  new.rating_sum   := old.rating_sum;
  new.rating_time  := old.rating_time;
  new.page_count   := old.page_count;
  new.search_queue := old.search_queue;
  new.related      := old.related;

  return new;
end;
$$;

drop trigger if exists trg_protect_stories_columns on public.stories;
create trigger trg_protect_stories_columns
  before update on public.stories
  for each row
  execute function public.protect_stories_server_columns();

alter table public.stories enable row level security;

drop policy if exists "Public stories are viewable by everyone" on public.stories;
create policy "Public stories are viewable by everyone"
  on public.stories for select
  using (status = 'public' and banned = false);

drop policy if exists "Creators can view their own stories" on public.stories;
create policy "Creators can view their own stories"
  on public.stories for select
  using (auth.uid() = creator);

drop policy if exists "Creators can update their own stories" on public.stories;
create policy "Creators can update their own stories"
  on public.stories for update
  using (auth.uid() = creator)
  with check (auth.uid() = creator);

-- No direct client inserts: rows are created only by the create-story
-- Edge Function, which uses the service-role key and bypasses RLS.
drop policy if exists "Block direct client inserts" on public.stories;
create policy "Block direct client inserts"
  on public.stories for insert
  with check (false);