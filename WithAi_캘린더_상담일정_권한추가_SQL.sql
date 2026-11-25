-- WithAi calendar consultation-event extension
-- Run once in Supabase SQL Editor after the base calendar migration.
-- Existing PT and personal-workout records are preserved.

alter table public.withai_app_appointments
  drop constraint if exists withai_app_appointments_event_type_check;

alter table public.withai_app_appointments
  add constraint withai_app_appointments_event_type_check
  check (event_type in ('lesson','personal','consultation'));

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
  v_measurements jsonb;
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
  where a.app_member_id = v_app_member_id and a.status <> 'cancelled' and a.event_type in ('lesson','personal');

  select coalesce(jsonb_agg(jsonb_build_object(
    'id', w.id, 'scheduled_date', w.scheduled_date, 'scheduled_time', w.scheduled_time, 'title', w.title,
    'focus', w.focus, 'exercises', w.exercises, 'coach_note', w.coach_note,
    'status', w.status
  ) order by w.scheduled_date desc), '[]'::jsonb)
  into v_workouts
  from public.withai_app_personal_workouts w
  where w.app_member_id = v_app_member_id and w.status <> 'cancelled';

  select coalesce(jsonb_agg(jsonb_build_object(
    'measured_on', m.measured_on, 'weight_kg', m.weight_kg,
    'body_fat_percent', m.body_fat_percent, 'muscle_kg', m.muscle_kg, 'waist_cm', m.waist_cm
  ) order by m.measured_on), '[]'::jsonb)
  into v_measurements
  from public.withai_app_body_measurements m
  where m.app_member_id = v_app_member_id;

  return jsonb_build_object('ok', true, 'appointments', v_appointments, 'personal_workouts', v_workouts, 'measurements', v_measurements);
end;
$$;

revoke all on function public.withai_member_get_calendar(text) from public;
grant execute on function public.withai_member_get_calendar(text) to anon, authenticated;
