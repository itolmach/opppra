-- Storage buckets for user-uploaded images.
-- Run after 0001_init.sql.

insert into storage.buckets (id, name, public)
values
  ('avatars', 'avatars', true),
  ('ticket-photos', 'ticket-photos', false),
  ('log-photos', 'log-photos', false)
on conflict (id) do nothing;

-- Each user may only read/write inside a folder named after their own uid,
-- e.g. ticket-photos/<uid>/<file>.jpg. Avatars are public to read (profile
-- pictures shown on public profiles) but still only owner-writable.

drop policy if exists "avatars_public_read" on storage.objects;
create policy "avatars_public_read" on storage.objects
  for select using (bucket_id = 'avatars');

drop policy if exists "avatars_owner_write" on storage.objects;
create policy "avatars_owner_write" on storage.objects
  for insert with check (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_owner_update" on storage.objects;
create policy "avatars_owner_update" on storage.objects
  for update using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

drop policy if exists "avatars_owner_delete" on storage.objects;
create policy "avatars_owner_delete" on storage.objects
  for delete using (
    bucket_id = 'avatars' and (storage.foldername(name))[1] = auth.uid()::text
  );

do $$
declare
  b text;
begin
  foreach b in array array['ticket-photos', 'log-photos'] loop
    execute format(
      'drop policy if exists "%1$s_owner_all" on storage.objects', b
    );
    execute format(
      $sql$create policy "%1$s_owner_all" on storage.objects
        for all using (
          bucket_id = %2$L and (storage.foldername(name))[1] = auth.uid()::text
        ) with check (
          bucket_id = %2$L and (storage.foldername(name))[1] = auth.uid()::text
        )$sql$,
      b, b
    );
  end loop;
end $$;
