-- WishyWashy backend, part 4 of 4: run private.advance_bookings() every minute.
--
-- This moves time forward on the server (expire holds, finish cycles, free machines) even when nobody has the app open.
-- It needs the pg_cron extension. In Supabase turn it on first:
--   Dashboard > Database > Extensions > search "pg_cron" > switch it on
-- If pg_cron is not on yet, this file does nothing except print a notice, and you can run it again later.
-- Nothing breaks without it: every function in part 3 also moves time forward before it reads or changes anything.

do $$
begin
  if exists (select 1 from pg_extension where extname = 'pg_cron') then
    perform cron.schedule('advance-bookings', '* * * * *', 'select private.advance_bookings()');
    raise notice 'Scheduled advance-bookings to run every minute.';
  else
    raise notice 'pg_cron is not enabled, so nothing was scheduled. Enable it, then run this file again.';
  end if;
end;
$$;
