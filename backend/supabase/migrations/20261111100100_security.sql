-- WishyWashy backend, part 2 of 4: who may read and write what.
--
-- Supabase gives every table an automatic web API, so a table without row-level security (RLS) is readable and
-- writable by anyone who has the public key. Here every table has RLS on, apps can only READ, and nothing can be
-- written except through the functions in part 3 (which enforce the rules).

alter table public.booking_rules enable row level security;
alter table public.laundromats   enable row level security;
alter table public.machines      enable row level security;
alter table public.profiles      enable row level security;
alter table public.bookings      enable row level security;

-- Start from nothing, then grant only what is needed. This does not depend on Supabase's default grants.
revoke all on public.booking_rules, public.laundromats, public.machines, public.profiles, public.bookings
  from anon, authenticated;

grant select on public.booking_rules, public.laundromats, public.machines to anon, authenticated;
grant select on public.bookings, public.profiles to authenticated;
grant update (display_name, phone) on public.profiles to authenticated;   -- only these two columns

-- Everyone (even signed-out visitors) can browse laundromats and machines
create policy "anyone can read the rules"       on public.booking_rules for select to anon, authenticated using (true);
create policy "anyone can read laundromats"     on public.laundromats   for select to anon, authenticated using (true);
create policy "anyone can read machines"        on public.machines      for select to anon, authenticated using (true);

-- A signed-in user sees only their own bookings and profile
create policy "users read their own bookings"   on public.bookings for select to authenticated
  using (user_id = (select auth.uid()));
create policy "users read their own profile"    on public.profiles for select to authenticated
  using (id = (select auth.uid()));
create policy "users update their own profile"  on public.profiles for update to authenticated
  using (id = (select auth.uid())) with check (id = (select auth.uid()));

-- The private schema (helpers) is invisible to the apps
revoke all on schema private from public, anon, authenticated;

-- Live updates: let Realtime send machine and booking changes to open apps (it respects the policies above)
do $$
declare
  t text;
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    foreach t in array array['machines', 'bookings'] loop
      if not exists (select 1 from pg_publication_tables
                     where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t) then
        execute format('alter publication supabase_realtime add table public.%I', t);
      end if;
    end loop;
  end if;
end;
$$;
