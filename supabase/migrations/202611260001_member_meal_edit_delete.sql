-- WithAi / calendar-first member portal: member-owned meal update & delete
-- Additive migration only. Existing records and other snapshot fields are preserved.
create or replace function public.withai_member_update_meal(
  p_token text,
  p_meal_id text,
  p_entry jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_owner uuid;
  v_member_id text;
  v_data jsonb;
  v_meals jsonb;
  v_entry jsonb;
  v_food text;
  v_grams numeric;
  v_kcal numeric;
  v_carbs numeric;
  v_protein numeric;
  v_fat numeric;
  v_meal text;
  v_date text;
begin
  select owner_user_id, member_id into v_owner, v_member_id
  from public.withai_member_portal_tokens
  where token = p_token and expires_at > now();

  if v_owner is null then
    return jsonb_build_object('ok', false, 'message', '회원 로그인 정보가 만료되었습니다. 다시 로그인해 주세요.');
  end if;

  if coalesce(p_meal_id, '') = '' then
    return jsonb_build_object('ok', false, 'message', '식단 기록 식별 정보가 없습니다.');
  end if;

  v_food := trim(coalesce(p_entry->>'food', ''));
  v_grams := nullif(p_entry->>'grams', '')::numeric;
  v_kcal := coalesce(nullif(p_entry->>'kcal', '')::numeric, 0);
  v_carbs := coalesce(nullif(p_entry->>'carbs', '')::numeric, 0);
  v_protein := coalesce(nullif(p_entry->>'protein', '')::numeric, 0);
  v_fat := coalesce(nullif(p_entry->>'fat', '')::numeric, 0);
  v_meal := coalesce(nullif(p_entry->>'meal', ''), '간식');
  v_date := coalesce(nullif(p_entry->>'date', ''), to_char(current_date, 'YYYY-MM-DD'));

  if v_food = '' then return jsonb_build_object('ok', false, 'message', '음식명을 입력해 주세요.'); end if;
  if v_grams is null or v_grams < 1 or v_grams > 3000 then
    return jsonb_build_object('ok', false, 'message', '섭취량은 1~3000g 사이로 입력해 주세요.');
  end if;
  if v_kcal < 0 or v_carbs < 0 or v_protein < 0 or v_fat < 0 then
    return jsonb_build_object('ok', false, 'message', '열량과 영양소는 0 이상으로 입력해 주세요.');
  end if;
  if v_meal not in ('아침', '점심', '저녁', '간식') then
    return jsonb_build_object('ok', false, 'message', '식사 구분을 확인해 주세요.');
  end if;
  if v_date !~ '^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then
  end if;

  select data into v_data
  from public.withai_app_snapshots
  where owner_user_id = v_owner
  for update;

  if v_data is null then return jsonb_build_object('ok', false, 'message', '회원 식단 데이터를 찾을 수 없습니다.'); end if;

  select x.value || jsonb_build_object(
    'date', v_date, 'meal', v_meal, 'food', v_food, 'grams', v_grams,
    'kcal', v_kcal, 'carbs', v_carbs, 'protein', v_protein, 'fat', v_fat,
    'note', coalesce(p_entry->>'note', '')
  )
  into v_entry
  from jsonb_array_elements(coalesce(v_data->'meals', '[]'::jsonb)) as x(value)
  where x.value->>'id' = p_meal_id
    and coalesce(x.value->>'memberId', x.value->>'member_id', '') = v_member_id
  limit 1;

  if v_entry is null then
    return jsonb_build_object('ok', false, 'message', '해당 회원의 식단 기록을 찾을 수 없습니다.');
  end if;

  select jsonb_agg(
    case
      when x.value->>'id' = p_meal_id
       and coalesce(x.value->>'memberId', x.value->>'member_id', '') = v_member_id
      then v_entry
      else x.value
    end
    order by x.ordinality
  )
  into v_meals
  from jsonb_array_elements(coalesce(v_data->'meals', '[]'::jsonb))
    with ordinality as x(value, ordinality);

  v_data := jsonb_set(v_data, '{meals}', coalesce(v_meals, '[]'::jsonb), true);
  update public.withai_app_snapshots
  set data = v_data, updated_at = now()
  where owner_user_id = v_owner;

  return jsonb_build_object('ok', true, 'message', '식단 기록을 수정했습니다.', 'entry', v_entry);
end;
$$;

create or replace function public.withai_member_delete_meal(
  p_token text,
  p_meal_id text
)
returns jsonb
language plpgsql
security definer
set search_path = public, extensions
as $$
declare
  v_owner uuid;
  v_member_id text;
  v_data jsonb;
  v_meals jsonb;
  v_count integer;
begin
  select owner_user_id, member_id into v_owner, v_member_id
  from public.withai_member_portal_tokens
  where token = p_token and expires_at > now();

  if v_owner is null then
    return jsonb_build_object('ok', false, 'message', '회원 로그인 정보가 만료되었습니다. 다시 로그인해 주세요.');
  end if;
  if coalesce(p_meal_id, '') = '' then
    return jsonb_build_object('ok', false, 'message', '식단 기록 식별 정보가 없습니다.');
  end if;

  select data into v_data
  from public.withai_app_snapshots
  where owner_user_id = v_owner
  for update;

  if v_data is null then return jsonb_build_object('ok', false, 'message', '회원 식단 데이터를 찾을 수 없습니다.'); end if;

  select count(*) into v_count
  from jsonb_array_elements(coalesce(v_data->'meals', '[]'::jsonb)) as x(value)
  where x.value->>'id' = p_meal_id
    and coalesce(x.value->>'memberId', x.value->>'member_id', '') = v_member_id;

  if v_count = 0 then
    return jsonb_build_object('ok', false, 'message', '해당 회원의 식단 기록을 찾을 수 없습니다.');
  end if;

  select coalesce(jsonb_agg(x.value order by x.ordinality), '[]'::jsonb)
  into v_meals
  from jsonb_array_elements(coalesce(v_data->'meals', '[]'::jsonb))
    with ordinality as x(value, ordinality)
  where not (
    x.value->>'id' = p_meal_id
    and coalesce(x.value->>'memberId', x.value->>'member_id', '') = v_member_id
  );

  v_data := jsonb_set(v_data, '{meals}', v_meals, true);
  update public.withai_app_snapshots
  set data = v_data, updated_at = now()
  where owner_user_id = v_owner;

  return jsonb_build_object('ok', true, 'message', '식단 기록을 삭제했습니다.');
end;
$$;

revoke all on function public.withai_member_update_meal(text, text, jsonb) from public;
revoke all on function public.withai_member_delete_meal(text, text) from public;
grant execute on function public.withai_member_update_meal(text, text, jsonb) to anon, authenticated;
grant execute on function public.withai_member_delete_meal(text, text) to anon, authenticated;
