-- WithAi: use existing app member IDs for trainer assignment and lesson sharing.
-- Additive only: does not alter members, training_sessions, login, or snapshot tables.

create table if not exists public.withai_app_member_assignments (
  app_member_id text primary key,
  member_name text not null,
  member_phone text,
  member_goal text,
  trainer_user_id uuid references auth.users(id) on delete set null,
  assigned_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.withai_app_member_assignments enable row level security;

drop policy if exists withai_app_member_assignments_select on public.withai_app_member_assignments;
create policy withai_app_member_assignments_select
on public.withai_app_member_assignments for select to authenticated
using (public.current_app_role() = 'admin' or trainer_user_id = auth.uid());

drop policy if exists withai_app_member_assignments_admin_write on public.withai_app_member_assignments;
create policy withai_app_member_assignments_admin_write
on public.withai_app_member_assignments for all to authenticated
using (public.current_app_role() = 'admin')
with check (public.current_app_role() = 'admin');

grant select, insert, update, delete on public.withai_app_member_assignments to authenticated;
create index if not exists withai_app_member_assignments_trainer_idx on public.withai_app_member_assignments(trainer_user_id);

create table if not exists public.withai_app_training_sessions (
  id uuid primary key default gen_random_uuid(),
  app_member_id text not null references public.withai_app_member_assignments(app_member_id) on delete cascade,
  legacy_session_id text,
  session_date date,
  session_number integer,
  training_part text,
  goal text,
  exercises jsonb not null default '[]'::jsonb,
  rpe numeric,
  condition text,
  good text,
  coaching_note text,
  next_goal text,
  video_url text,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  constraint withai_app_training_sessions_legacy_unique unique (app_member_id, legacy_session_id)
);

alter table public.withai_app_training_sessions enable row level security;

drop policy if exists withai_app_training_sessions_select on public.withai_app_training_sessions;
create policy withai_app_training_sessions_select
on public.withai_app_training_sessions for select to authenticated
using (
  public.current_app_role() = 'admin'
  or exists (
    select 1 from public.withai_app_member_assignments a
    where a.app_member_id = withai_app_training_sessions.app_member_id
      and a.trainer_user_id = auth.uid()
  )
);

drop policy if exists withai_app_training_sessions_insert on public.withai_app_training_sessions;
create policy withai_app_training_sessions_insert
on public.withai_app_training_sessions for insert to authenticated
with check (
  (created_by is null or created_by = auth.uid())
  and (
    public.current_app_role() = 'admin'
    or exists (
      select 1 from public.withai_app_member_assignments a
      where a.app_member_id = withai_app_training_sessions.app_member_id
        and a.trainer_user_id = auth.uid()
    )
  )
);

drop policy if exists withai_app_training_sessions_update on public.withai_app_training_sessions;
create policy withai_app_training_sessions_update
on public.withai_app_training_sessions for update to authenticated
using (
  public.current_app_role() = 'admin'
  or exists (
    select 1 from public.withai_app_member_assignments a
    where a.app_member_id = withai_app_training_sessions.app_member_id
      and a.trainer_user_id = auth.uid()
  )
)
with check (
  (created_by is null or created_by = auth.uid())
  and (
    public.current_app_role() = 'admin'
    or exists (
      select 1 from public.withai_app_member_assignments a
      where a.app_member_id = withai_app_training_sessions.app_member_id
        and a.trainer_user_id = auth.uid()
    )
  )
);

drop policy if exists withai_app_training_sessions_delete on public.withai_app_training_sessions;
create policy withai_app_training_sessions_delete
on public.withai_app_training_sessions for delete to authenticated
using (
  public.current_app_role() = 'admin'
  or exists (
    select 1 from public.withai_app_member_assignments a
    where a.app_member_id = withai_app_training_sessions.app_member_id
      and a.trainer_user_id = auth.uid()
  )
);

grant select, insert, update, delete on public.withai_app_training_sessions to authenticated;
create index if not exists withai_app_training_sessions_member_date_idx on public.withai_app_training_sessions(app_member_id, session_date desc);

create table if not exists public.withai_app_consultations (
  app_member_id text primary key references public.withai_app_member_assignments(app_member_id) on delete cascade,
  consultation jsonb not null default '{}'::jsonb,
  updated_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.withai_app_consultations enable row level security;

drop policy if exists withai_app_consultations_select on public.withai_app_consultations;
create policy withai_app_consultations_select
on public.withai_app_consultations for select to authenticated
using (
  public.current_app_role() = 'admin'
  or exists (
    select 1 from public.withai_app_member_assignments a
    where a.app_member_id = withai_app_consultations.app_member_id
      and a.trainer_user_id = auth.uid()
  )
);

drop policy if exists withai_app_consultations_insert on public.withai_app_consultations;
create policy withai_app_consultations_insert
on public.withai_app_consultations for insert to authenticated
with check (
  (updated_by is null or updated_by = auth.uid())
  and (
    public.current_app_role() = 'admin'
    or exists (
      select 1 from public.withai_app_member_assignments a
      where a.app_member_id = withai_app_consultations.app_member_id
        and a.trainer_user_id = auth.uid()
    )
  )
);

drop policy if exists withai_app_consultations_update on public.withai_app_consultations;
create policy withai_app_consultations_update
on public.withai_app_consultations for update to authenticated
using (
  public.current_app_role() = 'admin'
  or exists (
    select 1 from public.withai_app_member_assignments a
    where a.app_member_id = withai_app_consultations.app_member_id
      and a.trainer_user_id = auth.uid()
  )
)
with check (
  (updated_by is null or updated_by = auth.uid())
  and (
    public.current_app_role() = 'admin'
    or exists (
      select 1 from public.withai_app_member_assignments a
      where a.app_member_id = withai_app_consultations.app_member_id
        and a.trainer_user_id = auth.uid()
    )
  )
);

grant select, insert, update on public.withai_app_consultations to authenticated;

-- Member portal: resolve the existing phone-last4 login token to its original app member ID.
create or replace function public.withai_member_get_training_sessions(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_app_member_id text;
  v_sessions jsonb;
begin
  if p_token is null or length(trim(p_token)) < 10 then
    return jsonb_build_object('ok', false, 'message', '회원 로그인 정보가 유효하지 않습니다.');
  end if;

  select t.member_id into v_app_member_id
  from public.withai_member_portal_tokens t
  where t.token = p_token and t.expires_at > now()
  limit 1;

  if v_app_member_id is null then
    return jsonb_build_object('ok', false, 'message', '회원 로그인 정보가 만료되었습니다.');
  end if;

  select coalesce(jsonb_agg(
    jsonb_build_object(
      'id', s.id,
      'session_date', s.session_date,
      'session_number', s.session_number,
      'training_part', s.training_part,
      'goal', s.goal,
      'exercises', s.exercises,
      'rpe', s.rpe,
      'condition', s.condition,
      'good', s.good,
      'coaching_note', s.coaching_note,
      'next_goal', s.next_goal,
      'video_url', s.video_url
    ) order by s.session_date desc nulls last, s.session_number desc nulls last, s.created_at desc
  ), '[]'::jsonb)
  into v_sessions
  from public.withai_app_training_sessions s
  where s.app_member_id = v_app_member_id;

  return jsonb_build_object('ok', true, 'sessions', v_sessions);
end;
$$;

revoke all on function public.withai_member_get_training_sessions(text) from public;
grant execute on function public.withai_member_get_training_sessions(text) to anon, authenticated;

create or replace function public.withai_member_get_consultation(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_app_member_id text;
  v_consultation jsonb;
begin
  if p_token is null or length(trim(p_token)) < 10 then
    return jsonb_build_object('ok', false, 'message', '회원 로그인 정보가 유효하지 않습니다.');
  end if;

  select t.member_id into v_app_member_id
  from public.withai_member_portal_tokens t
  where t.token = p_token and t.expires_at > now()
  limit 1;

  if v_app_member_id is null then
    return jsonb_build_object('ok', false, 'message', '회원 로그인 정보가 만료되었습니다.');
  end if;

  select c.consultation into v_consultation
  from public.withai_app_consultations c
  where c.app_member_id = v_app_member_id
  limit 1;

  return jsonb_build_object('ok', true, 'consultation', v_consultation);
end;
$$;

revoke all on function public.withai_member_get_consultation(text) from public;
grant execute on function public.withai_member_get_consultation(text) to anon, authenticated;
