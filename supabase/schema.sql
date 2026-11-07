-- XOLLORO OS initial database schema
-- Run in Supabase SQL Editor after replacing ADMIN_EMAIL with the owner's verified email.
create table if not exists public.admin_allowlist (
  email text primary key,
  created_at timestamptz not null default now()
);
insert into public.admin_allowlist(email) values (lower('kdqqdud@gmail.com'))
on conflict (email) do nothing;

create or replace function public.is_xolloro_admin()
returns boolean language sql stable security definer set search_path = public
as $$
  select exists (
    select 1 from public.admin_allowlist
    where email = lower(coalesce(auth.jwt()->>'email',''))
  );
$$;

create table if not exists public.leads (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  email text,
  phone text,
  message text,
  consent boolean not null default false,
  created_at timestamptz not null default now()
);
create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  customer_name text not null,
  customer_email text,
  customer_phone text,
  service text not null,
  details text,
  status text not null default 'new',
  created_at timestamptz not null default now()
);
create table if not exists public.analytics_events (
  id bigint generated always as identity primary key,
  event_name text not null,
  page_path text,
  referrer text,
  device_type text,
  country text,
  city text,
  created_at timestamptz not null default now()
);
create table if not exists public.site_content (
  content_key text primary key,
  content_value jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

alter table public.admin_allowlist enable row level security;
alter table public.leads enable row level security;
alter table public.orders enable row level security;
alter table public.analytics_events enable row level security;
alter table public.site_content enable row level security;

drop policy if exists "admin allowlist read" on public.admin_allowlist;
create policy "admin allowlist read" on public.admin_allowlist for select to authenticated using (public.is_xolloro_admin());
drop policy if exists "admin leads all" on public.leads;
create policy "admin leads all" on public.leads for all to authenticated using (public.is_xolloro_admin()) with check (public.is_xolloro_admin());
drop policy if exists "admin orders all" on public.orders;
create policy "admin orders all" on public.orders for all to authenticated using (public.is_xolloro_admin()) with check (public.is_xolloro_admin());
drop policy if exists "admin events read" on public.analytics_events;
create policy "admin events read" on public.analytics_events for select to authenticated using (public.is_xolloro_admin());
drop policy if exists "admin content all" on public.site_content;
create policy "admin content all" on public.site_content for all to authenticated using (public.is_xolloro_admin()) with check (public.is_xolloro_admin());

-- Public lead submission: allow insert only; never public read.
drop policy if exists "public submit leads" on public.leads;
create policy "public submit leads" on public.leads for insert to anon, authenticated with check (consent = true);
-- Public analytics event collection may insert events, but cannot read them.
drop policy if exists "public insert analytics events" on public.analytics_events;
create policy "public insert analytics events" on public.analytics_events for insert to anon, authenticated with check (length(event_name) between 1 and 80);

-- IMPORTANT: orders and site_content remain admin-only. Do not add public SELECT policies.
