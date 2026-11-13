-- Time passing: holds waiting for a busy machine, expiry, finished cycles and released machines.
-- These set up a situation directly (as the server would), then call private.advance_bookings(), which the
-- scheduled job runs every minute and every public function runs first.

begin;
select test_support.setup();
do $$
declare
  booking_id text;
  hold timestamptz;
begin
  -- Started 12 minutes ago, hold ran out 2 minutes ago, but a walk-in is on the machine for 5 more minutes
  perform test_support.set_machine('w01', 'in_use', now() + interval '5 minutes');
  booking_id := test_support.add_booking(test_support.alice(), 'w01', now() - interval '12 minutes', 'confirmed', now() - interval '2 minutes');

  perform private.advance_bookings();

  select hold_expires_at into hold from public.bookings where status = 'confirmed' and machine_id = 'w01';
  assert hold is not null, 'booking should still be waiting, not expired';
  assert hold = now() + interval '15 minutes', 'the check-in window should start when the machine frees up, hold was ' || hold;
end;
$$;
select test_support.pass('a hold waits for a busy machine instead of expiring');
rollback;

begin;
select test_support.setup();
do $$
declare
  booking_id text;
begin
  -- The walk-in left a minute ago. The user gets a full window from then.
  perform test_support.set_machine('w01', 'in_use', now() - interval '1 minute');
  booking_id := test_support.add_booking(test_support.alice(), 'w01', now() - interval '12 minutes', 'confirmed', now() - interval '2 minutes');

  perform private.advance_bookings();

  assert (select status from public.bookings where machine_id = 'w01') = 'confirmed', 'booking should still be confirmed';
  assert (select hold_expires_at from public.bookings where machine_id = 'w01') = now() + interval '9 minutes', 'window should run from when the machine freed';
  assert (select status from public.machines where id = 'w01') = 'reserved', 'machine should now be held for the booking';
end;
$$;
select test_support.pass('the check-in window starts when the machine frees up');
rollback;

begin;
select test_support.setup();
do $$
declare
  start timestamptz := now() - interval '5 minutes';
begin
  perform test_support.set_machine('w01', 'in_use', now() + interval '120 minutes');
  perform test_support.add_booking(test_support.alice(), 'w01', start, 'confirmed', now() + interval '5 minutes');

  perform private.advance_bookings();

  -- 30 minutes of waiting plus the 10 minute window, counted from the start time
  assert (select hold_expires_at from public.bookings where machine_id = 'w01') = start + interval '40 minutes', 'the wait should be capped';
end;
$$;
select test_support.pass('waiting for a busy machine is capped at 30 minutes past the start');
rollback;

begin;
select test_support.setup();
do $$
begin
  perform test_support.set_machine('w01', 'reserved');
  perform test_support.add_booking(test_support.alice(), 'w01', now() - interval '12 minutes', 'confirmed', now() - interval '2 minutes');

  perform private.advance_bookings();

  assert (select status from public.bookings where machine_id = 'w01') = 'expired', 'unused hold should expire';
  assert (select hold_expires_at from public.bookings where machine_id = 'w01') is null, 'hold should be cleared';
  assert (select status from public.machines where id = 'w01') = 'available', 'machine should be released';
end;
$$;
select test_support.pass('an unused reservation expires and releases the machine');
rollback;

begin;
select test_support.setup();
do $$
declare
  next_hold timestamptz;
  checked public.bookings;
begin
  -- Alice is 9 minutes late, and Bob's booking starts the moment her slot would have ended
  perform test_support.set_machine('w01', 'reserved');
  perform test_support.add_booking(test_support.alice(), 'w01', now() - interval '9 minutes', 'confirmed', now() + interval '1 minute');
  perform test_support.add_booking(test_support.bob(), 'w01', now() + interval '27 minutes', 'confirmed', now() + interval '37 minutes');

  perform test_support.as_service();
  checked := public.check_in((select id from public.bookings where user_id = test_support.alice()), 'pay_1');
  reset role;

  select hold_expires_at into next_hold from public.bookings where user_id = test_support.bob();
  assert next_hold = checked.end_time + interval '10 minutes', 'Bob should get his full window after Alice finishes, was ' || next_hold;
end;
$$;
select test_support.pass('a late check-in extends the next booking''s hold');
rollback;

begin;
select test_support.setup();
do $$
begin
  perform test_support.set_machine('w01', 'reserved');
  perform private.advance_bookings();
  assert (select status from public.machines where id = 'w01') = 'available', 'a reserved machine nobody holds should be released';
end;
$$;
select test_support.pass('a reserved machine without a booking is released');
rollback;

begin;
select test_support.setup();
do $$
begin
  perform test_support.set_machine('w01', 'reserved');
  perform test_support.add_booking(test_support.alice(), 'w01', now() - interval '1 minute', 'confirmed', now() + interval '9 minutes');
  perform private.advance_bookings();
  assert (select status from public.machines where id = 'w01') = 'reserved', 'a held machine should stay reserved';
end;
$$;
select test_support.pass('a reserved machine with a held booking stays reserved');
rollback;

begin;
select test_support.setup();
do $$
begin
  -- A booking whose start time has arrived holds its free machine
  perform test_support.add_booking(test_support.alice(), 'w03', now() - interval '1 minute', 'confirmed', now() + interval '9 minutes');
  perform private.advance_bookings();
  assert (select status from public.machines where id = 'w03') = 'reserved', 'machine should be held once the start time has come';
end;
$$;
select test_support.pass('a booking holds its machine from its start time');
rollback;

begin;
select test_support.setup();
do $$
begin
  -- Cycle started 40 minutes ago, so it finished 4 minutes ago
  perform test_support.set_machine('w01', 'in_use', now() - interval '4 minutes');
  perform test_support.add_booking(test_support.alice(), 'w01', now() - interval '40 minutes', 'in_progress');
  perform private.advance_bookings();
  assert (select status from public.bookings where machine_id = 'w01') = 'completed', 'cycle should be completed';
  assert (select status from public.machines where id = 'w01') = 'available', 'machine should be free';
end;
$$;
select test_support.pass('a finished cycle completes and frees the machine');
rollback;

begin;
select test_support.setup();
do $$
begin
  -- A walk-in cycle (no booking in the app) that has finished
  perform test_support.set_machine('w02', 'in_use', now() - interval '1 minute');
  perform private.advance_bookings();
  assert (select status from public.machines where id = 'w02') = 'available', 'machine should be free';
  -- But a machine in use with no finish time stays in use, like in the app
  assert (select status from public.machines where id = 'w06') = 'in_use', 'machine with no finish time stays in use';
end;
$$;
select test_support.pass('a finished walk-in cycle frees the machine');
rollback;
