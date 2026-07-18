-- THIKA TANDEM: website content tables for the four page codes not already present.
-- site_mtb_items already exists in the supplied schema, so this script does not recreate it.
-- Designed for Supabase/PostgreSQL. Safe to rerun.

begin;
create extension if not exists pgcrypto;

create or replace function public.set_updated_at()
returns trigger language plpgsql security invoker set search_path = public as $$
begin new.updated_at = now(); return new; end; $$;

-- A shared, normalized content table avoids four near-identical tables.
create table if not exists public.site_page_items (
  item_id uuid primary key default gen_random_uuid(),
  page_code varchar(40) not null check (page_code in ('RENEW','VOLUNTEER','ATHLETES','SUPPORT')),
  section_code varchar(80) not null,
  eyebrow varchar(160),
  title varchar(240) not null,
  slug varchar(180),
  summary text,
  body_html text,
  button_text varchar(120),
  button_url text check (button_url is null or button_url !~* '^\s*(javascript|data):'),
  image_url text,
  image_alt varchar(240),
  metadata jsonb not null default '{}'::jsonb check (jsonb_typeof(metadata) = 'object'),
  display_order integer not null default 0 check (display_order >= 0),
  is_featured boolean not null default false,
  is_active boolean not null default true,
  publish_at timestamptz not null default now(),
  expire_at timestamptz,
  created_by uuid references auth.users(id) on delete set null,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint site_page_items_publish_window_ck check (expire_at is null or expire_at > publish_at),
  constraint site_page_items_page_section_slug_uq unique nulls not distinct (page_code, section_code, slug)
);

create index if not exists site_page_items_public_lookup_idx on public.site_page_items(page_code, section_code, display_order, publish_at) where is_active;
create index if not exists site_page_items_page_featured_idx on public.site_page_items(page_code, is_featured, display_order) where is_active;
create index if not exists site_page_items_metadata_gin_idx on public.site_page_items using gin(metadata);
create index if not exists site_page_items_created_by_idx on public.site_page_items(created_by);
create index if not exists site_page_items_updated_by_idx on public.site_page_items(updated_by);

drop trigger if exists trg_site_page_items_updated_at on public.site_page_items;
create trigger trg_site_page_items_updated_at before update on public.site_page_items for each row execute function public.set_updated_at();

alter table public.site_page_items enable row level security;
alter table public.site_page_items force row level security;

drop policy if exists "Public can read published site page items" on public.site_page_items;
create policy "Public can read published site page items" on public.site_page_items for select to anon, authenticated
using (is_active and publish_at <= now() and (expire_at is null or expire_at > now()));

drop policy if exists "Admins manage site page items" on public.site_page_items;
create policy "Admins manage site page items" on public.site_page_items for all to authenticated
using (exists (select 1 from public.profiles p join public.user_role_master r on r.user_role_id=p.user_role_id where p.auth_user_id=auth.uid() and r.role_code in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN')))
with check (exists (select 1 from public.profiles p join public.user_role_master r on r.user_role_id=p.user_role_id where p.auth_user_id=auth.uid() and r.role_code in ('ADMIN','SUPER_ADMIN','CONTENT_ADMIN')));

revoke all on table public.site_page_items from public;
grant select on table public.site_page_items to anon, authenticated;
grant insert, update, delete on table public.site_page_items to authenticated;
grant all on table public.site_page_items to service_role;

comment on table public.site_page_items is 'Published website content for Renew, Volunteer, Athletes and Support pages.';
comment on column public.site_page_items.body_html is 'Trusted editorial HTML. Sanitize before rendering.';

commit;
