-- Booking rules: reserving, the limits, cancelling and checking in.
-- Each test runs in its own transaction that is rolled back, so tests never affect each other.
-- Seed machines used: w01 (free, 36 min, S$6), w02 (in use, 18 min left), w04 (in use, 5 min left),
-- w05 (out of order), w06 (in use, no finish time).

begin;
select test_support.setup();
do $$
declare
  b public.bookings;
  m public.machines;
begin
  perform test_support.as_user(test_support.alice());
  b := public.book_machine('w01', null);
  assert b.status = 'confirmed', 'status was ' || b.status;
  assert b.user_id = test_support.alice(), 'wrong user';
  assert b.price_minor = 600, 'price was ' || b.price_minor;
  assert b.currency = 'SGD', 'currency was ' || b.currency;
  assert b.hold_expires_at = b.start_time + interval '10 minutes', 'hold window was wrong';
  reset role;
  select * into m from public.machines where id = 'w01';
  assert m.status = 'reserved', 'machine was ' || m.status;
end;
$$;
select test_support.pass('reserve now on a free machine holds it for the user');
rollback;

begin;
select test_support.setup();
do $$
begin
  perform test_support.as_user(test_support.alice());
  perform public.book_machine('w01', null);
  perform test_support.expect_error($q$select public.book_machine('w03', null)$q$, 'already_holding');
end;
$$;
select test_support.pass('a second "reserve now" while one is waiting for check-in is refused');
rollback;

begin;
select test_support.setup();
do $$
declare
  b public.bookings;
begin
  -- The limit is per user: Bob is not affected by Alice's bookings
  perform test_support.as_user(test_support.alice());
  perform public.book_machine('w01', test_support.local_at(1, 8));
  perform public.book_machine('w01', test_support.local_at(1, 10));
  perform public.book_machine('w01', test_support.local_at(1, 12));
  perform public.book_machine('w01', test_support.local_at(1, 14));
  perform public.book_machine('w01', test_support.local_at(1, 16));
  perform test_support.expect_error($q$select public.book_machine('w01', test_support.local_at(1, 18))$q$, 'too_many_bookings');

  perform test_support.as_user(test_support.bob());
  b := public.book_machine('w01', test_support.local_at(1, 18));
  assert b.user_id = test_support.bob(), 'Bob should be able to book';
end;
$$;
select test_support.pass('a sixth upcoming booking is refused, per user');
rollback;

begin;
select test_support.setup();
do $$
begin
  perform test_support.as_user(test_support.alice());
  perform public.book_machine('w01', test_support.local_at(1, 10));
  -- The 36 minute cycle from 10:00 is still running at 10:15
  perform test_support.expect_error($q$select public.book_machine('w01', test_support.local_at(1, 10, 15))$q$, 'slot_taken');
  -- Starting exactly when it ends is fine
  perform public.book_machine('w01', test_support.local_at(1, 10, 36));
end;
$$;
select test_support.pass('overlapping slots are refused, back-to-back slots are allowed');
rollback;

begin;
select test_support.setup();
do $$
begin
  perform test_support.as_user(test_support.alice());
  perform test_support.expect_error($q$select public.book_machine('w05', null)$q$, 'machine_unavailable');
  assert public.get_now_start('w05') is null, 'out of order machine should have no start time';
  perform test_support.expect_error($q$select public.book_machine('no-such-machine', null)$q$, 'machine_unavailable');
end;
$$;
select test_support.pass('an out of order or unknown machine cannot be reserved');
rollback;

begin;
select test_support.setup();
do $$
declare
  b public.bookings;
begin
  perform test_support.as_user(test_support.alice());
  assert public.get_now_start('w04') is not null, 'w04 frees in 5 minutes, so it can be reserved now';
  assert public.get_now_start('w02') is null, 'w02 frees in 18 minutes, which is more than 15';
  assert public.get_now_start('w06') is null, 'a machine with no finish time cannot be reserved now';

  b := public.book_machine('w04', null);
  reset role;
  assert b.start_time = (select available_at from public.machines where id = 'w04'), 'should start when the machine frees up';
  assert b.start_time > now(), 'should start in the future';
  assert (select status from public.machines where id = 'w04') = 'in_use', 'machine is still in use until then';
end;
$$;
select test_support.pass('a busy machine can be reserved now only if it frees up within 15 minutes');
rollback;

begin;
select test_support.setup();
update public.laundromats set open_hour = 8, close_hour = 20;
do $$
begin
  perform test_support.as_user(test_support.alice());
  perform test_support.expect_error($q$select public.book_machine('w01', test_support.local_at(1, 7))$q$, 'slot_taken');
  perform test_support.expect_error($q$select public.book_machine('w01', test_support.local_at(1, 19, 30))$q$, 'slot_taken');
  perform public.book_machine('w01', test_support.local_at(1, 19));
end;
$$;
select test_support.pass('bookings must fall inside opening hours, and the whole cycle must fit');
rollback;

begin;
select test_support.setup();
do $$
begin
  perform test_support.as_user(test_support.alice());
  perform test_support.expect_error($q$select public.book_machine('w01', now() - interval '10 minutes')$q$, 'slot_taken');
  perform public.book_machine('w01', test_support.local_at(2, 10));
  perform test_support.expect_error($q$select public.book_machine('w03', test_support.local_at(3, 10))$q$, 'slot_taken');
