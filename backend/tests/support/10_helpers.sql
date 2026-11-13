-- Helpers for the tests. Loaded after the migrations and the seed.

create schema test_support;
grant usage on schema test_support to anon, authenticated, service_role;

-- Two fixed users, created once. The sign-up trigger gives each of them a profile.
insert into auth.users (id, email) values
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'alice@example.test'),
  ('bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb', 'bob@example.test');

create function test_support.alice() returns uuid language sql immutable as $$ select 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'::uuid $$;
create function test_support.bob()   returns uuid language sql immutable as $$ select 'bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb'::uuid $$;

-- Act as a signed-in user, a visitor, or the server, until the end of the transaction or until "reset role"
create function test_support.as_user(p_user uuid) returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('sub', p_user, 'role', 'authenticated')::text, true);
  perform set_config('role', 'authenticated', true);
end;
$$;

create function test_support.as_anon() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'anon')::text, true);
  perform set_config('role', 'anon', true);
end;
$$;

create function test_support.as_service() returns void language plpgsql as $$
begin
  perform set_config('request.jwt.claims', json_build_object('role', 'service_role')::text, true);
  perform set_config('role', 'service_role', true);
end;
$$;

-- A time zone in which it is about midday right now, so tests behave the same at any hour of the day
create function test_support.midday_zone() returns text language sql stable as $$
  select case when off = 0 then 'Etc/GMT' when off > 0 then 'Etc/GMT-' || off else 'Etc/GMT+' || (-off) end
  from (select 12 - extract(hour from now() at time zone 'UTC')::int as off) s
$$;

-- Open all day, in the midday zone
create function test_support.setup() returns void language sql as $$
  update public.laundromats set timezone = test_support.midday_zone(), open_hour = 0, close_hour = 24;
$$;

-- A moment on the local clock of the first laundromat: day_offset days from today at the given hour and minute
create function test_support.local_at(p_day_offset int, p_hour int, p_minute int default 0) returns timestamptz language sql stable as $$
  select (((now() at time zone l.timezone)::date + p_day_offset)::timestamp
          + make_interval(hours => p_hour, mins => p_minute)) at time zone l.timezone
  from public.laundromats l where l.id = 'l1'
$$;

-- Insert a booking directly, as the server would, to set up a situation
create function test_support.add_booking(
  p_user uuid, p_machine text, p_start timestamptz, p_status text, p_hold timestamptz default null
) returns text language plpgsql as $$
declare
  v_id text;
  m public.machines;
begin
  select * into m from public.machines where id = p_machine;
  insert into public.bookings (user_id, laundromat_id, machine_id, start_time, end_time, status, hold_expires_at, price_minor, currency)
  values (p_user, m.laundromat_id, m.id, p_start, p_start + make_interval(mins => m.cycle_minutes), p_status, p_hold, m.price_minor, 'SGD')
  returning id into v_id;
  return v_id;
end;
$$;

create function test_support.set_machine(p_machine text, p_status text, p_available_at timestamptz default null) returns void language sql as $$
  update public.machines set status = p_status, available_at = p_available_at where id = p_machine;
$$;

-- Run one statement and check that it fails with this message or SQLSTATE code
create function test_support.expect_error(p_sql text, p_expected text) returns void language plpgsql as $$
declare
  v_succeeded boolean := false;
begin
  begin
    execute p_sql;
    v_succeeded := true;
  exception when others then
    if sqlerrm <> p_expected and sqlstate <> p_expected then
      raise exception 'expected error "%" but got "%" (%)', p_expected, sqlerrm, sqlstate;
    end if;
  end;
  if v_succeeded then
    raise exception 'expected error "%" but the statement succeeded', p_expected;
  end if;
end;
$$;

create function test_support.pass(p_name text) returns void language plpgsql as $$
begin
  raise notice 'PASS: %', p_name;
end;
$$;

grant execute on all functions in schema test_support to public;
