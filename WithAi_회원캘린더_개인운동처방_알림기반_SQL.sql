-- WithAi calendar and trainer-prescribed personal workouts
-- Additive migration. Does not alter existing login, snapshots, lesson records, or member data.

create table if not exists public.withai_app_appointments (
  id uuid primary key default gen_random_uuid(),
  app_member_id text not null references public.withai_app_member_assignments(app_member_id) on delete cascade,
  event_type text not null default 'lesson' check (event_type in ('lesson','personal')),
  title text not null default 'PT 레슨',
  starts_at timestamptz not null,
  duration_minutes integer not null default 50 check (duration_minutes between 5 and 240),
  status text not null default 'scheduled' check (status in ('scheduled','completed','cancelled','no_show')),
  note text,
  trainer_user_id uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.withai_app_personal_workouts (
  id uuid primary key default gen_random_uuid(),
  app_member_id text not null references public.withai_app_member_assignments(app_member_id) on delete cascade,
  scheduled_date date not null,
  title text not null default '개인 운동 프로그램',
  focus text,
  exercises jsonb not null default '[]'::jsonb,
  coach_note text,
  status text not null default 'assigned' check (status in ('assigned','completed','cancelled')),
  trainer_user_id uuid references auth.users(id) on delete set null,
  created_by uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.withai_app_appointments enable row level security;
alter table public.withai_app_personal_workouts enable row level security;

drop policy if exists withai_app_appointments_staff_all on public.withai_app_appointments;
create policy withai_app_appointments_staff_all on public.withai_app_appointments
for all to authenticated
using (
  public.current_app_role() = 'admin'
  or exists (select 1 from public.withai_app_member_assignments a
    where a.app_member_id = withai_app_appointments.app_member_id and a.trainer_user_id = auth.uid())
)
with check (
  (created_by is null or created_by = auth.uid())
  and (
    public.current_app_role() = 'admin'
    or exists (select 1 from public.withai_app_member_assignments a
      where a.app_member_id = withai_app_appointments.app_member_id and a.trainer_user_id = auth.uid())
  )
);

drop policy if exists withai_app_personal_workouts_staff_all on public.withai_app_personal_workouts;
create policy withai_app_personal_workouts_staff_all on public.withai_app_personal_workouts
for all to authenticated
using (
  public.current_app_role() = 'admin'
  or exists (select 1 from public.withai_app_member_assignments a
    where a.app_member_id = withai_app_personal_workouts.app_member_id and a.trainer_user_id = auth.uid())
)
with check (
  (created_by is null or created_by = auth.uid())
  and (
    public.current_app_role() = 'admin'
    or exists (select 1 from public.withai_app_member_assignments a
      where a.app_member_id = withai_app_personal_workouts.app_member_id and a.trainer_user_id = auth.uid())
  )
);

grant select, insert, update, delete on public.withai_app_appointments to authenticated;
grant select, insert, update, delete on public.withai_app_personal_workouts to authenticated;

create index if not exists withai_app_appointments_member_start_idx
  on public.withai_app_appointments(app_member_id, starts_at);
create index if not exists withai_app_personal_workouts_member_date_idx
  on public.withai_app_personal_workouts(app_member_id, scheduled_date desc);

create or replace function public.withai_member_get_calendar(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_app_member_id text;
  v_appointments jsonb;
  v_workouts jsonb;
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

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', a.id, 'event_type', a.event_type, 'title', a.title,
    'starts_at', a.starts_at, 'duration_minutes', a.duration_minutes,
    'status', a.status, 'note', a.note
  ) order by a.starts_at), '[]'::jsonb)
  into v_appointments
  from public.withai_app_appointments a
  where a.app_member_id = v_app_member_id and a.status <> 'cancelled';

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', w.id, 'scheduled_date', w.scheduled_date, 'title', w.title,
    'focus', w.focus, 'exercises', w.exercises, 'coach_note', w.coach_note,
    'status', w.status
  ) order by w.scheduled_date desc), '[]'::jsonb)
  into v_workouts
  from public.withai_app_personal_workouts w
  where w.app_member_id = v_app_member_id and w.status <> 'cancelled';

  return jsonb_build_object('ok', true, 'appointments', v_appointments, 'personal_workouts', v_workouts);
end;
$$;

revoke all on function public.withai_member_get_calendar(text) from public;
grant execute on function public.withai_member_get_calendar(text) to anon, authenticated;