end;
$$;
select test_support.pass('bookings in the past or more than two days ahead are refused');
rollback;

begin;
select test_support.setup();
do $$
declare
  n int;
  early timestamptz;
  late timestamptz;
begin
  perform test_support.as_user(test_support.alice());
  select count(*) into n from public.get_slots('w01', 0);
  assert n > 10, 'expected a day of slots, got ' || n;
  assert not exists (select 1 from public.get_slots('w01', 0) s where s <= now()), 'slots must be in the future';
  assert not exists (select 1 from public.get_slots('w01', 0) s
                     where extract(minute from s at time zone test_support.midday_zone())::int % 30 <> 0), 'slots must be on the half hour';
  assert (select count(*) from public.get_slots('w01', 3)) = 0, 'no slots beyond two days ahead';
  assert (select count(*) from public.get_slots('w01', -1)) = 0, 'no slots in the past';
  assert (select count(*) from public.get_slots('nope', 0)) = 0, 'no slots for an unknown machine';

  perform public.book_machine('w01', test_support.local_at(1, 10));
  assert not exists (select 1 from public.get_slots('w01', 1) s where s = test_support.local_at(1, 9, 30)), '09:30 runs into the booking';
  assert not exists (select 1 from public.get_slots('w01', 1) s where s = test_support.local_at(1, 10)), '10:00 is taken';
  assert not exists (select 1 from public.get_slots('w01', 1) s where s = test_support.local_at(1, 10, 30)), '10:30 runs into the booking';
  assert exists (select 1 from public.get_slots('w01', 1) s where s = test_support.local_at(1, 9)), '09:00 is free';
  assert exists (select 1 from public.get_slots('w01', 1) s where s = test_support.local_at(1, 11)), '11:00 is free';
end;
$$;
select test_support.pass('get_slots lists free half-hour starts and leaves out taken ones');
rollback;

begin;
select test_support.setup();
do $$
declare
  b public.bookings;
begin
  perform test_support.as_user(test_support.alice());
  b := public.book_machine('w01', test_support.local_at(1, 10));
  perform test_support.expect_error(format('select public.can_check_in(%L)', b.id), 'not_ready');
end;
$$;
select test_support.pass('cannot check in before the start time');
rollback;

begin;
select test_support.setup();
do $$
declare
  booking_id text;
begin
  -- The previous user is still at the machine for 3 more minutes
  perform test_support.set_machine('w01', 'in_use', now() + interval '3 minutes');
  booking_id := test_support.add_booking(test_support.alice(), 'w01', now() - interval '1 minute', 'confirmed', now() + interval '9 minutes');

  perform test_support.as_user(test_support.alice());
  perform test_support.expect_error(format('select public.can_check_in(%L)', booking_id), 'machine_busy');
end;
$$;
select test_support.pass('cannot check in while the previous user is still at the machine');
rollback;

begin;
select test_support.setup();
do $$
declare
  b public.bookings;
  checked public.bookings;
  m public.machines;
begin
  perform test_support.as_user(test_support.alice());
  b := public.book_machine('w01', null);
  b := public.can_check_in(b.id);

  -- Bob cannot check in, or learn about, Alice's booking
  perform test_support.as_user(test_support.bob());
  perform test_support.expect_error(format('select public.can_check_in(%L)', b.id), 'not_ready');
  perform test_support.expect_error(format('select public.cancel_booking(%L)', b.id), 'not_found');

  -- The server starts the cycle once the payment is confirmed
  perform test_support.as_service();
  checked := public.check_in(b.id, 'pay_123');
  reset role;
  assert checked.status = 'in_progress', 'status was ' || checked.status;
  assert checked.hold_expires_at is null, 'hold should be cleared';
  assert checked.payment_id = 'pay_123', 'payment id was not saved';
  assert checked.end_time = now() + interval '36 minutes', 'cycle should last 36 minutes';
  select * into m from public.machines where id = 'w01';
  assert m.status = 'in_use' and m.available_at = checked.end_time, 'machine should be in use until the cycle ends';

  -- It cannot be checked in twice, or cancelled for free once it is running
  perform test_support.as_service();
  perform test_support.expect_error(format('select public.check_in(%L, %L)', b.id, 'again'), 'not_ready');
  perform test_support.as_user(test_support.alice());
  perform test_support.expect_error(format('select public.cancel_booking(%L)', b.id), 'not_found');
end;
$$;
select test_support.pass('check-in starts the cycle, only for the owner, and only once');
rollback;

begin;
select test_support.setup();
do $$
declare
  b public.bookings;
begin
  perform test_support.as_user(test_support.alice());
  b := public.book_machine('w01', null);
  perform public.cancel_booking(b.id);
  reset role;
  assert (select status from public.bookings where id = b.id) = 'cancelled', 'booking should be cancelled';
  assert (select status from public.machines where id = 'w01') = 'available', 'machine should be free again';
end;
$$;
select test_support.pass('cancelling a reservation is free and releases the machine');
rollback;
