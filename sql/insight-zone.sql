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
