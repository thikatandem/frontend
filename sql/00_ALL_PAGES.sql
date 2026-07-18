-- ============================================================
-- NEWS PAGE — news.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_news_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'NEWS',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_news_items_page_code_check check (page_code = 'NEWS'),
  constraint site_news_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_news_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_news_items_section_order_uidx
  on public.site_news_items(section_code, display_order);

create unique index if not exists site_news_items_slug_uidx
  on public.site_news_items(slug)
  where slug is not null;

create index if not exists site_news_items_public_idx
  on public.site_news_items(is_active, publish_at desc, display_order);

create index if not exists site_news_items_section_idx
  on public.site_news_items(section_code, display_order);

create index if not exists site_news_items_metadata_gin_idx
  on public.site_news_items using gin(metadata);

drop trigger if exists trg_site_news_items_updated_at on public.site_news_items;
create trigger trg_site_news_items_updated_at
before update on public.site_news_items
for each row execute function public.set_updated_at();

alter table public.site_news_items enable row level security;
alter table public.site_news_items force row level security;

drop policy if exists "site_news_items_public_read" on public.site_news_items;
create policy "site_news_items_public_read"
on public.site_news_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_news_items_admin_select" on public.site_news_items;
create policy "site_news_items_admin_select"
on public.site_news_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_news_items_admin_insert" on public.site_news_items;
create policy "site_news_items_admin_insert"
on public.site_news_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_news_items_admin_update" on public.site_news_items;
create policy "site_news_items_admin_update"
on public.site_news_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_news_items_admin_delete" on public.site_news_items;
create policy "site_news_items_admin_delete"
on public.site_news_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_news_items from public;
revoke all on table public.site_news_items from anon, authenticated;
grant select on table public.site_news_items to anon, authenticated;
grant insert, update, delete on table public.site_news_items to authenticated;
grant all on table public.site_news_items to service_role;

insert into public.site_news_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('NEWS', 'FEATURED', 'Featured story', 'Club news, athlete stories and competition updates from Thika Tandem.',
 'Read the latest', 'news.html#latest', '/assets/img/site/news/featured/news-featured-01-1920x1080.webp', 'Featured story',
 '{"category":"News","position":1}'::jsonb, 1, true, now()),
('NEWS', 'LATEST', 'Latest news', 'Browse announcements, results, training updates and community stories.',
 'Explore stories', 'news.html#latest', '/assets/img/site/news/cards/news-card-01-1200x900.webp', 'Latest news',
 '{"category":"News","position":2}'::jsonb, 2, true, now()),
