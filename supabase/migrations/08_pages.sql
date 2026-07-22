-- ============================================================
-- TABLE: pages  (create if missing)
-- ============================================================
create table if not exists public.pages (
  id             uuid        default gen_random_uuid() primary key,
  story_id       uuid        not null references public.stories(id) on delete cascade,
  creator        uuid        not null references auth.users(id)     on delete cascade,
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  title          text        not null default '',
  thumbnail      text,
  content        text        not null default '',
  status         text        not null default 'draft'
                             check (status in ('draft','private','public')),
  banned         boolean     not null default false,
  views_count    int         not null default 0,
  likes_count    int         not null default 0,
  comment_count  int         not null default 0,
  content_length int         not null default 0,
  page_no        int         not null,
  related_pages  uuid[]      not null default '{}'::uuid[],
  search_queue   text[]      not null default '{}'::text[]
);

-- ============================================================
-- Repair: rename stories_id → story_id if the old column exists
-- ============================================================
do $$
begin
  if exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name   = 'pages'
      and column_name  = 'stories_id'
  ) and not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name   = 'pages'
      and column_name  = 'story_id'
  ) then
    alter table public.pages rename column stories_id to story_id;
  end if;

  if not exists (
    select 1 from information_schema.columns
    where table_schema = 'public'
      and table_name   = 'pages'
      and column_name  = 'story_id'
  ) then
    alter table public.pages
      add column story_id uuid references public.stories(id) on delete cascade;
  end if;
end $$;

alter table public.pages
  add column if not exists creator        uuid references auth.users(id) on delete cascade,
  add column if not exists created_at     timestamptz default now(),
  add column if not exists updated_at     timestamptz default now(),
  add column if not exists title          text default '',
  add column if not exists thumbnail      text,
  add column if not exists content        text default '',
  add column if not exists status         text default 'draft',
  add column if not exists banned         boolean default false,
  add column if not exists views_count    int default 0,
  add column if not exists likes_count    int default 0,
  add column if not exists comment_count  int default 0,
  add column if not exists content_length int default 0,
  add column if not exists page_no        int,
  add column if not exists related_pages  uuid[] default '{}'::uuid[],
  add column if not exists search_queue   text[] default '{}'::text[];

do $$
begin
  alter table public.pages alter column creator        set not null;
  alter table public.pages alter column created_at     set not null;
  alter table public.pages alter column updated_at     set not null;
  alter table public.pages alter column title          set not null;
  alter table public.pages alter column content        set not null;
  alter table public.pages alter column status         set not null;
  alter table public.pages alter column banned         set not null;
  alter table public.pages alter column views_count    set not null;
  alter table public.pages alter column likes_count    set not null;
  alter table public.pages alter column comment_count  set not null;
  alter table public.pages alter column content_length set not null;
  alter table public.pages alter column page_no        set not null;
  alter table public.pages alter column related_pages  set not null;
  alter table public.pages alter column search_queue   set not null;
  if not exists (select 1 from public.pages where story_id is null) then
    alter table public.pages alter column story_id set not null;
  end if;
exception when others then
  raise notice 'Some NOT NULL constraints skipped: %', sqlerrm;
end $$;

do $$
begin
  alter table public.pages drop constraint if exists pages_status_check;
  alter table public.pages add constraint pages_status_check
    check (status in ('draft','private','public'));
end $$;

do $$
begin
  alter table public.pages drop constraint if exists pages_story_page_unique;
  alter table public.pages add constraint pages_story_page_unique unique (story_id, page_no);
end $$;

do $$
begin
  alter table public.pages drop constraint if exists pages_story_id_fkey;
  alter table public.pages add constraint pages_story_id_fkey
    foreign key (story_id) references public.stories(id) on delete cascade;
exception when others then
  raise notice 'FK pages_story_id_fkey skipped: %', sqlerrm;
end $$;

