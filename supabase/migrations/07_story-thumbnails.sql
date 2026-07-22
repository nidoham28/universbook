-- Creates the `story-thumbnails` Storage bucket and its access policies.
--
-- Upload path convention (see StoriesService.uploadThumbnail):
--   {auth.uid()}/{timestamp}.{ext}
-- The policies below rely on that first path segment matching the
-- uploader's own user id.

-- 1. The bucket itself, public so getPublicUrl() works without a signed URL.
insert into storage.buckets (id, name, public)
values ('story-thumbnails', 'story-thumbnails', true)
on conflict (id) do update set public = true;

-- 2. Anyone (including anonymous readers) can view thumbnails, since the
--    bucket is public — this just makes it explicit at the RLS level too.
create policy "Public read access to story thumbnails"
  on storage.objects for select
  using (bucket_id = 'story-thumbnails');

-- 3. Signed-in users can upload only into their own folder
--    ({auth.uid()}/...), not anyone else's.
create policy "Users can upload their own story thumbnails"
  on storage.objects for insert
  to authenticated
  with check (
    bucket_id = 'story-thumbnails'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- 4. Signed-in users can replace/overwrite their own thumbnails
--    (matches uploadBinary's fileOptions: upsert: true).
create policy "Users can update their own story thumbnails"
  on storage.objects for update
  to authenticated
  using (
    bucket_id = 'story-thumbnails'
    and (storage.foldername(name))[1] = auth.uid()::text
  )
  with check (
    bucket_id = 'story-thumbnails'
    and (storage.foldername(name))[1] = auth.uid()::text
  );

-- 5. Signed-in users can delete their own thumbnails (e.g. when removing
--    a picked image or deleting a story).
create policy "Users can delete their own story thumbnails"
  on storage.objects for delete
  to authenticated
  using (
    bucket_id = 'story-thumbnails'
    and (storage.foldername(name))[1] = auth.uid()::text
  );