-- ONLY for the throwaway Postgres that `npm test` starts. Never run this on a real Supabase project.
--
-- Plain Postgres does not have the parts of Supabase that the migrations rely on: the three API roles, the auth
-- schema, auth.uid(), and the realtime publication. This file makes just enough of them to run the migrations and tests.

do $$
begin
  if exists (select 1 from pg_roles where rolname = 'supabase_admin') then
    raise exception 'Refusing to run: this looks like a real Supabase database.';
  end if;
end;
$$;

create role anon nologin;
create role authenticated nologin;
create role service_role nologin bypassrls;

create schema extensions;
create schema auth;

create table auth.users (
  id uuid primary key default gen_random_uuid(),
  email text,
  raw_user_meta_data jsonb not null default '{}'
);

-- Like Supabase: read the signed-in user's id from the request's JWT claims
create function auth.uid()
returns uuid
language sql
stable
as $$
  select coalesce(nullif(current_setting('request.jwt.claim.sub', true), ''),
                  nullif(current_setting('request.jwt.claims', true), '')::jsonb ->> 'sub')::uuid
$$;

grant usage on schema auth to anon, authenticated, service_role;
grant usage on schema public to anon, authenticated, service_role;

create publication supabase_realtime;

-- Supabase lets the API roles use everything new in the public schema by default. Copy that, so the tests prove the
-- migrations take it away again rather than relying on a stricter default.
alter default privileges in schema public grant all on tables to anon, authenticated, service_role;
alter default privileges in schema public grant all on functions to anon, authenticated, service_role;
alter default privileges in schema public grant all on sequences to anon, authenticated, service_role;
