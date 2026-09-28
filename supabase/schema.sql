-- Run once in the SQL Editor of the ARMSys Supabase project.
create table public.documents (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id),
  title text not null check (length(title) between 1 and 180),
  number text not null,
  category text not null,
  signer_name text not null,
  signer_email text not null check (signer_email = lower(signer_email)),
  kind text not null check (kind in ('Tanda Tangan','Paraf')),
  cluster text not null default '',
  notes text not null default '',
  original_path text not null,
  signed_path text,
  placement jsonb,
  status text not null default 'pending' check (status in ('pending','signed')),
  created_at timestamptz not null default now(),
  signed_at timestamptz,
  signed_by uuid references auth.users(id)
);
create index documents_owner on public.documents(owner_id);
create index documents_signer on public.documents(signer_email);
alter table public.documents enable row level security;
revoke all on public.documents from anon, authenticated;
grant select, insert on public.documents to authenticated;
create policy "Participants read documents" on public.documents for select to authenticated
using (owner_id = (select auth.uid()) or signer_email = lower((select auth.jwt()->>'email')));
create policy "Owners submit pending documents" on public.documents for insert to authenticated
with check (owner_id = (select auth.uid()) and status = 'pending' and signed_path is null and signed_at is null and signed_by is null and placement is null
  and original_path = auth.uid()::text || '/' || id::text || '/original.pdf');

create table public.signature_models (
  user_id uuid not null references auth.users(id),
  kind text not null check (kind in ('Tanda Tangan','Paraf')),
  image text not null check (length(image) < 2000000 and image like 'data:image/png;base64,%'),
  primary key(user_id,kind)
);
alter table public.signature_models enable row level security;
revoke all on public.signature_models from anon, authenticated;
grant select,insert,update on public.signature_models to authenticated;
create policy "Private signature models" on public.signature_models for all to authenticated
using(user_id = (select auth.uid())) with check(user_id = (select auth.uid()));

create table public.document_events (
  id bigint generated always as identity primary key,
  document_id uuid not null references public.documents(id),
  actor_id uuid not null references auth.users(id),
  event text not null,
  created_at timestamptz not null default now()
);
alter table public.document_events enable row level security;
revoke all on public.document_events from anon, authenticated;
grant select on public.document_events to authenticated;
create policy "Participants read events" on public.document_events for select to authenticated
using (exists(select 1 from public.documents d where d.id = document_id));

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('documents','documents',false,15728640,array['application/pdf']);
create policy "Upload to own folder" on storage.objects for insert to authenticated
with check(bucket_id = 'documents' and (storage.foldername(name))[1] = (select auth.uid())::text);
create policy "Read assigned PDFs" on storage.objects for select to authenticated
using(bucket_id = 'documents' and ((storage.foldername(name))[1] = (select auth.uid())::text or exists(
select 1 from public.documents d where d.original_path = name or d.signed_path = name)));
-- Only orphan files can be deleted; referenced originals and signed PDFs are immutable.
create policy "Clean own orphan uploads" on storage.objects for delete to authenticated
using(bucket_id = 'documents' and (storage.foldername(name))[1] = (select auth.uid())::text and not exists(
select 1 from public.documents d where d.original_path = name or d.signed_path = name));

create or replace function public.complete_document(doc_id uuid,file_path text,"position" jsonb)
returns void language plpgsql security definer set search_path = '' as $$
declare doc public.documents;
begin
  if auth.uid() is null then raise exception 'Authentication required'; end if;
  select * into doc from public.documents where id=doc_id for update;
  if not found or doc.signer_email is distinct from lower(auth.jwt()->>'email') then
    raise exception 'Only the assigned signer can complete this document';
  end if;
  if doc.status <> 'pending' then raise exception 'Document already completed'; end if;
  if file_path not like auth.uid()::text || '/' || doc_id::text || '/signed-%.pdf' then
    raise exception 'Invalid signed file path';
  end if;
  if not exists(select 1 from storage.objects where bucket_id='documents' and name=file_path) then
    raise exception 'Signed PDF has not been uploaded';
  end if;
  if "position" is null or not ("position" ?& array['page','x','y','w','h']) or
    ("position"->>'page')::int < 1 or ("position"->>'x')::float < 0 or ("position"->>'y')::float < 0 or
    ("position"->>'w')::float <= 0 or ("position"->>'h')::float <= 0 or
    ("position"->>'x')::float + ("position"->>'w')::float > 1.00001 or
    ("position"->>'y')::float + ("position"->>'h')::float > 1.00001 then
    raise exception 'Invalid signature position';
  end if;
  update public.documents set status='signed',signed_path=file_path,placement="position",
    signed_at=now(),signed_by=auth.uid() where id=doc_id;
  insert into public.document_events(document_id,actor_id,event) values(doc_id,auth.uid(),'signed');
end $$;
revoke all on function public.complete_document(uuid,text,jsonb) from public, anon;
grant execute on function public.complete_document(uuid,text,jsonb) to authenticated;

create function public.log_document_created() returns trigger language plpgsql
security definer set search_path = '' as $$
begin
  insert into public.document_events(document_id,actor_id,event) values(new.id,new.owner_id,'created');
  return new;
end $$;
create trigger document_created after insert on public.documents for each row execute function public.log_document_created();
