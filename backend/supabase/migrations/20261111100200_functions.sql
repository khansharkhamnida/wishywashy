-- WishyWashy backend, part 3 of 4: the booking rules, as database functions.
--
-- These are the same rules the iOS app runs on the phone today (LocalBookingService), moved to the server so nobody
-- can bypass them and so they use the server's clock.
--
-- Two kinds of function:
--   private.*  internal helpers. The apps cannot call them.
--   public.*   what the apps call, with  select * from rpc('book_machine', ...)  or the REST endpoint /rpc/book_machine.
--
-- Errors are plain words the app maps to its own messages:
--   machine_unavailable, already_holding, slot_taken, too_many_bookings, not_ready, machine_busy,
--   not_found, not_signed_in

-- =================================================================================================================
-- Internal helpers
-- =================================================================================================================

-- When a laundromat opens and closes on the local day that contains p_day
create function private.opening_window(p_laundromat text, p_day timestamptz, out opens timestamptz, out closes timestamptz)
language sql
stable
security definer
set search_path = ''
as $$
  select ((((p_day at time zone l.timezone)::date) + make_interval(hours => l.open_hour)) at time zone l.timezone),
         ((((p_day at time zone l.timezone)::date) + make_interval(hours => l.close_hour)) at time zone l.timezone)
  from public.laundromats l
  where l.id = p_laundromat;
$$;

-- Whether the machine is free for a whole cycle starting at p_start
create function private.can_book(p_machine public.machines, p_start timestamptz)
returns boolean
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_cycle interval := make_interval(mins => p_machine.cycle_minutes);
  v_end timestamptz := p_start + make_interval(mins => p_machine.cycle_minutes);
  v_window record;
  v_busy_until timestamptz;
begin
  if p_machine.status = 'out_of_order' then
    return false;
  end if;

  select * into v_window from private.opening_window(p_machine.laundromat_id, p_start);
  if v_window.opens is null then
    return false;
  end if;
  if p_start < v_window.opens or v_end > v_window.closes or p_start < now() - interval '1 minute' then
    return false;
  end if;

  if p_machine.status = 'in_use' then
    v_busy_until := coalesce(p_machine.available_at, now() + v_cycle);
    if p_start < v_busy_until then
      return false;
    end if;
  end if;

  return not exists (
    select 1
    from public.bookings b
    where b.machine_id = p_machine.id
      and b.status in ('pending', 'confirmed', 'in_progress')
      and b.start_time < v_end
      and p_start < b.end_time
  );
end;
$$;

-- When the user could start if they reserve "now": straight away for a free machine, or when a busy one frees up if
-- that is soon. Null if the machine cannot be reserved now.
create function private.now_start(p_machine public.machines)
returns timestamptz
language plpgsql
stable
security definer
set search_path = ''
as $$
declare
  v_rules public.booking_rules;
  v_candidate timestamptz;
begin
  select * into v_rules from public.booking_rules;

  if p_machine.status = 'available' then
    v_candidate := now();
  elsif p_machine.status = 'in_use' then
    if p_machine.available_at is null
       or p_machine.available_at - now() > make_interval(mins => v_rules.finishing_soon_minutes) then
      return null;
    end if;
    v_candidate := greatest(p_machine.available_at, now());
  else
    return null;
  end if;

  if private.can_book(p_machine, v_candidate) then
    return v_candidate;
  end if;
  return null;
end;
$$;

-- Frees the machine, but only if it is still in the state this booking left it in
create function private.release_machine(p_machine text, p_from text)
returns void
language sql
security definer
set search_path = ''
as $$
  update public.machines
  set status = 'available', available_at = null, status_updated_at = now()
  where id = p_machine and status = p_from;
$$;

-- Gives bookings waiting for a busy machine a full check-in window once it frees up, but never more than
-- max_wait_minutes past their start. Returns whether anything changed.
create function private.extend_holds(p_machine text, p_free timestamptz)
returns boolean
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rules public.booking_rules;
  v_count int;
begin
  select * into v_rules from public.booking_rules;

  update public.bookings b
  set hold_expires_at = least(p_free + make_interval(mins => v_rules.hold_minutes),
                              b.start_time + make_interval(mins => v_rules.max_wait_minutes + v_rules.hold_minutes))
  where b.machine_id = p_machine
    and b.status = 'confirmed'
    and b.hold_expires_at is not null
    and b.start_time < p_free
    and least(p_free + make_interval(mins => v_rules.hold_minutes),
              b.start_time + make_interval(mins => v_rules.max_wait_minutes + v_rules.hold_minutes)) > b.hold_expires_at;

  get diagnostics v_count = row_count;
  return v_count > 0;
end;
$$;

