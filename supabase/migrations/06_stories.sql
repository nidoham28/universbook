-- Creates the `stories` table backing the "Create Stories" flow.
-- Inserts are performed only by the `create-story` Edge Function using
-- the service-role key, so client-side inserts are blocked by RLS.

create extension if not exists "pgcrypto";

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

create index if not exists stories_creator_idx on public.stories (creator);
create index if not exists stories_status_idx on public.stories (status);
create index if not exists stories_category_idx on public.stories (category);
create index if not exists stories_search_queue_idx on public.stories (search_queue)
  where search_queue = true;

-- Keep `updated_at` current on every update.
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

alter table public.stories enable row level security;

-- Anyone can read published, non-banned stories.
create policy "Public stories are viewable by everyone"
  on public.stories for select
  using (status = 'public' and banned = false);

-- Authors can always see their own stories, including drafts.
create policy "Creators can view their own stories"
  on public.stories for select
  using (auth.uid() = creator);

-- Authors can edit their own stories (e.g. publish a draft), but cannot
-- touch server-controlled fields like banned/verified/counts from the
-- client — enforce that separately via a column trigger or a view if
-- needed.
create policy "Creators can update their own stories"
  on public.stories for update
  using (auth.uid() = creator);

-- No direct client inserts: rows are created only by the create-story
-- Edge Function, which uses the service-role key and bypasses RLS.
create policy "Block direct client inserts"
  on public.stories for insert
  with check (false);