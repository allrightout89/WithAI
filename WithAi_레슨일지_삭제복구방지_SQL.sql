-- WithAi: prevent deleted legacy lesson logs from being re-imported.
-- Run this once in Supabase SQL Editor after the app code update.
alter table public.withai_app_training_sessions
  add column if not exists deleted_at timestamptz;

-- Member portal must never return soft-deleted lesson logs.
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
  where s.app_member_id = v_app_member_id
    and s.deleted_at is null;

  return jsonb_build_object('ok', true, 'sessions', v_sessions);
end;
$$;

revoke all on function public.withai_member_get_training_sessions(text) from public;
grant execute on function public.withai_member_get_training_sessions(text) to anon, authenticated;