-- Moves time forward. Called before every read or change, and once a minute by a scheduled job (part 4), so the data
-- is right even when nobody has the app open:
--   holds wait for a machine that is still busy, holds that ran out expire, finished cycles complete,
--   a booking whose start time has come holds its machine, and a machine nobody holds is released.
create function private.advance_bookings()
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_row record;
begin
  perform pg_advisory_xact_lock(7266348);  -- one at a time, so two callers never fight over the same rows

  -- A busy machine delays the bookings waiting for it, so their check-in window starts when it frees up
  for v_row in select id, available_at from public.machines where status = 'in_use' and available_at is not null loop
    perform private.extend_holds(v_row.id, v_row.available_at);
  end loop;

  -- Holds that ran out expire, and the machine is released
  for v_row in
    update public.bookings
    set status = 'expired', hold_expires_at = null
    where status = 'confirmed' and hold_expires_at is not null and hold_expires_at < now()
    returning machine_id
  loop
    perform private.release_machine(v_row.machine_id, 'reserved');
  end loop;

  -- Finished cycles complete, and the machine is released
  for v_row in
    update public.bookings
    set status = 'completed'
    where status = 'in_progress' and end_time < now()
    returning machine_id
  loop
    perform private.release_machine(v_row.machine_id, 'in_use');
  end loop;

  -- Cycles by people without a booking in the app
  update public.machines m
  set status = 'available', available_at = null, status_updated_at = now()
  where m.status = 'in_use'
    and m.available_at is not null
    and m.available_at < now()
    and not exists (select 1 from public.bookings b where b.machine_id = m.id and b.status = 'in_progress');

  -- A booking whose start time has come holds its machine
  update public.machines m
  set status = 'reserved', status_updated_at = now()
  where m.status = 'available'
    and exists (select 1 from public.bookings b
                where b.machine_id = m.id and b.status = 'confirmed'
                  and b.hold_expires_at is not null and b.start_time <= now());

  -- Only a booking can hold a machine, so a "reserved" machine without one is released
  update public.machines m
  set status = 'available', available_at = null, status_updated_at = now()
  where m.status = 'reserved'
    and not exists (select 1 from public.bookings b
                    where b.machine_id = m.id and b.status = 'confirmed'
                      and b.hold_expires_at is not null and b.start_time <= now());
end;
$$;

-- =================================================================================================================
-- What the apps call
-- =================================================================================================================

-- Books a machine. p_start null means "now" (see get_now_start). Nothing is charged until check-in.
create function public.book_machine(p_machine text, p_start timestamptz default null)
returns public.bookings
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_rules public.booking_rules;
  v_machine public.machines;
  v_laundromat public.laundromats;
  v_begin timestamptz;
  v_last_day_end timestamptz;
  v_booking public.bookings;
begin
  if v_user is null then
    raise exception 'not_signed_in';
  end if;

  perform private.advance_bookings();
  select * into v_rules from public.booking_rules;

  -- Lock the machine row, so two people booking the same machine are handled one after the other
  select * into v_machine from public.machines where id = p_machine for update;
  if not found then
    raise exception 'machine_unavailable';
  end if;
  select * into v_laundromat from public.laundromats where id = v_machine.laundromat_id;

  if p_start is null then
    -- One reservation at a time can be waiting for check-in, so nobody blocks several machines
    if exists (select 1 from public.bookings
               where user_id = v_user and status = 'confirmed' and hold_expires_at is not null and start_time <= now()) then
      raise exception 'already_holding';
    end if;
    v_begin := private.now_start(v_machine);
    if v_begin is null then
      raise exception 'machine_unavailable';
    end if;
  else
    v_begin := p_start;
    -- Only today and days_ahead more days can be booked
    v_last_day_end := (((now() at time zone v_laundromat.timezone)::date + v_rules.days_ahead + 1)::timestamp)
                      at time zone v_laundromat.timezone;
    if v_begin >= v_last_day_end then
      raise exception 'slot_taken';
    end if;
  end if;

  if (select count(*) from public.bookings
      where user_id = v_user and status = 'confirmed' and hold_expires_at is not null) >= v_rules.max_upcoming then
    raise exception 'too_many_bookings';
  end if;

  if not private.can_book(v_machine, v_begin) then
    if p_start is null then
      raise exception 'machine_unavailable';
    end if;
    raise exception 'slot_taken';
  end if;

  insert into public.bookings (user_id, laundromat_id, machine_id, start_time, end_time, status,
                               hold_expires_at, price_minor, currency)
  values (v_user, v_machine.laundromat_id, v_machine.id, v_begin,
          v_begin + make_interval(mins => v_machine.cycle_minutes), 'confirmed',
          v_begin + make_interval(mins => v_rules.hold_minutes), v_machine.price_minor, v_laundromat.currency)
  returning * into v_booking;

  perform private.advance_bookings();
  select * into v_booking from public.bookings where id = v_booking.id;
  return v_booking;
exception
  when exclusion_violation then
    raise exception 'slot_taken';
end;
$$;

