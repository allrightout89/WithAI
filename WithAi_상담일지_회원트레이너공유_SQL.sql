-- WithAi consultation sharing bridge (additive)
-- Allows a phone-last4 member portal token to read only its own mapped consultation.
-- Does not change existing login, member snapshots, or existing RPC functions.

create or replace function public.withai_member_get_consultation(p_token text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_app_member_id text;
  v_member_id uuid;
  v_consultation jsonb;
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
    return jsonb_build_object('ok', true, 'consultation', null);
  end if;

  select c.consultation
    into v_consultation
  from public.withai_consultations c
  where c.member_id = v_member_id
  limit 1;

  return jsonb_build_object('ok', true, 'consultation', v_consultation);
end;
$$;

revoke all on function public.withai_member_get_consultation(text) from public;
grant execute on function public.withai_member_get_consultation(text) to anon, authenticated;