('NEWS', 'CATEGORIES', 'News categories', 'Filter stories by racing, training, athletes, partnerships and community impact.',
 'Browse categories', 'news.html#categories', '/assets/img/site/news/cards/news-card-02-1200x900.webp', 'News categories',
 '{"category":"News","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_news_items is
  'Public CMS content for news.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_news_items
order by display_order;


-- ============================================================
-- EVENTS PAGE — events.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_events_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'EVENTS',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_events_items_page_code_check check (page_code = 'EVENTS'),
  constraint site_events_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_events_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_events_items_section_order_uidx
  on public.site_events_items(section_code, display_order);

create unique index if not exists site_events_items_slug_uidx
  on public.site_events_items(slug)
  where slug is not null;

create index if not exists site_events_items_public_idx
  on public.site_events_items(is_active, publish_at desc, display_order);

create index if not exists site_events_items_section_idx
  on public.site_events_items(section_code, display_order);

create index if not exists site_events_items_metadata_gin_idx
  on public.site_events_items using gin(metadata);

drop trigger if exists trg_site_events_items_updated_at on public.site_events_items;
create trigger trg_site_events_items_updated_at
before update on public.site_events_items
for each row execute function public.set_updated_at();

alter table public.site_events_items enable row level security;
alter table public.site_events_items force row level security;

drop policy if exists "site_events_items_public_read" on public.site_events_items;
create policy "site_events_items_public_read"
on public.site_events_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_events_items_admin_select" on public.site_events_items;
create policy "site_events_items_admin_select"
on public.site_events_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_events_items_admin_insert" on public.site_events_items;
create policy "site_events_items_admin_insert"
on public.site_events_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_events_items_admin_update" on public.site_events_items;
create policy "site_events_items_admin_update"
on public.site_events_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_events_items_admin_delete" on public.site_events_items;
create policy "site_events_items_admin_delete"
on public.site_events_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_events_items from public;
revoke all on table public.site_events_items from anon, authenticated;
grant select on table public.site_events_items to anon, authenticated;
grant insert, update, delete on table public.site_events_items to authenticated;
grant all on table public.site_events_items to service_role;

insert into public.site_events_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('EVENTS', 'FINDER', 'Find an event', 'Search upcoming races, camps, skills days and community rides.',
 'View calendar', 'events.html#calendar', '/assets/img/site/events/featured/events-featured-01-1920x1080.webp', 'Find an event',
 '{"category":"Events","position":1}'::jsonb, 1, true, now()),
('EVENTS', 'FEATURED', 'Featured event', 'See the next major Thika Tandem activity and registration details.',
 'Event details', 'events.html#featured', '/assets/img/site/events/cards/events-card-01-1200x800.webp', 'Featured event',
 '{"category":"Events","position":2}'::jsonb, 2, true, now()),
('EVENTS', 'SUPPORT', 'Event support', 'Learn how to enter, volunteer, officiate or attend.',
 'Get involved', 'volunteer.html', '/assets/img/site/events/cards/events-card-02-1200x800.webp', 'Event support',
 '{"category":"Events","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_events_items is
  'Public CMS content for events.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_events_items
order by display_order;


-- ============================================================
-- CAMPAIGNING PAGE — campaigning.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_campaigning_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'CAMPAIGNING',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_campaigning_items_page_code_check check (page_code = 'CAMPAIGNING'),
  constraint site_campaigning_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_campaigning_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_campaigning_items_section_order_uidx
  on public.site_campaigning_items(section_code, display_order);

create unique index if not exists site_campaigning_items_slug_uidx
  on public.site_campaigning_items(slug)
  where slug is not null;

create index if not exists site_campaigning_items_public_idx
  on public.site_campaigning_items(is_active, publish_at desc, display_order);

create index if not exists site_campaigning_items_section_idx
  on public.site_campaigning_items(section_code, display_order);

create index if not exists site_campaigning_items_metadata_gin_idx
  on public.site_campaigning_items using gin(metadata);

drop trigger if exists trg_site_campaigning_items_updated_at on public.site_campaigning_items;
create trigger trg_site_campaigning_items_updated_at
before update on public.site_campaigning_items
for each row execute function public.set_updated_at();

alter table public.site_campaigning_items enable row level security;
alter table public.site_campaigning_items force row level security;

drop policy if exists "site_campaigning_items_public_read" on public.site_campaigning_items;
create policy "site_campaigning_items_public_read"
on public.site_campaigning_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_campaigning_items_admin_select" on public.site_campaigning_items;
create policy "site_campaigning_items_admin_select"
on public.site_campaigning_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_campaigning_items_admin_insert" on public.site_campaigning_items;
create policy "site_campaigning_items_admin_insert"
on public.site_campaigning_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_campaigning_items_admin_update" on public.site_campaigning_items;
create policy "site_campaigning_items_admin_update"
on public.site_campaigning_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_campaigning_items_admin_delete" on public.site_campaigning_items;
create policy "site_campaigning_items_admin_delete"
on public.site_campaigning_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_campaigning_items from public;
revoke all on table public.site_campaigning_items from anon, authenticated;
grant select on table public.site_campaigning_items to anon, authenticated;
grant insert, update, delete on table public.site_campaigning_items to authenticated;
grant all on table public.site_campaigning_items to service_role;

insert into public.site_campaigning_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('CAMPAIGNING', 'MISSION', 'Our campaign', 'We advocate for accessible roads, inclusive facilities and equal sporting opportunity.',
 'Our priorities', 'campaigning.html#priorities', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Our campaign',
 '{"category":"Campaigning","position":1}'::jsonb, 1, true, now()),
('CAMPAIGNING', 'ACTION', 'Take action', 'Support awareness, community consultation and practical improvements.',
 'Get involved', 'campaigning.html#action', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Take action',
 '{"category":"Campaigning","position":2}'::jsonb, 2, true, now()),
('CAMPAIGNING', 'IMPACT', 'Our impact', 'See how partnership and advocacy create lasting change.',
 'View impact', 'campaigning.html#impact', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Our impact',
 '{"category":"Campaigning","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_campaigning_items is
  'Public CMS content for campaigning.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_campaigning_items
order by display_order;


-- ============================================================
-- LEARNING PAGE — learning.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_learning_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'LEARNING',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_learning_items_page_code_check check (page_code = 'LEARNING'),
  constraint site_learning_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_learning_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_learning_items_section_order_uidx
  on public.site_learning_items(section_code, display_order);

create unique index if not exists site_learning_items_slug_uidx
  on public.site_learning_items(slug)
  where slug is not null;

create index if not exists site_learning_items_public_idx
  on public.site_learning_items(is_active, publish_at desc, display_order);

create index if not exists site_learning_items_section_idx
  on public.site_learning_items(section_code, display_order);

create index if not exists site_learning_items_metadata_gin_idx
  on public.site_learning_items using gin(metadata);

drop trigger if exists trg_site_learning_items_updated_at on public.site_learning_items;
create trigger trg_site_learning_items_updated_at
before update on public.site_learning_items
for each row execute function public.set_updated_at();

alter table public.site_learning_items enable row level security;
alter table public.site_learning_items force row level security;

drop policy if exists "site_learning_items_public_read" on public.site_learning_items;
create policy "site_learning_items_public_read"
on public.site_learning_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_learning_items_admin_select" on public.site_learning_items;
create policy "site_learning_items_admin_select"
on public.site_learning_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_learning_items_admin_insert" on public.site_learning_items;
create policy "site_learning_items_admin_insert"
on public.site_learning_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_learning_items_admin_update" on public.site_learning_items;
create policy "site_learning_items_admin_update"
on public.site_learning_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_learning_items_admin_delete" on public.site_learning_items;
create policy "site_learning_items_admin_delete"
on public.site_learning_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_learning_items from public;
revoke all on table public.site_learning_items from anon, authenticated;
grant select on table public.site_learning_items to anon, authenticated;
grant insert, update, delete on table public.site_learning_items to authenticated;
grant all on table public.site_learning_items to service_role;

insert into public.site_learning_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('LEARNING', 'PATHWAY', 'Learning pathway', 'Progress from first ride to confident tandem participation.',
 'Start learning', 'start.html', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Learning pathway',
 '{"category":"Learning","position":1}'::jsonb, 1, true, now()),
('LEARNING', 'COACHING', 'Coaching resources', 'Inclusive session guidance for coaches, pilots and volunteers.',
 'Coach development', 'coaches.html', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Coaching resources',
 '{"category":"Learning","position":2}'::jsonb, 2, true, now()),
('LEARNING', 'SAFETY', 'Safe practice', 'Clear guidance for communication, equipment checks and road awareness.',
 'Read guidance', 'learning.html#safety', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Safe practice',
 '{"category":"Learning","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_learning_items is
  'Public CMS content for learning.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_learning_items
order by display_order;


-- ============================================================
-- INSIGHT ZONE PAGE — insight-zone.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_insight_zone_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'INSIGHT_ZONE',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_insight_zone_items_page_code_check check (page_code = 'INSIGHT_ZONE'),
  constraint site_insight_zone_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_insight_zone_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_insight_zone_items_section_order_uidx
  on public.site_insight_zone_items(section_code, display_order);

create unique index if not exists site_insight_zone_items_slug_uidx
  on public.site_insight_zone_items(slug)
  where slug is not null;

create index if not exists site_insight_zone_items_public_idx
  on public.site_insight_zone_items(is_active, publish_at desc, display_order);

create index if not exists site_insight_zone_items_section_idx
  on public.site_insight_zone_items(section_code, display_order);

create index if not exists site_insight_zone_items_metadata_gin_idx
  on public.site_insight_zone_items using gin(metadata);

drop trigger if exists trg_site_insight_zone_items_updated_at on public.site_insight_zone_items;
create trigger trg_site_insight_zone_items_updated_at
before update on public.site_insight_zone_items
for each row execute function public.set_updated_at();

alter table public.site_insight_zone_items enable row level security;
alter table public.site_insight_zone_items force row level security;

drop policy if exists "site_insight_zone_items_public_read" on public.site_insight_zone_items;
create policy "site_insight_zone_items_public_read"
on public.site_insight_zone_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_insight_zone_items_admin_select" on public.site_insight_zone_items;
create policy "site_insight_zone_items_admin_select"
on public.site_insight_zone_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_insight_zone_items_admin_insert" on public.site_insight_zone_items;
create policy "site_insight_zone_items_admin_insert"
on public.site_insight_zone_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_insight_zone_items_admin_update" on public.site_insight_zone_items;
create policy "site_insight_zone_items_admin_update"
on public.site_insight_zone_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_insight_zone_items_admin_delete" on public.site_insight_zone_items;
create policy "site_insight_zone_items_admin_delete"
on public.site_insight_zone_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_insight_zone_items from public;
revoke all on table public.site_insight_zone_items from anon, authenticated;
grant select on table public.site_insight_zone_items to anon, authenticated;
grant insert, update, delete on table public.site_insight_zone_items to authenticated;
grant all on table public.site_insight_zone_items to service_role;

insert into public.site_insight_zone_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('INSIGHT_ZONE', 'ADVICE', 'Rider advice', 'Training, recovery, equipment and confidence-building guidance.',
 'Explore advice', 'insight-zone.html#advice', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Rider advice',
 '{"category":"Insight Zone","position":1}'::jsonb, 1, true, now()),
('INSIGHT_ZONE', 'PERFORMANCE', 'Performance insight', 'Understand pacing, teamwork and preparation.',
 'Improve performance', 'insight-zone.html#performance', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Performance insight',
 '{"category":"Insight Zone","position":2}'::jsonb, 2, true, now()),
('INSIGHT_ZONE', 'WELLBEING', 'Wellbeing', 'Support healthy, sustainable participation in sport.',
 'Wellbeing guidance', 'insight-zone.html#wellbeing', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Wellbeing',
 '{"category":"Insight Zone","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_insight_zone_items is
  'Public CMS content for insight-zone.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_insight_zone_items
order by display_order;


-- ============================================================
-- NATIONAL TEAM PAGE — team.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_team_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'TEAM',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_team_items_page_code_check check (page_code = 'TEAM'),
  constraint site_team_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_team_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_team_items_section_order_uidx
  on public.site_team_items(section_code, display_order);

create unique index if not exists site_team_items_slug_uidx
  on public.site_team_items(slug)
  where slug is not null;

create index if not exists site_team_items_public_idx
  on public.site_team_items(is_active, publish_at desc, display_order);

create index if not exists site_team_items_section_idx
  on public.site_team_items(section_code, display_order);

create index if not exists site_team_items_metadata_gin_idx
  on public.site_team_items using gin(metadata);

drop trigger if exists trg_site_team_items_updated_at on public.site_team_items;
create trigger trg_site_team_items_updated_at
before update on public.site_team_items
for each row execute function public.set_updated_at();

alter table public.site_team_items enable row level security;
alter table public.site_team_items force row level security;

drop policy if exists "site_team_items_public_read" on public.site_team_items;
create policy "site_team_items_public_read"
on public.site_team_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_team_items_admin_select" on public.site_team_items;
create policy "site_team_items_admin_select"
on public.site_team_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_team_items_admin_insert" on public.site_team_items;
create policy "site_team_items_admin_insert"
on public.site_team_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_team_items_admin_update" on public.site_team_items;
create policy "site_team_items_admin_update"
on public.site_team_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_team_items_admin_delete" on public.site_team_items;
create policy "site_team_items_admin_delete"
on public.site_team_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_team_items from public;
revoke all on table public.site_team_items from anon, authenticated;
grant select on table public.site_team_items to anon, authenticated;
grant insert, update, delete on table public.site_team_items to authenticated;
grant all on table public.site_team_items to service_role;

insert into public.site_team_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('TEAM', 'SQUAD', 'National team', 'Meet active tandem pairs and the people supporting them.',
 'View squad', 'team.html#squad', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'National team',
 '{"category":"National Team","position":1}'::jsonb, 1, true, now()),
('TEAM', 'PATHWAY', 'Performance pathway', 'Understand selection, development and competition preparation.',
 'View pathway', 'team.html#pathway', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Performance pathway',
 '{"category":"National Team","position":2}'::jsonb, 2, true, now()),
('TEAM', 'STAFF', 'Coaches and staff', 'Meet the specialists behind safe and effective performance.',
 'Meet staff', 'team.html#staff', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Coaches and staff',
 '{"category":"National Team","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_team_items is
  'Public CMS content for team.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_team_items
order by display_order;


-- ============================================================
-- SHOP TEAM KIT PAGE — shop.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_shop_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'SHOP',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_shop_items_page_code_check check (page_code = 'SHOP'),
  constraint site_shop_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_shop_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_shop_items_section_order_uidx
  on public.site_shop_items(section_code, display_order);

create unique index if not exists site_shop_items_slug_uidx
  on public.site_shop_items(slug)
  where slug is not null;

create index if not exists site_shop_items_public_idx
  on public.site_shop_items(is_active, publish_at desc, display_order);

create index if not exists site_shop_items_section_idx
  on public.site_shop_items(section_code, display_order);

create index if not exists site_shop_items_metadata_gin_idx
  on public.site_shop_items using gin(metadata);

drop trigger if exists trg_site_shop_items_updated_at on public.site_shop_items;
create trigger trg_site_shop_items_updated_at
before update on public.site_shop_items
for each row execute function public.set_updated_at();

alter table public.site_shop_items enable row level security;
alter table public.site_shop_items force row level security;

drop policy if exists "site_shop_items_public_read" on public.site_shop_items;
create policy "site_shop_items_public_read"
on public.site_shop_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_shop_items_admin_select" on public.site_shop_items;
create policy "site_shop_items_admin_select"
on public.site_shop_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_shop_items_admin_insert" on public.site_shop_items;
create policy "site_shop_items_admin_insert"
on public.site_shop_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_shop_items_admin_update" on public.site_shop_items;
create policy "site_shop_items_admin_update"
on public.site_shop_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_shop_items_admin_delete" on public.site_shop_items;
create policy "site_shop_items_admin_delete"
on public.site_shop_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_shop_items from public;
revoke all on table public.site_shop_items from anon, authenticated;
grant select on table public.site_shop_items to anon, authenticated;
grant insert, update, delete on table public.site_shop_items to authenticated;
grant all on table public.site_shop_items to service_role;

insert into public.site_shop_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('SHOP', 'KIT', 'Team kit', 'Club jerseys, casual wear and selected accessories.',
 'Browse kit', 'shop.html#kit', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Team kit',
 '{"category":"Shop Team Kit","position":1}'::jsonb, 1, true, now()),
('SHOP', 'ORDER', 'How to order', 'Simple guidance for sizing, availability and collection.',
 'Ordering help', 'shop.html#order', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'How to order',
 '{"category":"Shop Team Kit","position":2}'::jsonb, 2, true, now()),
('SHOP', 'SUPPORT', 'Support through purchase', 'Selected purchases help fund athlete participation.',
 'Learn more', 'support.html', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Support through purchase',
 '{"category":"Shop Team Kit","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_shop_items is
  'Public CMS content for shop.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_shop_items
order by display_order;


-- ============================================================
-- BEGIN CYCLING PAGE — start.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_start_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'START',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_start_items_page_code_check check (page_code = 'START'),
  constraint site_start_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_start_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_start_items_section_order_uidx
  on public.site_start_items(section_code, display_order);

create unique index if not exists site_start_items_slug_uidx
  on public.site_start_items(slug)
  where slug is not null;

create index if not exists site_start_items_public_idx
  on public.site_start_items(is_active, publish_at desc, display_order);

create index if not exists site_start_items_section_idx
  on public.site_start_items(section_code, display_order);

create index if not exists site_start_items_metadata_gin_idx
  on public.site_start_items using gin(metadata);

drop trigger if exists trg_site_start_items_updated_at on public.site_start_items;
create trigger trg_site_start_items_updated_at
before update on public.site_start_items
for each row execute function public.set_updated_at();

alter table public.site_start_items enable row level security;
alter table public.site_start_items force row level security;

drop policy if exists "site_start_items_public_read" on public.site_start_items;
create policy "site_start_items_public_read"
on public.site_start_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_start_items_admin_select" on public.site_start_items;
create policy "site_start_items_admin_select"
on public.site_start_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_start_items_admin_insert" on public.site_start_items;
create policy "site_start_items_admin_insert"
on public.site_start_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_start_items_admin_update" on public.site_start_items;
create policy "site_start_items_admin_update"
on public.site_start_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_start_items_admin_delete" on public.site_start_items;
create policy "site_start_items_admin_delete"
on public.site_start_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_start_items from public;
revoke all on table public.site_start_items from anon, authenticated;
grant select on table public.site_start_items to anon, authenticated;
grant insert, update, delete on table public.site_start_items to authenticated;
grant all on table public.site_start_items to service_role;

insert into public.site_start_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('START', 'FIRST_RIDE', 'Your first ride', 'What to expect and how tandem cycling works.',
 'Get started', 'start.html#first-ride', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Your first ride',
 '{"category":"Begin Cycling","position":1}'::jsonb, 1, true, now()),
('START', 'EQUIPMENT', 'What you need', 'Comfortable clothing, a helmet and an open mind.',
 'Preparation', 'start.html#equipment', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'What you need',
 '{"category":"Begin Cycling","position":2}'::jsonb, 2, true, now()),
('START', 'NEXT_STEP', 'Book an introduction', 'Connect with the club and arrange a suitable first session.',
 'Contact us', 'contact.html', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Book an introduction',
 '{"category":"Begin Cycling","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_start_items is
  'Public CMS content for start.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_start_items
order by display_order;


-- ============================================================
-- MOUNTAIN BIKE PAGE — mtb.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_mtb_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'MTB',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_mtb_items_page_code_check check (page_code = 'MTB'),
  constraint site_mtb_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_mtb_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_mtb_items_section_order_uidx
  on public.site_mtb_items(section_code, display_order);

create unique index if not exists site_mtb_items_slug_uidx
  on public.site_mtb_items(slug)
  where slug is not null;

create index if not exists site_mtb_items_public_idx
  on public.site_mtb_items(is_active, publish_at desc, display_order);

create index if not exists site_mtb_items_section_idx
  on public.site_mtb_items(section_code, display_order);

create index if not exists site_mtb_items_metadata_gin_idx
  on public.site_mtb_items using gin(metadata);

drop trigger if exists trg_site_mtb_items_updated_at on public.site_mtb_items;
create trigger trg_site_mtb_items_updated_at
before update on public.site_mtb_items
for each row execute function public.set_updated_at();

alter table public.site_mtb_items enable row level security;
alter table public.site_mtb_items force row level security;

drop policy if exists "site_mtb_items_public_read" on public.site_mtb_items;
create policy "site_mtb_items_public_read"
on public.site_mtb_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_mtb_items_admin_select" on public.site_mtb_items;
create policy "site_mtb_items_admin_select"
on public.site_mtb_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_mtb_items_admin_insert" on public.site_mtb_items;
create policy "site_mtb_items_admin_insert"
on public.site_mtb_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_mtb_items_admin_update" on public.site_mtb_items;
create policy "site_mtb_items_admin_update"
on public.site_mtb_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_mtb_items_admin_delete" on public.site_mtb_items;
create policy "site_mtb_items_admin_delete"
on public.site_mtb_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_mtb_items from public;
revoke all on table public.site_mtb_items from anon, authenticated;
grant select on table public.site_mtb_items to anon, authenticated;
grant insert, update, delete on table public.site_mtb_items to authenticated;
grant all on table public.site_mtb_items to service_role;

insert into public.site_mtb_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('MTB', 'DISCIPLINE', 'Mountain biking', 'Explore off-road skills adapted for tandem and inclusive cycling.',
 'Learn the discipline', 'mtb.html#discipline', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Mountain biking',
 '{"category":"Mountain Bike","position":1}'::jsonb, 1, true, now()),
('MTB', 'SKILLS', 'Skills sessions', 'Build handling, communication and confidence progressively.',
 'Find training', 'learning.html', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Skills sessions',
 '{"category":"Mountain Bike","position":2}'::jsonb, 2, true, now()),
('MTB', 'EVENTS', 'Off-road events', 'Discover suitable events and club activities.',
 'See events', 'events.html', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Off-road events',
 '{"category":"Mountain Bike","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_mtb_items is
  'Public CMS content for mtb.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_mtb_items
order by display_order;


-- ============================================================
-- VOLUNTEER PAGE — volunteer.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_volunteer_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'VOLUNTEER',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_volunteer_items_page_code_check check (page_code = 'VOLUNTEER'),
  constraint site_volunteer_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_volunteer_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_volunteer_items_section_order_uidx
  on public.site_volunteer_items(section_code, display_order);

create unique index if not exists site_volunteer_items_slug_uidx
  on public.site_volunteer_items(slug)
  where slug is not null;

create index if not exists site_volunteer_items_public_idx
  on public.site_volunteer_items(is_active, publish_at desc, display_order);

create index if not exists site_volunteer_items_section_idx
  on public.site_volunteer_items(section_code, display_order);

create index if not exists site_volunteer_items_metadata_gin_idx
  on public.site_volunteer_items using gin(metadata);

drop trigger if exists trg_site_volunteer_items_updated_at on public.site_volunteer_items;
create trigger trg_site_volunteer_items_updated_at
before update on public.site_volunteer_items
for each row execute function public.set_updated_at();

alter table public.site_volunteer_items enable row level security;
alter table public.site_volunteer_items force row level security;

drop policy if exists "site_volunteer_items_public_read" on public.site_volunteer_items;
create policy "site_volunteer_items_public_read"
on public.site_volunteer_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_volunteer_items_admin_select" on public.site_volunteer_items;
create policy "site_volunteer_items_admin_select"
on public.site_volunteer_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_volunteer_items_admin_insert" on public.site_volunteer_items;
create policy "site_volunteer_items_admin_insert"
on public.site_volunteer_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_volunteer_items_admin_update" on public.site_volunteer_items;
create policy "site_volunteer_items_admin_update"
on public.site_volunteer_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_volunteer_items_admin_delete" on public.site_volunteer_items;
create policy "site_volunteer_items_admin_delete"
on public.site_volunteer_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_volunteer_items from public;
revoke all on table public.site_volunteer_items from anon, authenticated;
grant select on table public.site_volunteer_items to anon, authenticated;
grant insert, update, delete on table public.site_volunteer_items to authenticated;
grant all on table public.site_volunteer_items to service_role;

insert into public.site_volunteer_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('VOLUNTEER', 'ROLES', 'Volunteer roles', 'Support rides, events, administration, transport and athlete services.',
 'Explore roles', 'volunteer.html#roles', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Volunteer roles',
 '{"category":"Volunteer","position":1}'::jsonb, 1, true, now()),
('VOLUNTEER', 'PROCESS', 'How to join', 'Tell us your interests, availability and relevant experience.',
 'Apply', 'volunteer.html#apply', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'How to join',
 '{"category":"Volunteer","position":2}'::jsonb, 2, true, now()),
('VOLUNTEER', 'SAFEGUARDING', 'Safe volunteering', 'All roles follow club safeguarding and conduct standards.',
 'Safeguarding', 'safeguarding.html', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Safe volunteering',
 '{"category":"Volunteer","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_volunteer_items is
  'Public CMS content for volunteer.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_volunteer_items
order by display_order;


-- ============================================================
-- JOIN TODAY PAGE — membership.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_membership_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'MEMBERSHIP',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_membership_items_page_code_check check (page_code = 'MEMBERSHIP'),
  constraint site_membership_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_membership_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_membership_items_section_order_uidx
  on public.site_membership_items(section_code, display_order);

create unique index if not exists site_membership_items_slug_uidx
  on public.site_membership_items(slug)
  where slug is not null;

create index if not exists site_membership_items_public_idx
  on public.site_membership_items(is_active, publish_at desc, display_order);

create index if not exists site_membership_items_section_idx
  on public.site_membership_items(section_code, display_order);

create index if not exists site_membership_items_metadata_gin_idx
  on public.site_membership_items using gin(metadata);

drop trigger if exists trg_site_membership_items_updated_at on public.site_membership_items;
create trigger trg_site_membership_items_updated_at
before update on public.site_membership_items
for each row execute function public.set_updated_at();

alter table public.site_membership_items enable row level security;
alter table public.site_membership_items force row level security;

drop policy if exists "site_membership_items_public_read" on public.site_membership_items;
create policy "site_membership_items_public_read"
on public.site_membership_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_membership_items_admin_select" on public.site_membership_items;
create policy "site_membership_items_admin_select"
on public.site_membership_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_membership_items_admin_insert" on public.site_membership_items;
create policy "site_membership_items_admin_insert"
on public.site_membership_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_membership_items_admin_update" on public.site_membership_items;
create policy "site_membership_items_admin_update"
on public.site_membership_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_membership_items_admin_delete" on public.site_membership_items;
create policy "site_membership_items_admin_delete"
on public.site_membership_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_membership_items from public;
revoke all on table public.site_membership_items from anon, authenticated;
grant select on table public.site_membership_items to anon, authenticated;
grant insert, update, delete on table public.site_membership_items to authenticated;
grant all on table public.site_membership_items to service_role;

insert into public.site_membership_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('MEMBERSHIP', 'JOIN', 'Join the club', 'Access structured training, community support and club opportunities.',
 'Join today', 'membership.html#join', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Join the club',
 '{"category":"Join Today","position":1}'::jsonb, 1, true, now()),
('MEMBERSHIP', 'OPTIONS', 'Membership options', 'Choose the pathway that fits your age, role and goals.',
 'Compare options', 'membership.html#options', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Membership options',
 '{"category":"Join Today","position":2}'::jsonb, 2, true, now()),
('MEMBERSHIP', 'SUPPORT', 'Member support', 'Get help with registration, renewals and participation.',
 'Contact support', 'contact.html', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Member support',
 '{"category":"Join Today","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_membership_items is
  'Public CMS content for membership.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_membership_items
order by display_order;


-- ============================================================
-- RACE RESULTS PAGE — results.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_results_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'RESULTS',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_results_items_page_code_check check (page_code = 'RESULTS'),
  constraint site_results_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_results_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_results_items_section_order_uidx
  on public.site_results_items(section_code, display_order);

create unique index if not exists site_results_items_slug_uidx
  on public.site_results_items(slug)
  where slug is not null;

create index if not exists site_results_items_public_idx
  on public.site_results_items(is_active, publish_at desc, display_order);

create index if not exists site_results_items_section_idx
  on public.site_results_items(section_code, display_order);

create index if not exists site_results_items_metadata_gin_idx
  on public.site_results_items using gin(metadata);

drop trigger if exists trg_site_results_items_updated_at on public.site_results_items;
create trigger trg_site_results_items_updated_at
before update on public.site_results_items
for each row execute function public.set_updated_at();

alter table public.site_results_items enable row level security;
alter table public.site_results_items force row level security;

drop policy if exists "site_results_items_public_read" on public.site_results_items;
create policy "site_results_items_public_read"
on public.site_results_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_results_items_admin_select" on public.site_results_items;
create policy "site_results_items_admin_select"
on public.site_results_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_results_items_admin_insert" on public.site_results_items;
create policy "site_results_items_admin_insert"
on public.site_results_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_results_items_admin_update" on public.site_results_items;
create policy "site_results_items_admin_update"
on public.site_results_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_results_items_admin_delete" on public.site_results_items;
create policy "site_results_items_admin_delete"
on public.site_results_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_results_items from public;
revoke all on table public.site_results_items from anon, authenticated;
grant select on table public.site_results_items to anon, authenticated;
grant insert, update, delete on table public.site_results_items to authenticated;
grant all on table public.site_results_items to service_role;

insert into public.site_results_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('RESULTS', 'LATEST', 'Latest results', 'Review recent race placings, times and event details.',
 'View results', 'results.html#table', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Latest results',
 '{"category":"Race Results","position":1}'::jsonb, 1, true, now()),
('RESULTS', 'FILTERS', 'Find a result', 'Filter by season, discipline, event and team.',
 'Search results', 'results.html#filters', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Find a result',
 '{"category":"Race Results","position":2}'::jsonb, 2, true, now()),
('RESULTS', 'ARCHIVE', 'Results archive', 'Explore past seasons and key club achievements.',
 'Open archive', 'results.html#archive', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Results archive',
 '{"category":"Race Results","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_results_items is
  'Public CMS content for results.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_results_items
order by display_order;


-- ============================================================
-- RANKINGS PAGE — rankings.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_rankings_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'RANKINGS',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_rankings_items_page_code_check check (page_code = 'RANKINGS'),
  constraint site_rankings_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_rankings_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_rankings_items_section_order_uidx
  on public.site_rankings_items(section_code, display_order);

create unique index if not exists site_rankings_items_slug_uidx
  on public.site_rankings_items(slug)
  where slug is not null;

create index if not exists site_rankings_items_public_idx
  on public.site_rankings_items(is_active, publish_at desc, display_order);

create index if not exists site_rankings_items_section_idx
  on public.site_rankings_items(section_code, display_order);

create index if not exists site_rankings_items_metadata_gin_idx
  on public.site_rankings_items using gin(metadata);

drop trigger if exists trg_site_rankings_items_updated_at on public.site_rankings_items;
create trigger trg_site_rankings_items_updated_at
before update on public.site_rankings_items
for each row execute function public.set_updated_at();

alter table public.site_rankings_items enable row level security;
alter table public.site_rankings_items force row level security;

drop policy if exists "site_rankings_items_public_read" on public.site_rankings_items;
create policy "site_rankings_items_public_read"
on public.site_rankings_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_rankings_items_admin_select" on public.site_rankings_items;
create policy "site_rankings_items_admin_select"
on public.site_rankings_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_rankings_items_admin_insert" on public.site_rankings_items;
create policy "site_rankings_items_admin_insert"
on public.site_rankings_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_rankings_items_admin_update" on public.site_rankings_items;
create policy "site_rankings_items_admin_update"
on public.site_rankings_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_rankings_items_admin_delete" on public.site_rankings_items;
create policy "site_rankings_items_admin_delete"
on public.site_rankings_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_rankings_items from public;
revoke all on table public.site_rankings_items from anon, authenticated;
grant select on table public.site_rankings_items to anon, authenticated;
grant insert, update, delete on table public.site_rankings_items to authenticated;
grant all on table public.site_rankings_items to service_role;

insert into public.site_rankings_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('RANKINGS', 'TABLE', 'Current rankings', 'View athlete and team positions with ranking points.',
 'View standings', 'rankings.html#table', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Current rankings',
 '{"category":"Rankings","position":1}'::jsonb, 1, true, now()),
('RANKINGS', 'FILTERS', 'Ranking filters', 'Choose season, discipline, category and ranking type.',
 'Set filters', 'rankings.html#filters', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Ranking filters',
 '{"category":"Rankings","position":2}'::jsonb, 2, true, now()),
('RANKINGS', 'METHOD', 'How rankings work', 'Understand points, eligibility and update timing.',
 'Methodology', 'rankings.html#method', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'How rankings work',
 '{"category":"Rankings","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_rankings_items is
  'Public CMS content for rankings.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_rankings_items
order by display_order;


-- ============================================================
-- BENEFITS PAGE — benefits.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_benefits_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'BENEFITS',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_benefits_items_page_code_check check (page_code = 'BENEFITS'),
  constraint site_benefits_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_benefits_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_benefits_items_section_order_uidx
  on public.site_benefits_items(section_code, display_order);

create unique index if not exists site_benefits_items_slug_uidx
  on public.site_benefits_items(slug)
  where slug is not null;

create index if not exists site_benefits_items_public_idx
  on public.site_benefits_items(is_active, publish_at desc, display_order);

create index if not exists site_benefits_items_section_idx
  on public.site_benefits_items(section_code, display_order);

create index if not exists site_benefits_items_metadata_gin_idx
  on public.site_benefits_items using gin(metadata);

drop trigger if exists trg_site_benefits_items_updated_at on public.site_benefits_items;
create trigger trg_site_benefits_items_updated_at
before update on public.site_benefits_items
for each row execute function public.set_updated_at();

alter table public.site_benefits_items enable row level security;
alter table public.site_benefits_items force row level security;

drop policy if exists "site_benefits_items_public_read" on public.site_benefits_items;
create policy "site_benefits_items_public_read"
on public.site_benefits_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_benefits_items_admin_select" on public.site_benefits_items;
create policy "site_benefits_items_admin_select"
on public.site_benefits_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_benefits_items_admin_insert" on public.site_benefits_items;
create policy "site_benefits_items_admin_insert"
on public.site_benefits_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_benefits_items_admin_update" on public.site_benefits_items;
create policy "site_benefits_items_admin_update"
on public.site_benefits_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_benefits_items_admin_delete" on public.site_benefits_items;
create policy "site_benefits_items_admin_delete"
on public.site_benefits_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_benefits_items from public;
revoke all on table public.site_benefits_items from anon, authenticated;
grant select on table public.site_benefits_items to anon, authenticated;
grant insert, update, delete on table public.site_benefits_items to authenticated;
grant all on table public.site_benefits_items to service_role;

insert into public.site_benefits_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('BENEFITS', 'TRAINING', 'Structured training', 'Join planned sessions with inclusive coaching.',
 'Training benefits', 'benefits.html#training', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Structured training',
 '{"category":"Benefits","position":1}'::jsonb, 1, true, now()),
('BENEFITS', 'COMMUNITY', 'Club community', 'Build confidence and connection through shared rides.',
 'Community benefits', 'benefits.html#community', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Club community',
 '{"category":"Benefits","position":2}'::jsonb, 2, true, now()),
('BENEFITS', 'OPPORTUNITY', 'Competition opportunity', 'Access pathways into events and performance development.',
 'Performance pathway', 'team.html#pathway', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Competition opportunity',
 '{"category":"Benefits","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_benefits_items is
  'Public CMS content for benefits.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_benefits_items
order by display_order;


-- ============================================================
-- FIND A CLUB PAGE — clubs.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_clubs_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'CLUBS',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_clubs_items_page_code_check check (page_code = 'CLUBS'),
  constraint site_clubs_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_clubs_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_clubs_items_section_order_uidx
  on public.site_clubs_items(section_code, display_order);

create unique index if not exists site_clubs_items_slug_uidx
  on public.site_clubs_items(slug)
  where slug is not null;

create index if not exists site_clubs_items_public_idx
  on public.site_clubs_items(is_active, publish_at desc, display_order);

create index if not exists site_clubs_items_section_idx
  on public.site_clubs_items(section_code, display_order);

create index if not exists site_clubs_items_metadata_gin_idx
  on public.site_clubs_items using gin(metadata);

drop trigger if exists trg_site_clubs_items_updated_at on public.site_clubs_items;
create trigger trg_site_clubs_items_updated_at
before update on public.site_clubs_items
for each row execute function public.set_updated_at();

alter table public.site_clubs_items enable row level security;
alter table public.site_clubs_items force row level security;

drop policy if exists "site_clubs_items_public_read" on public.site_clubs_items;
create policy "site_clubs_items_public_read"
on public.site_clubs_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_clubs_items_admin_select" on public.site_clubs_items;
create policy "site_clubs_items_admin_select"
on public.site_clubs_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_clubs_items_admin_insert" on public.site_clubs_items;
create policy "site_clubs_items_admin_insert"
on public.site_clubs_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_clubs_items_admin_update" on public.site_clubs_items;
create policy "site_clubs_items_admin_update"
on public.site_clubs_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_clubs_items_admin_delete" on public.site_clubs_items;
create policy "site_clubs_items_admin_delete"
on public.site_clubs_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_clubs_items from public;
revoke all on table public.site_clubs_items from anon, authenticated;
grant select on table public.site_clubs_items to anon, authenticated;
grant insert, update, delete on table public.site_clubs_items to authenticated;
grant all on table public.site_clubs_items to service_role;

insert into public.site_clubs_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('CLUBS', 'FINDER', 'Club finder', 'Search by county, town and cycling focus.',
 'Find a club', 'clubs.html#finder', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Club finder',
 '{"category":"Find A Club","position":1}'::jsonb, 1, true, now()),
('CLUBS', 'AFFILIATION', 'Club standards', 'Understand inclusion, safeguarding and participation expectations.',
 'Club guidance', 'clubs.html#standards', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Club standards',
 '{"category":"Find A Club","position":2}'::jsonb, 2, true, now()),
('CLUBS', 'CONTACT', 'List your club', 'Partner organisations can request inclusion in the directory.',
 'Contact us', 'contact.html', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'List your club',
 '{"category":"Find A Club","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_clubs_items is
  'Public CMS content for clubs.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_clubs_items
order by display_order;


-- ============================================================
-- OFFICIALS PAGE — officials.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_officials_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'OFFICIALS',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_officials_items_page_code_check check (page_code = 'OFFICIALS'),
  constraint site_officials_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_officials_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_officials_items_section_order_uidx
  on public.site_officials_items(section_code, display_order);

create unique index if not exists site_officials_items_slug_uidx
  on public.site_officials_items(slug)
  where slug is not null;

create index if not exists site_officials_items_public_idx
  on public.site_officials_items(is_active, publish_at desc, display_order);

create index if not exists site_officials_items_section_idx
  on public.site_officials_items(section_code, display_order);

create index if not exists site_officials_items_metadata_gin_idx
  on public.site_officials_items using gin(metadata);

drop trigger if exists trg_site_officials_items_updated_at on public.site_officials_items;
create trigger trg_site_officials_items_updated_at
before update on public.site_officials_items
for each row execute function public.set_updated_at();

alter table public.site_officials_items enable row level security;
alter table public.site_officials_items force row level security;

drop policy if exists "site_officials_items_public_read" on public.site_officials_items;
create policy "site_officials_items_public_read"
on public.site_officials_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_officials_items_admin_select" on public.site_officials_items;
create policy "site_officials_items_admin_select"
on public.site_officials_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_officials_items_admin_insert" on public.site_officials_items;
create policy "site_officials_items_admin_insert"
on public.site_officials_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_officials_items_admin_update" on public.site_officials_items;
create policy "site_officials_items_admin_update"
on public.site_officials_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_officials_items_admin_delete" on public.site_officials_items;
create policy "site_officials_items_admin_delete"
on public.site_officials_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_officials_items from public;
revoke all on table public.site_officials_items from anon, authenticated;
grant select on table public.site_officials_items to anon, authenticated;
grant insert, update, delete on table public.site_officials_items to authenticated;
grant all on table public.site_officials_items to service_role;

insert into public.site_officials_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('OFFICIALS', 'ROLES', 'Official roles', 'Learn about commissaires, timekeepers, marshals and event support.',
 'Explore roles', 'officials.html#roles', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Official roles',
 '{"category":"Officials","position":1}'::jsonb, 1, true, now()),
('OFFICIALS', 'DEVELOPMENT', 'Development pathway', 'Build knowledge through mentoring and practical experience.',
 'Start pathway', 'officials.html#pathway', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Development pathway',
 '{"category":"Officials","position":2}'::jsonb, 2, true, now()),
('OFFICIALS', 'EVENTS', 'Support an event', 'Find opportunities to contribute to upcoming competitions.',
 'View events', 'events.html', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Support an event',
 '{"category":"Officials","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_officials_items is
  'Public CMS content for officials.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_officials_items
order by display_order;


-- ============================================================
-- CYCLOCROSS PAGE — cyclocross.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_cyclocross_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'CYCLOCROSS',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_cyclocross_items_page_code_check check (page_code = 'CYCLOCROSS'),
  constraint site_cyclocross_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_cyclocross_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_cyclocross_items_section_order_uidx
  on public.site_cyclocross_items(section_code, display_order);

create unique index if not exists site_cyclocross_items_slug_uidx
  on public.site_cyclocross_items(slug)
  where slug is not null;

create index if not exists site_cyclocross_items_public_idx
  on public.site_cyclocross_items(is_active, publish_at desc, display_order);

create index if not exists site_cyclocross_items_section_idx
  on public.site_cyclocross_items(section_code, display_order);

create index if not exists site_cyclocross_items_metadata_gin_idx
  on public.site_cyclocross_items using gin(metadata);

drop trigger if exists trg_site_cyclocross_items_updated_at on public.site_cyclocross_items;
create trigger trg_site_cyclocross_items_updated_at
before update on public.site_cyclocross_items
for each row execute function public.set_updated_at();

alter table public.site_cyclocross_items enable row level security;
alter table public.site_cyclocross_items force row level security;

drop policy if exists "site_cyclocross_items_public_read" on public.site_cyclocross_items;
create policy "site_cyclocross_items_public_read"
on public.site_cyclocross_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_cyclocross_items_admin_select" on public.site_cyclocross_items;
create policy "site_cyclocross_items_admin_select"
on public.site_cyclocross_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_cyclocross_items_admin_insert" on public.site_cyclocross_items;
create policy "site_cyclocross_items_admin_insert"
on public.site_cyclocross_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_cyclocross_items_admin_update" on public.site_cyclocross_items;
create policy "site_cyclocross_items_admin_update"
on public.site_cyclocross_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_cyclocross_items_admin_delete" on public.site_cyclocross_items;
create policy "site_cyclocross_items_admin_delete"
on public.site_cyclocross_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_cyclocross_items from public;
revoke all on table public.site_cyclocross_items from anon, authenticated;
grant select on table public.site_cyclocross_items to anon, authenticated;
grant insert, update, delete on table public.site_cyclocross_items to authenticated;
grant all on table public.site_cyclocross_items to service_role;

insert into public.site_cyclocross_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('CYCLOCROSS', 'DISCIPLINE', 'About cyclocross', 'Short, technical racing across grass, mud and obstacles.',
 'Learn more', 'cyclocross.html#discipline', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'About cyclocross',
 '{"category":"Cyclocross","position":1}'::jsonb, 1, true, now()),
('CYCLOCROSS', 'PREP', 'Prepare to ride', 'Build handling, pacing and equipment confidence.',
 'Preparation', 'cyclocross.html#prepare', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Prepare to ride',
 '{"category":"Cyclocross","position":2}'::jsonb, 2, true, now()),
('CYCLOCROSS', 'CALENDAR', 'Cyclocross events', 'See relevant club and national calendar entries.',
 'View events', 'events.html', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Cyclocross events',
 '{"category":"Cyclocross","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_cyclocross_items is
  'Public CMS content for cyclocross.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_cyclocross_items
order by display_order;


-- ============================================================
-- COMMUNITY RIDES PAGE — rides.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_rides_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'RIDES',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_rides_items_page_code_check check (page_code = 'RIDES'),
  constraint site_rides_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_rides_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_rides_items_section_order_uidx
  on public.site_rides_items(section_code, display_order);

create unique index if not exists site_rides_items_slug_uidx
  on public.site_rides_items(slug)
  where slug is not null;

create index if not exists site_rides_items_public_idx
  on public.site_rides_items(is_active, publish_at desc, display_order);

create index if not exists site_rides_items_section_idx
  on public.site_rides_items(section_code, display_order);

create index if not exists site_rides_items_metadata_gin_idx
  on public.site_rides_items using gin(metadata);

drop trigger if exists trg_site_rides_items_updated_at on public.site_rides_items;
create trigger trg_site_rides_items_updated_at
before update on public.site_rides_items
for each row execute function public.set_updated_at();

alter table public.site_rides_items enable row level security;
alter table public.site_rides_items force row level security;

drop policy if exists "site_rides_items_public_read" on public.site_rides_items;
create policy "site_rides_items_public_read"
on public.site_rides_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_rides_items_admin_select" on public.site_rides_items;
create policy "site_rides_items_admin_select"
on public.site_rides_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_rides_items_admin_insert" on public.site_rides_items;
create policy "site_rides_items_admin_insert"
on public.site_rides_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_rides_items_admin_update" on public.site_rides_items;
create policy "site_rides_items_admin_update"
on public.site_rides_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_rides_items_admin_delete" on public.site_rides_items;
create policy "site_rides_items_admin_delete"
on public.site_rides_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_rides_items from public;
revoke all on table public.site_rides_items from anon, authenticated;
grant select on table public.site_rides_items to anon, authenticated;
grant insert, update, delete on table public.site_rides_items to authenticated;
grant all on table public.site_rides_items to service_role;

insert into public.site_rides_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('RIDES', 'FINDER', 'Find a ride', 'Discover welcoming social and development rides.',
 'Ride calendar', 'rides.html#calendar', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Find a ride',
 '{"category":"Community Rides","position":1}'::jsonb, 1, true, now()),
('RIDES', 'EXPECT', 'What to expect', 'Clear pace, communication and support for each participant.',
 'Ride guide', 'rides.html#guide', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'What to expect',
 '{"category":"Community Rides","position":2}'::jsonb, 2, true, now()),
('RIDES', 'HOST', 'Help host a ride', 'Volunteer to support safe, inclusive community sessions.',
 'Volunteer', 'volunteer.html', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Help host a ride',
 '{"category":"Community Rides","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_rides_items is
  'Public CMS content for rides.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_rides_items
order by display_order;


-- ============================================================
-- COACHES PAGE — coaches.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_coaches_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'COACHES',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_coaches_items_page_code_check check (page_code = 'COACHES'),
  constraint site_coaches_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_coaches_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_coaches_items_section_order_uidx
  on public.site_coaches_items(section_code, display_order);

create unique index if not exists site_coaches_items_slug_uidx
  on public.site_coaches_items(slug)
  where slug is not null;

create index if not exists site_coaches_items_public_idx
  on public.site_coaches_items(is_active, publish_at desc, display_order);

create index if not exists site_coaches_items_section_idx
  on public.site_coaches_items(section_code, display_order);

create index if not exists site_coaches_items_metadata_gin_idx
  on public.site_coaches_items using gin(metadata);

drop trigger if exists trg_site_coaches_items_updated_at on public.site_coaches_items;
create trigger trg_site_coaches_items_updated_at
before update on public.site_coaches_items
for each row execute function public.set_updated_at();

alter table public.site_coaches_items enable row level security;
alter table public.site_coaches_items force row level security;

drop policy if exists "site_coaches_items_public_read" on public.site_coaches_items;
create policy "site_coaches_items_public_read"
on public.site_coaches_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_coaches_items_admin_select" on public.site_coaches_items;
create policy "site_coaches_items_admin_select"
on public.site_coaches_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_coaches_items_admin_insert" on public.site_coaches_items;
create policy "site_coaches_items_admin_insert"
on public.site_coaches_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_coaches_items_admin_update" on public.site_coaches_items;
create policy "site_coaches_items_admin_update"
on public.site_coaches_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_coaches_items_admin_delete" on public.site_coaches_items;
create policy "site_coaches_items_admin_delete"
on public.site_coaches_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_coaches_items from public;
revoke all on table public.site_coaches_items from anon, authenticated;
grant select on table public.site_coaches_items to anon, authenticated;
grant insert, update, delete on table public.site_coaches_items to authenticated;
grant all on table public.site_coaches_items to service_role;

insert into public.site_coaches_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('COACHES', 'DIRECTORY', 'Coach directory', 'Meet the coaches supporting Thika Tandem programmes.',
 'View coaches', 'coaches.html#directory', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Coach directory',
 '{"category":"Coaches","position":1}'::jsonb, 1, true, now()),
('COACHES', 'PATHWAY', 'Coach pathway', 'Develop inclusive practice through learning and mentoring.',
 'Start development', 'learning.html', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Coach pathway',
 '{"category":"Coaches","position":2}'::jsonb, 2, true, now()),
('COACHES', 'RESOURCES', 'Coach resources', 'Session planning, safety and communication guidance.',
 'Open resources', 'coaches.html#resources', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Coach resources',
 '{"category":"Coaches","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_coaches_items is
  'Public CMS content for coaches.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_coaches_items
order by display_order;


-- ============================================================
-- NATIONAL CHAMPIONSHIPS PAGE — championships.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_championships_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'CHAMPIONSHIPS',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_championships_items_page_code_check check (page_code = 'CHAMPIONSHIPS'),
  constraint site_championships_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_championships_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_championships_items_section_order_uidx
  on public.site_championships_items(section_code, display_order);

create unique index if not exists site_championships_items_slug_uidx
  on public.site_championships_items(slug)
  where slug is not null;

create index if not exists site_championships_items_public_idx
  on public.site_championships_items(is_active, publish_at desc, display_order);

create index if not exists site_championships_items_section_idx
  on public.site_championships_items(section_code, display_order);

create index if not exists site_championships_items_metadata_gin_idx
  on public.site_championships_items using gin(metadata);

drop trigger if exists trg_site_championships_items_updated_at on public.site_championships_items;
create trigger trg_site_championships_items_updated_at
before update on public.site_championships_items
for each row execute function public.set_updated_at();

alter table public.site_championships_items enable row level security;
alter table public.site_championships_items force row level security;

drop policy if exists "site_championships_items_public_read" on public.site_championships_items;
create policy "site_championships_items_public_read"
on public.site_championships_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_championships_items_admin_select" on public.site_championships_items;
create policy "site_championships_items_admin_select"
on public.site_championships_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_championships_items_admin_insert" on public.site_championships_items;
create policy "site_championships_items_admin_insert"
on public.site_championships_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_championships_items_admin_update" on public.site_championships_items;
create policy "site_championships_items_admin_update"
on public.site_championships_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_championships_items_admin_delete" on public.site_championships_items;
create policy "site_championships_items_admin_delete"
on public.site_championships_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_championships_items from public;
revoke all on table public.site_championships_items from anon, authenticated;
grant select on table public.site_championships_items to anon, authenticated;
grant insert, update, delete on table public.site_championships_items to authenticated;
grant all on table public.site_championships_items to service_role;

insert into public.site_championships_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('CHAMPIONSHIPS', 'OVERVIEW', 'Championship overview', 'Key dates, disciplines, eligibility and event information.',
 'Championship details', 'championships.html#overview', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Championship overview',
 '{"category":"National Championships","position":1}'::jsonb, 1, true, now()),
('CHAMPIONSHIPS', 'ENTRIES', 'Entries', 'Follow registration deadlines and entry requirements.',
 'Entry information', 'championships.html#entries', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Entries',
 '{"category":"National Championships","position":2}'::jsonb, 2, true, now()),
('CHAMPIONSHIPS', 'RESULTS', 'Championship results', 'Review placings and performances.',
 'View results', 'results.html', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Championship results',
 '{"category":"National Championships","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_championships_items is
  'Public CMS content for championships.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_championships_items
order by display_order;


-- ============================================================
-- RENEW MEMBERSHIP PAGE — renew.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_renew_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'RENEW',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_renew_items_page_code_check check (page_code = 'RENEW'),
  constraint site_renew_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_renew_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_renew_items_section_order_uidx
  on public.site_renew_items(section_code, display_order);

create unique index if not exists site_renew_items_slug_uidx
  on public.site_renew_items(slug)
  where slug is not null;

create index if not exists site_renew_items_public_idx
  on public.site_renew_items(is_active, publish_at desc, display_order);

create index if not exists site_renew_items_section_idx
  on public.site_renew_items(section_code, display_order);

create index if not exists site_renew_items_metadata_gin_idx
  on public.site_renew_items using gin(metadata);

drop trigger if exists trg_site_renew_items_updated_at on public.site_renew_items;
create trigger trg_site_renew_items_updated_at
before update on public.site_renew_items
for each row execute function public.set_updated_at();

alter table public.site_renew_items enable row level security;
alter table public.site_renew_items force row level security;

drop policy if exists "site_renew_items_public_read" on public.site_renew_items;
create policy "site_renew_items_public_read"
on public.site_renew_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_renew_items_admin_select" on public.site_renew_items;
create policy "site_renew_items_admin_select"
on public.site_renew_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_renew_items_admin_insert" on public.site_renew_items;
create policy "site_renew_items_admin_insert"
on public.site_renew_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_renew_items_admin_update" on public.site_renew_items;
create policy "site_renew_items_admin_update"
on public.site_renew_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_renew_items_admin_delete" on public.site_renew_items;
create policy "site_renew_items_admin_delete"
on public.site_renew_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_renew_items from public;
revoke all on table public.site_renew_items from anon, authenticated;
grant select on table public.site_renew_items to anon, authenticated;
grant insert, update, delete on table public.site_renew_items to authenticated;
grant all on table public.site_renew_items to service_role;

insert into public.site_renew_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('RENEW', 'RENEW', 'Renew membership', 'Keep your membership active without interrupting participation.',
 'Renew now', 'renew.html#form', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Renew membership',
 '{"category":"Renew Membership","position":1}'::jsonb, 1, true, now()),
('RENEW', 'CHECK', 'Check your details', 'Confirm contact, emergency and membership information.',
 'Review details', 'renew.html#details', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Check your details',
 '{"category":"Renew Membership","position":2}'::jsonb, 2, true, now()),
('RENEW', 'HELP', 'Renewal help', 'Get support if your status or payment needs attention.',
 'Contact support', 'contact.html', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Renewal help',
 '{"category":"Renew Membership","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_renew_items is
  'Public CMS content for renew.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_renew_items
order by display_order;


-- ============================================================
-- PARTNERS PAGE — partners.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_partners_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'PARTNERS',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_partners_items_page_code_check check (page_code = 'PARTNERS'),
  constraint site_partners_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_partners_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_partners_items_section_order_uidx
  on public.site_partners_items(section_code, display_order);

create unique index if not exists site_partners_items_slug_uidx
  on public.site_partners_items(slug)
  where slug is not null;

create index if not exists site_partners_items_public_idx
  on public.site_partners_items(is_active, publish_at desc, display_order);

create index if not exists site_partners_items_section_idx
  on public.site_partners_items(section_code, display_order);

create index if not exists site_partners_items_metadata_gin_idx
  on public.site_partners_items using gin(metadata);

drop trigger if exists trg_site_partners_items_updated_at on public.site_partners_items;
create trigger trg_site_partners_items_updated_at
before update on public.site_partners_items
for each row execute function public.set_updated_at();

alter table public.site_partners_items enable row level security;
alter table public.site_partners_items force row level security;

drop policy if exists "site_partners_items_public_read" on public.site_partners_items;
create policy "site_partners_items_public_read"
on public.site_partners_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_partners_items_admin_select" on public.site_partners_items;
create policy "site_partners_items_admin_select"
on public.site_partners_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_partners_items_admin_insert" on public.site_partners_items;
create policy "site_partners_items_admin_insert"
on public.site_partners_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_partners_items_admin_update" on public.site_partners_items;
create policy "site_partners_items_admin_update"
on public.site_partners_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_partners_items_admin_delete" on public.site_partners_items;
create policy "site_partners_items_admin_delete"
on public.site_partners_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_partners_items from public;
revoke all on table public.site_partners_items from anon, authenticated;
grant select on table public.site_partners_items to anon, authenticated;
grant insert, update, delete on table public.site_partners_items to authenticated;
grant all on table public.site_partners_items to service_role;

insert into public.site_partners_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('PARTNERS', 'CURRENT', 'Our partners', 'Meet organisations contributing equipment, expertise and opportunity.',
 'View partners', 'partners.html#current', '/assets/img/site/home/hero/home-hero-featured-01-1920x1200.webp', 'Our partners',
 '{"category":"Partners","position":1}'::jsonb, 1, true, now()),
('PARTNERS', 'BECOME', 'Become a partner', 'Create measurable impact through inclusive sport.',
 'Partner with us', 'partners.html#enquire', '/assets/img/site/home/story-grid/home-story-grid-large-01-1600x900.webp', 'Become a partner',
 '{"category":"Partners","position":2}'::jsonb, 2, true, now()),
('PARTNERS', 'IMPACT', 'Partnership impact', 'See how support reaches athletes and programmes.',
 'View impact', 'partners.html#impact', '/assets/img/site/home/story-grid/home-story-grid-small-02-1000x1000.webp', 'Partnership impact',
 '{"category":"Partners","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_partners_items is
  'Public CMS content for partners.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_partners_items
order by display_order;


-- ============================================================
-- ROAD TEAMS PAGE — teams.html
-- Standalone, idempotent Supabase/PostgreSQL migration
-- ============================================================

begin;

create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger
language plpgsql
security invoker
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create or replace function public.is_site_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.profiles p
    join public.user_role_master r on r.user_role_id = p.user_role_id
    where (p.auth_user_id = auth.uid() or p.profile_id = auth.uid())
      and upper(r.role_code) in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN','EDITOR')
      and coalesce(p.account_status, 'ACTIVE') = 'ACTIVE'
  );
$$;

revoke all on function public.is_site_admin() from public;
grant execute on function public.is_site_admin() to anon, authenticated, service_role;

create table if not exists public.site_teams_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(50) not null default 'TEAMS',
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(260),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text,
  image_url text,
  image_alt varchar(300),
  metadata jsonb not null default '{}'::jsonb,
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_teams_items_page_code_check check (page_code = 'TEAMS'),
  constraint site_teams_items_url_check check (
    button_url is null or button_url !~* '^\s*(javascript|data):'
  ),
  constraint site_teams_items_publish_window_check check (
    expire_at is null or expire_at > publish_at
  )
);

create unique index if not exists site_teams_items_section_order_uidx
  on public.site_teams_items(section_code, display_order);

create unique index if not exists site_teams_items_slug_uidx
  on public.site_teams_items(slug)
  where slug is not null;

create index if not exists site_teams_items_public_idx
  on public.site_teams_items(is_active, publish_at desc, display_order);

create index if not exists site_teams_items_section_idx
  on public.site_teams_items(section_code, display_order);

create index if not exists site_teams_items_metadata_gin_idx
  on public.site_teams_items using gin(metadata);

drop trigger if exists trg_site_teams_items_updated_at on public.site_teams_items;
create trigger trg_site_teams_items_updated_at
before update on public.site_teams_items
for each row execute function public.set_updated_at();

alter table public.site_teams_items enable row level security;
alter table public.site_teams_items force row level security;

drop policy if exists "site_teams_items_public_read" on public.site_teams_items;
create policy "site_teams_items_public_read"
on public.site_teams_items
for select
to anon, authenticated
using (
  is_active = true
  and publish_at <= now()
  and (expire_at is null or expire_at > now())
);

drop policy if exists "site_teams_items_admin_select" on public.site_teams_items;
create policy "site_teams_items_admin_select"
on public.site_teams_items
for select
to authenticated
using (public.is_site_admin());

drop policy if exists "site_teams_items_admin_insert" on public.site_teams_items;
create policy "site_teams_items_admin_insert"
on public.site_teams_items
for insert
to authenticated
with check (public.is_site_admin());

drop policy if exists "site_teams_items_admin_update" on public.site_teams_items;
create policy "site_teams_items_admin_update"
on public.site_teams_items
for update
to authenticated
using (public.is_site_admin())
with check (public.is_site_admin());

drop policy if exists "site_teams_items_admin_delete" on public.site_teams_items;
create policy "site_teams_items_admin_delete"
on public.site_teams_items
for delete
to authenticated
using (public.is_site_admin());

revoke all on table public.site_teams_items from public;
revoke all on table public.site_teams_items from anon, authenticated;
grant select on table public.site_teams_items to anon, authenticated;
grant insert, update, delete on table public.site_teams_items to authenticated;
grant all on table public.site_teams_items to service_role;

insert into public.site_teams_items
(page_code, section_code, title, summary, button_text, button_url,
 image_url, image_alt, metadata, display_order, is_active, publish_at)
values
('TEAMS', 'SQUADS', 'Road teams', 'Meet competitive tandem pairings and development squads.',
 'View teams', 'teams.html#squads', '/assets/img/site/teams/team-portrait-01-1200x1600.webp', 'Road teams',
 '{"category":"Road Teams","position":1}'::jsonb, 1, true, now()),
('TEAMS', 'SELECTION', 'Team selection', 'Understand readiness, pairing and competition considerations.',
 'Selection guide', 'teams.html#selection', '/assets/img/site/teams/team-portrait-02-1200x1600.webp', 'Team selection',
 '{"category":"Road Teams","position":2}'::jsonb, 2, true, now()),
('TEAMS', 'RESULTS', 'Team results', 'Follow recent road performances.',
 'View results', 'results.html', '/assets/img/site/teams/team-portrait-03-1200x1600.webp', 'Team results',
 '{"category":"Road Teams","position":3}'::jsonb, 3, true, now())
on conflict (section_code, display_order) do update set
  title = excluded.title,
  summary = excluded.summary,
  button_text = excluded.button_text,
  button_url = excluded.button_url,
  image_url = excluded.image_url,
  image_alt = excluded.image_alt,
  metadata = excluded.metadata,
  is_active = excluded.is_active,
  updated_at = now();

comment on table public.site_teams_items is
  'Public CMS content for teams.html. Public reads are restricted to active published rows; writes require an approved site administrator role.';

commit;

-- Verification
select section_code, title, button_url, image_url, display_order, is_active
from public.site_teams_items
order by display_order;