-- When "reserve now" would start for this machine, or null if it cannot be reserved now
create function public.get_now_start(p_machine text)
returns timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_machine public.machines;
begin
  perform private.advance_bookings();
  select * into v_machine from public.machines where id = p_machine;
  if not found then
    return null;
  end if;
  return private.now_start(v_machine);
end;
$$;

-- Free start times on one day, p_day_offset days from today (0 is today)
create function public.get_slots(p_machine text, p_day_offset int)
returns setof timestamptz
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_rules public.booking_rules;
  v_machine public.machines;
  v_laundromat public.laundromats;
  v_day timestamptz;
  v_window record;
  v_time timestamptz;
begin
  perform private.advance_bookings();
  select * into v_rules from public.booking_rules;
  if p_day_offset < 0 or p_day_offset > v_rules.days_ahead then
    return;
  end if;

  select * into v_machine from public.machines where id = p_machine;
  if not found then
    return;
  end if;
  select * into v_laundromat from public.laundromats where id = v_machine.laundromat_id;

  v_day := (((now() at time zone v_laundromat.timezone)::date + p_day_offset)::timestamp) at time zone v_laundromat.timezone;
  select * into v_window from private.opening_window(v_machine.laundromat_id, v_day);

  v_time := v_window.opens;
  while v_time < v_window.closes loop
    if v_time > now() and private.can_book(v_machine, v_time) then
      return next v_time;
    end if;
    v_time := v_time + make_interval(mins => v_rules.slot_step_minutes);
  end loop;
end;
$$;

-- Cancels a reservation or a later booking that has not been checked in. It is free.
create function public.cancel_booking(p_booking text)
returns void
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_machine text;
begin
  if v_user is null then
    raise exception 'not_signed_in';
  end if;

  perform private.advance_bookings();

  update public.bookings
  set status = 'cancelled', hold_expires_at = null
  where id = p_booking and user_id = v_user and status = 'confirmed' and hold_expires_at is not null
  returning machine_id into v_machine;

  if not found then
    raise exception 'not_found';
  end if;

  perform private.release_machine(v_machine, 'reserved');
end;
$$;

-- Whether the user can check in right now, without changing anything. Called before taking payment.
create function public.can_check_in(p_booking text)
returns public.bookings
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_user uuid := auth.uid();
  v_booking public.bookings;
  v_machine public.machines;
begin
  if v_user is null then
    raise exception 'not_signed_in';
  end if;

  perform private.advance_bookings();

  select * into v_booking from public.bookings where id = p_booking and user_id = v_user;
  if not found or v_booking.status <> 'confirmed' or v_booking.hold_expires_at is null or v_booking.start_time > now() then
    raise exception 'not_ready';
  end if;

  -- The machine only turns "reserved" once the previous user has left
  select * into v_machine from public.machines where id = v_booking.machine_id;
  if v_machine.status <> 'reserved' then
    raise exception 'machine_busy';
  end if;

  return v_booking;
end;
$$;

-- Starts the cycle once it has been paid for. NOT callable by the apps: the payment webhook calls it with the
-- service key, after the payment provider confirms the payment.
create function public.check_in(p_booking text, p_payment_id text)
returns public.bookings
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_booking public.bookings;
  v_machine public.machines;
  v_end timestamptz;
begin
  perform private.advance_bookings();

  select * into v_booking from public.bookings where id = p_booking for update;
  if not found or v_booking.status <> 'confirmed' or v_booking.hold_expires_at is null or v_booking.start_time > now() then
    raise exception 'not_ready';
  end if;

  select * into v_machine from public.machines where id = v_booking.machine_id for update;
  if v_machine.status <> 'reserved' then
    raise exception 'machine_busy';
  end if;

  v_end := now() + make_interval(mins => v_machine.cycle_minutes);

  update public.bookings
  set status = 'in_progress', start_time = now(), end_time = v_end, hold_expires_at = null, payment_id = p_payment_id
  where id = v_booking.id;

  update public.machines
  set status = 'in_use', available_at = v_end, status_updated_at = now()
  where id = v_machine.id;

  -- A late check-in can run into the next booking, whose hold must not run out while it waits
  perform private.extend_holds(v_machine.id, v_end);

  select * into v_booking from public.bookings where id = v_booking.id;
  return v_booking;
end;
$$;

-- =================================================================================================================
-- Permissions
-- =================================================================================================================
-- Postgres lets everyone run a new function unless told otherwise, so take that away first.
revoke execute on all functions in schema public from public, anon, authenticated;
revoke execute on all functions in schema private from public, anon, authenticated;

grant execute on function public.get_now_start(text)                to anon, authenticated;
grant execute on function public.get_slots(text, int)               to anon, authenticated;
grant execute on function public.book_machine(text, timestamptz)    to authenticated;
grant execute on function public.cancel_booking(text)               to authenticated;
grant execute on function public.can_check_in(text)                 to authenticated;
grant execute on function public.check_in(text, text)               to service_role;
