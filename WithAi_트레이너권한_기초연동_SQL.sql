-- WithAi trainer access foundation (additive migration)
-- Run in Supabase SQL Editor. Does not modify existing member login or snapshot data.

-- Link the existing browser-app member IDs (for example: m123...) to
-- normalized Supabase members UUIDs. Admins perform this mapping.
create table if not exists public.withai_member_app_links (
  app_member_id text primary key,
  member_id uuid not null unique references public.members(id) on delete cascade,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now()
);

alter table public.withai_member_app_links enable row level security;

drop policy if exists withai_member_app_links_admin_all on public.withai_member_app_links;
create policy withai_member_app_links_admin_all
on public.withai_member_app_links
for all
to authenticated
using (public.current_app_role() = 'admin')
with check (public.current_app_role() = 'admin');

grant select, insert, update, delete on public.withai_member_app_links to authenticated;

-- Store initial consultation separately from the admin-only whole-app snapshot.
-- This permits a member to read their own consultation and their assigned
-- trainer/admin to create or update it without exposing other members.
create table if not exists public.withai_consultations (
  member_id uuid primary key references public.members(id) on delete cascade,
  consultation jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.withai_consultations enable row level security;

drop policy if exists withai_consultations_select on public.withai_consultations;
create policy withai_consultations_select
on public.withai_consultations
for select
to authenticated
using (public.can_access_member(member_id));

drop policy if exists withai_consultations_insert on public.withai_consultations;
create policy withai_consultations_insert
on public.withai_consultations
for insert
to authenticated
with check (
  public.can_manage_member(member_id)
  and (updated_by is null or updated_by = auth.uid())
);

drop policy if exists withai_consultations_update on public.withai_consultations;
create policy withai_consultations_update
on public.withai_consultations
for update
to authenticated
using (public.can_manage_member(member_id))
with check (
  public.can_manage_member(member_id)
  and (updated_by is null or updated_by = auth.uid())
);

grant select, insert, update on public.withai_consultations to authenticated;

-- Keep updated_at current when consultation content changes.
create or replace function public.withai_touch_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists withai_consultations_touch_updated_at on public.withai_consultations;
create trigger withai_consultations_touch_updated_at
before update on public.withai_consultations
for each row execute function public.withai_touch_updated_at();
