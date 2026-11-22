-- WithAi 회원 로그인 복구: 이름 + 휴대폰 뒷자리 4자리
-- 기존 회원 데이터/식단/운동기록/레슨기록은 수정하거나 삭제하지 않습니다.
-- Supabase SQL Editor에서 1회 실행하세요.

create or replace function public.withai_member_enter_by_name_last4(p_name text, p_last4 text)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_owner uuid;
  v_data jsonb;
  v_member jsonb;
  v_count integer;
  v_token text;
  v_member_id text;
begin
  if p_name is null or length(trim(p_name)) < 1 or length(trim(p_name)) > 60 then
    return jsonb_build_object('ok',false,'message','회원 이름을 입력해 주세요.');
  end if;
  if p_last4 is null or p_last4 !~ '^[0-9]{4}$' then
    return jsonb_build_object('ok',false,'message','휴대폰 번호 뒷자리 숫자 4자리를 입력해 주세요.');
  end if;

  select owner_user_id, data into v_owner, v_data
  from public.withai_app_snapshots
  order by updated_at desc
  limit 1;

  if v_owner is null or v_data is null then
    return jsonb_build_object('ok',false,'message','센터 클라우드 데이터가 준비되지 않았습니다. 센터에 문의해 주세요.');
  end if;

  select count(*), (array_agg(m.value))[1]
    into v_count, v_member
  from jsonb_array_elements(coalesce(v_data->'members','[]'::jsonb)) as m(value)
  where lower(trim(coalesce(m.value->>'name',''))) = lower(trim(p_name))
    and right(regexp_replace(coalesce(m.value->>'phone',''),'[^0-9]','','g'),4) = p_last4
    and coalesce(m.value->>'status','') not in ('가입 대기','승인 대기','종료');

  if v_count = 0 then
    return jsonb_build_object('ok',false,'message','이름 또는 휴대폰 번호가 일치하는 이용 중 회원을 찾을 수 없습니다. 입력 정보를 확인해 주세요.');
  elsif v_count > 1 then
    return jsonb_build_object('ok',false,'message','동일한 이름과 번호 뒷자리를 가진 회원이 여러 명입니다. 센터에 회원 정보 확인을 요청해 주세요.');
  end if;

  v_member_id := v_member->>'id';
  if coalesce(v_member_id,'') = '' then
    return jsonb_build_object('ok',false,'message','회원 식별 정보를 찾을 수 없습니다. 센터에 문의해 주세요.');
  end if;

  v_token := gen_random_uuid()::text;
  insert into public.withai_member_portal_tokens(token,owner_user_id,member_id,expires_at)
  values(v_token,v_owner,v_member_id,now()+interval '30 days');

  return jsonb_build_object(
    'ok',true,'token',v_token,'member',v_member,
    'sessions','[]'::jsonb,'meals','[]'::jsonb,'memberExercises','[]'::jsonb,
    'exerciseGuides',coalesce(v_data->'memberExerciseGuides','[]'::jsonb)
  );
end;
$$;

revoke all on function public.withai_member_enter_by_name_last4(text,text) from public;
grant execute on function public.withai_member_enter_by_name_last4(text,text) to anon, authenticated;
