-- Security: who can see and do what. The tests act as a signed-in user (Alice or Bob), a signed-out visitor
-- (anon) and the server (service_role), exactly as the three Supabase API roles would.

begin;
select test_support.setup();
do $$
begin
  perform test_support.add_booking(test_support.alice(), 'w01', test_support.local_at(1, 10), 'confirmed', now());
  -- Overlaps Alice's booking on the same machine: the database itself refuses it (SQLSTATE 23P01)
  perform test_support.expect_error(
    $q$select test_support.add_booking(test_support.bob(), 'w01', test_support.local_at(1, 10, 10), 'confirmed', now())$q$, '23P01');
  -- A cycle already running is allowed to overlap a later reservation (the reservation waits)
  perform test_support.add_booking(test_support.bob(), 'w01', test_support.local_at(1, 10, 10), 'in_progress');
end;
$$;
select test_support.pass('the database refuses overlapping reservations even when the rules are bypassed');
rollback;

begin;
select test_support.setup();
do $$
declare
  n int;
begin
  perform test_support.add_booking(test_support.alice(), 'w01', test_support.local_at(1, 10), 'confirmed', now());
  perform test_support.add_booking(test_support.bob(), 'w03', test_support.local_at(1, 10), 'confirmed', now());

  perform test_support.as_user(test_support.alice());
  select count(*) into n from public.bookings;
  assert n = 1, 'Alice should see 1 booking, saw ' || n;
  assert (select user_id from public.bookings) = test_support.alice(), 'Alice should only see her own';

  perform test_support.as_user(test_support.bob());
  assert (select user_id from public.bookings) = test_support.bob(), 'Bob should only see his own';

  perform test_support.as_anon();
  perform test_support.expect_error('select count(*) from public.bookings', '42501');
end;
$$;
select test_support.pass('a user sees only their own bookings, a visitor sees none');
rollback;

begin;
select test_support.setup();
do $$
declare
  changed int;
begin
  perform test_support.as_user(test_support.alice());

  -- Nothing can be written to the tables directly, only through the functions
  perform test_support.expect_error(
    $q$insert into public.bookings (user_id, laundromat_id, machine_id, start_time, end_time, status, price_minor)
       values (test_support.alice(), 'l1', 'w01', now(), now() + interval '1 hour', 'confirmed', 0)$q$, '42501');
  perform test_support.expect_error($q$update public.machines set status = 'available'$q$, '42501');
  perform test_support.expect_error($q$update public.bookings set status = 'completed'$q$, '42501');
  perform test_support.expect_error($q$delete from public.laundromats$q$, '42501');
  perform test_support.expect_error($q$update public.booking_rules set max_upcoming = 1000$q$, '42501');

  -- A user can change their own display name and phone, and nothing else
  update public.profiles set display_name = 'Alice A' where id = test_support.alice();
  get diagnostics changed = row_count;
  assert changed = 1, 'Alice should be able to rename herself';

  update public.profiles set display_name = 'Hacked' where id = test_support.bob();
  get diagnostics changed = row_count;
  assert changed = 0, 'Alice must not change Bob''s profile';

  perform test_support.expect_error($q$update public.profiles set created_at = now()$q$, '42501');
end;
$$;
select test_support.pass('apps cannot write tables directly, and users can edit only their own profile name and phone');
rollback;

begin;
select test_support.setup();
do $$
begin
  perform test_support.as_anon();
  assert (select count(*) from public.laundromats) = 4, 'visitors can browse laundromats';
  assert (select count(*) from public.machines) = 39, 'visitors can browse machines';
  assert public.get_now_start('w01') is not null, 'visitors can see when a machine could start';
  assert (select count(*) from public.get_slots('w01', 0)) > 10, 'visitors can see free slots';
  perform test_support.expect_error($q$select public.book_machine('w01', null)$q$, '42501');
  perform test_support.expect_error($q$select public.cancel_booking('x')$q$, '42501');
end;
$$;
select test_support.pass('a signed-out visitor can browse but not book');
rollback;

begin;
select test_support.setup();
do $$
begin
  perform test_support.as_user(test_support.alice());
  -- Only the server (after a confirmed payment) may start a cycle, and internal helpers are hidden from apps
  perform test_support.expect_error($q$select public.check_in('x', 'y')$q$, '42501');
  perform test_support.expect_error($q$select private.advance_bookings()$q$, '42501');
  perform test_support.expect_error($q$select private.can_book(null, now())$q$, '42501');
end;
$$;
select test_support.pass('apps cannot call check_in or the internal helpers');
rollback;

begin;
do $$
begin
  -- No signed-in user: running as the database owner without a login
  perform test_support.expect_error($q$select public.book_machine('w01', null)$q$, 'not_signed_in');
  perform test_support.expect_error($q$select public.cancel_booking('x')$q$, 'not_signed_in');
  perform test_support.expect_error($q$select public.can_check_in('x')$q$, 'not_signed_in');
end;
$$;
select test_support.pass('functions refuse to run without a signed-in user');
rollback;

begin;
do $$
begin
  assert (select count(*) from public.profiles) = 2, 'every new user should get a profile';
  assert (select display_name from public.profiles where id = test_support.alice()) = 'alice', 'name should come from the email';
end;
$$;
select test_support.pass('signing up creates a profile automatically');
rollback;

begin;
do $$
begin
  assert (select count(*) from public.booking_rules) = 1, 'there is exactly one rules row';
  perform test_support.expect_error($q$insert into public.booking_rules (id) values (false)$q$, '23514');
  perform test_support.expect_error($q$insert into public.booking_rules (id) values (true)$q$, '23505');
end;
$$;
select test_support.pass('there can only ever be one rules row');
rollback;
