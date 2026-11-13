-- DANGER: for development only. Never run this on a project with real users.
--
-- Deletes every WishyWashy table (and all the data in them: laundromats, machines, bookings, profiles), every
-- WishyWashy function and the scheduled job. It does NOT delete the people who signed up (that is Supabase's
-- Authentication > Users list).
--
-- Use it when something went wrong halfway through the first run, or to start again from a clean slate.
-- Afterwards run the four migration files in order, then seed.sql, as in backend/README.md.

-- Stop the scheduled job, if pg_cron is on
do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    execute $q$select cron.unschedule(jobid) from cron.job where jobname = 'advance-bookings'$q$;
  end if;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;

drop table if exists public.bookings, public.machines, public.laundromats, public.profiles, public.booking_rules cascade;

-- Any function that is left (the ones that use the tables above are already gone)
do $$
declare
  f record;
begin
  for f in
    select p.oid::regprocedure as signature
    from pg_proc p
    join pg_namespace n on n.oid = p.pronamespace
    where n.nspname = 'private'
       or (n.nspname = 'public'
           and p.proname in ('book_machine', 'get_now_start', 'get_slots', 'cancel_booking', 'can_check_in', 'check_in'))
  loop
    execute format('drop function if exists %s cascade', f.signature);
  end loop;
end;
$$;

drop schema if exists private;
