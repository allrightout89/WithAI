-- WithAi member lesson-history sharing (additive migration)
-- Members can read only lesson rows belonging to the member linked to their valid portal token.
-- Existing member portal RPC and snapshot data are not modified.

create or replace function public.withai_member_get_training_sessions(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_app_member_id text;
  v_member_id uuid;
  v_sessions jsonb;
begin
  if p_token is null or length(trim(p_token)) < 10 then
    return jsonb_build_object('ok', false, 'message', '회원 로그인 정보가 유효하지 않습니다.');
  end if;

  select t.member_id
    into v_app_member_id
  from public.withai_member_portal_tokens t
  where t.token = p_token
    and t.expires_at > now()
  limit 1;

  if v_app_member_id is null then
    return jsonb_build_object('ok', false, 'message', '회원 로그인 정보가 만료되었습니다.');
  end if;

  select l.member_id
    into v_member_id
  from public.withai_member_app_links l
  where l.app_member_id = v_app_member_id
  limit 1;

  if v_member_id is null then
    return jsonb_build_object('ok', true, 'sessions', '[]'::jsonb);
  end if;

  select coalesce(
    jsonb_agg(
      jsonb_build_object(
        'id', s.id,
        'session_date', s.session_date,
        'session_number', s.session_number,
        'training_part', s.training_part,
        'goal', s.goal,
        'exercises', s.exercises,
        'rpe', s.rpe,
        'condition', s.condition,
        'coaching_note', s.coaching_note,
        'video_url', s.video_url
      )
      order by s.session_date desc, s.session_number desc
    ),
    '[]'::jsonb
  )
  into v_sessions
  from public.training_sessions s
  where s.member_id = v_member_id;

  return jsonb_build_object('ok', true, 'sessions', v_sessions);
end;
$$;

revoke all on function public.withai_member_get_training_sessions(text) from public;
grant execute on function public.withai_member_get_training_sessions(text) to anon, authenticated;