create index if not exists idx_pages_story_id on public.pages (story_id);
create index if not exists idx_pages_creator  on public.pages (creator);
create index if not exists idx_pages_status   on public.pages (status);
create index if not exists idx_pages_search_queue on public.pages using gin (search_queue);

create or replace function public.set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists trg_pages_updated_at on public.pages;
create trigger trg_pages_updated_at
  before update on public.pages
  for each row
  execute function public.set_updated_at();

-- ============================================================
-- append_page: atomic, race-safe page insert
-- ============================================================
-- Locks the parent story row before reading page_count, so two
-- concurrent "append a page" calls can't both compute the same
-- page_no. Only callable with the service-role key (see grants below);
-- upsert-page is the sole caller.
create or replace function public.append_page(
  p_story_id uuid,
  p_creator uuid,
  p_title text,
  p_content text,
  p_content_length int,
  p_thumbnail text,
  p_related_pages uuid[],
  p_search_queue text[],
  p_status text
) returns public.pages
language plpgsql
security definer
set search_path = public
as $$
declare
  v_next_no int;
  v_result public.pages;
begin
  select page_count into v_next_no
  from public.stories
  where id = p_story_id
  for update;

  if v_next_no is null then
    raise exception 'story not found';
  end if;

  insert into public.pages (
    story_id, creator, title, content, content_length,
    thumbnail, related_pages, search_queue, status, page_no
  ) values (
    p_story_id, p_creator, p_title, p_content, p_content_length,
    p_thumbnail, p_related_pages, p_search_queue, p_status, v_next_no
  ) returning * into v_result;

  update public.stories
  set page_count = v_next_no + 1
  where id = p_story_id;

  return v_result;
end;
$$;

revoke all on function public.append_page(
  uuid, uuid, text, text, int, text, uuid[], text[], text
) from public, anon, authenticated;
grant execute on function public.append_page(
  uuid, uuid, text, text, int, text, uuid[], text[], text
) to service_role;

-- ============================================================
-- RLS: pages
-- ============================================================
alter table public.pages enable row level security;

drop policy if exists "Public pages are viewable by everyone" on public.pages;
create policy "Public pages are viewable by everyone"
  on public.pages for select
  using (status = 'public' and banned = false);

drop policy if exists "Creators can view their own pages" on public.pages;
create policy "Creators can view their own pages"
  on public.pages for select
  using (auth.uid() = creator);

-- All writes to `pages` go through upsert-page (service role), which
-- keeps content_length / search_queue / page_no consistent and
-- enforces ownership. Direct client writes are blocked outright rather
-- than allowed-with-a-check, since there's no legitimate direct-write
-- path in this schema.
drop policy if exists "Creators manage own pages" on public.pages;

drop policy if exists "Block direct client inserts to pages" on public.pages;
create policy "Block direct client inserts to pages"
  on public.pages for insert
  with check (false);

drop policy if exists "Block direct client updates to pages" on public.pages;
create policy "Block direct client updates to pages"
  on public.pages for update
  using (false);

drop policy if exists "Block direct client deletes to pages" on public.pages;
create policy "Block direct client deletes to pages"
  on public.pages for delete
  using (false);

-- ============================================================
-- STORAGE: page-thumbnails
-- ============================================================
insert into storage.buckets (id, name, public)
values ('page-thumbnails', 'page-thumbnails', true)
on conflict (id) do nothing;

drop policy if exists "Authenticated users can upload thumbnails" on storage.objects;
create policy "Authenticated users can upload thumbnails"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'page-thumbnails'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Authenticated users can update own thumbnails" on storage.objects;
create policy "Authenticated users can update own thumbnails"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'page-thumbnails'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Authenticated users can delete own thumbnails" on storage.objects;
create policy "Authenticated users can delete own thumbnails"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'page-thumbnails'
    and auth.uid()::text = (storage.foldername(name))[1]
  );

drop policy if exists "Anyone can view thumbnails" on storage.objects;
create policy "Anyone can view thumbnails"
  on storage.objects for select
  using (bucket_id = 'page-thumbnails');