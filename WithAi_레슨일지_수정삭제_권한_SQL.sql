-- WithAi 레슨일지 수정 권한 보완
-- 기존 레슨일지를 담당 트레이너가 수정할 때 created_by가 관리자인 경우에도
-- 수정 후 정책 검증에서 차단되지 않도록 UPDATE 정책의 WITH CHECK를 보완합니다.
-- 삭제 정책은 기존 WithAi_기존회원_트레이너배정_레슨공유_SQL.sql에서 이미 설정되어 있습니다.

drop policy if exists withai_app_training_sessions_update on public.withai_app_training_sessions;

create policy withai_app_training_sessions_update
on public.withai_app_training_sessions
for update
to authenticated
using (
  public.current_app_role() = 'admin'
  or exists (
    select 1
    from public.withai_app_member_assignments a
    where a.app_member_id = withai_app_training_sessions.app_member_id
      and a.trainer_user_id = auth.uid()
  )
)
with check (
  public.current_app_role() = 'admin'
  or exists (
    select 1
    from public.withai_app_member_assignments a
    where a.app_member_id = withai_app_training_sessions.app_member_id
      and a.trainer_user_id = auth.uid()
  )
);

grant select, insert, update, delete
on public.withai_app_training_sessions
to authenticated;
