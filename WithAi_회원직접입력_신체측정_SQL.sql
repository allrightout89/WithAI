-- WithAi 회원 직접 신체 측정 저장 RPC (additive)
-- 회원 포털 토큰으로 본인에게만 측정 기록을 추가합니다.
-- 기존 테이블, 로그인, 기존 측정값은 변경/삭제하지 않습니다.

create or replace function public.withai_member_save_measurement(
  p_token text,
  p_entry jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_app_member_id text;
  v_date date;
  v_weight numeric(6,2);
  v_body_fat numeric(5,2);
  v_muscle numeric(6,2);
  v_waist numeric(6,2);
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

  begin
    v_date := coalesce(nullif(p_entry->>'date','')::date, current_date);
    v_weight := nullif(p_entry->>'weight','')::numeric;
    v_body_fat := nullif(p_entry->>'bodyFat','')::numeric;
    v_muscle := nullif(p_entry->>'muscle','')::numeric;
    v_waist := nullif(p_entry->>'waist','')::numeric;
  exception when others then
    return jsonb_build_object('ok', false, 'message', '측정일 또는 측정값 형식을 확인해 주세요.');
  end;

  if v_weight is null and v_body_fat is null and v_muscle is null and v_waist is null then
    return jsonb_build_object('ok', false, 'message', '측정값을 한 가지 이상 입력해 주세요.');
  end if;
  if (v_weight is not null and v_weight <= 0)
     or (v_body_fat is not null and (v_body_fat < 0 or v_body_fat > 100))
     or (v_muscle is not null and v_muscle <= 0)
     or (v_waist is not null and v_waist <= 0) then
    return jsonb_build_object('ok', false, 'message', '측정값의 범위를 확인해 주세요.');
  end if;

  insert into public.withai_app_body_measurements
    (app_member_id, measured_on, weight_kg, body_fat_percent, muscle_kg, waist_cm)
  values
    (v_app_member_id, v_date, v_weight, v_body_fat, v_muscle, v_waist);

  return jsonb_build_object('ok', true);
end;
$$;

revoke all on function public.withai_member_save_measurement(text, jsonb) from public;
grant execute on function public.withai_member_save_measurement(text, jsonb) to anon, authenticated;
