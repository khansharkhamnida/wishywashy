-- WishyWashy backend, part 1 of 4: tables.
--
-- Run this first. It only creates things, it does not insert any laundromats or machines (see seed.sql).
-- Money is stored as whole cents (price_minor), never as a decimal. Times are timestamptz (UTC inside, shown in the
-- laundromat's own time zone). Ids are text so the sample ids from the app (like 'w01') work, and real rows get a uuid.

create schema if not exists extensions;
create extension if not exists btree_gist with schema extensions;  -- lets the database refuse overlapping bookings

-- Internal helpers live here. This schema is not exposed to the app (see part 2).
create schema if not exists private;

-- ---------------------------------------------------------------------------------------------------------------
-- Rules. One row, so the numbers can change without an app release.
-- ---------------------------------------------------------------------------------------------------------------
create table public.booking_rules (
  id boolean primary key default true check (id),           -- always true, so there can only ever be one row
  hold_minutes int not null default 10 check (hold_minutes > 0),            -- check-in window after the start time
  max_wait_minutes int not null default 30 check (max_wait_minutes >= 0),   -- longest a booking waits for a busy machine
  finishing_soon_minutes int not null default 15 check (finishing_soon_minutes >= 0), -- "reserve now" on a busy machine
  slot_step_minutes int not null default 30 check (slot_step_minutes > 0),
  days_ahead int not null default 2 check (days_ahead >= 0),                -- today plus this many days
  max_upcoming int not null default 5 check (max_upcoming > 0)              -- per user
);
insert into public.booking_rules default values;

-- ---------------------------------------------------------------------------------------------------------------
-- Laundromats and machines
-- ---------------------------------------------------------------------------------------------------------------
create table public.laundromats (
  id text primary key default gen_random_uuid()::text,
  name text not null,
  address text not null,
  lat double precision not null,
  lng double precision not null,
  rating numeric(2, 1),
  country char(2) not null default 'SG',
  currency char(3) not null default 'SGD',
  timezone text not null default 'Asia/Singapore',
  open_hour int not null default 7 check (open_hour between 0 and 23),
  close_hour int not null default 23 check (close_hour between 1 and 24),
  is_partner boolean not null default true,
  check (close_hour > open_hour)
);

create table public.machines (
  id text primary key default gen_random_uuid()::text,
  laundromat_id text not null references public.laundromats (id) on delete cascade,
  type text not null check (type in ('washer', 'dryer')),
  label text not null,
  capacity_kg int not null check (capacity_kg > 0),
  status text not null default 'available' check (status in ('available', 'in_use', 'reserved', 'out_of_order')),
  price_minor int not null check (price_minor >= 0),
  cycle_minutes int not null check (cycle_minutes > 0),
  available_at timestamptz,                                  -- when a machine in use frees up, if known
  status_updated_at timestamptz not null default now()       -- lets the app say "updated 20 seconds ago"
);
create index machines_laundromat_idx on public.machines (laundromat_id);

-- ---------------------------------------------------------------------------------------------------------------
-- Users. Supabase keeps the login in auth.users. This table holds what the app shows.
-- ---------------------------------------------------------------------------------------------------------------
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  phone text,
  created_at timestamptz not null default now()
);

-- Every new sign-up gets a profile row automatically
create function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id,
          coalesce(new.raw_user_meta_data ->> 'display_name', nullif(split_part(coalesce(new.email, ''), '@', 1), '')));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- ---------------------------------------------------------------------------------------------------------------
-- Bookings
-- ---------------------------------------------------------------------------------------------------------------
create table public.bookings (
  id text primary key default gen_random_uuid()::text,
  user_id uuid not null references auth.users (id) on delete cascade,
  laundromat_id text not null references public.laundromats (id),
  machine_id text not null references public.machines (id),
  start_time timestamptz not null,
  end_time timestamptz not null,
  status text not null check (status in ('pending', 'confirmed', 'in_progress', 'completed', 'cancelled', 'expired')),
  hold_expires_at timestamptz,                               -- set while a reservation waits for check-in
  price_minor int not null check (price_minor >= 0),
  currency char(3) not null default 'SGD',
  payment_id text,
  created_at timestamptz not null default now(),
  check (end_time > start_time),
  during tstzrange generated always as (tstzrange(start_time, end_time, '[)')) stored,

  -- The database itself refuses two reservations on one machine at overlapping times, even if two people tap at the
  -- same instant. A booking that is already running is left out on purpose: a late previous user can run into the
  -- next booking, which then waits (see private.advance_bookings).
  constraint no_overlapping_reservations
    exclude using gist (machine_id with =, during with &&)
    where (status in ('pending', 'confirmed'))
);
create index bookings_user_idx on public.bookings (user_id, status);
create index bookings_machine_idx on public.bookings (machine_id, status);
