# WishyWashy backend (Supabase)

This folder is the **backend**: the database and the booking rules that the app will call instead of running them on
the phone. It is written for someone who has never used Supabase. Follow Part A top to bottom and you will have a
working backend you can poke at from the Terminal, in about 30 minutes.

For where this fits, see [docs/dev/ARCHITECTURE.md](../docs/dev/ARCHITECTURE.md). The iOS app does not use this backend yet.
It still runs on sample data. Connecting it is Part E.

## What is in here

```
backend/
├── README.md                         this guide
├── package.json                      lets you run the tests with npm
├── supabase/
│   ├── migrations/                   the database, in four steps. Run them in order.
│   │   ├── 20261111100000_schema.sql      1. tables
│   │   ├── 20261111100100_security.sql    2. who can read and write what
│   │   ├── 20261111100200_functions.sql   3. the booking rules
│   │   └── 20261111100300_schedule.sql    4. a job that moves time forward every minute
│   ├── seed.sql                      the sample laundromats and machines (same as the iOS sample data)
│   └── dev_reset.sql                 DANGER: wipes everything, for starting again while learning
└── tests/                            32 automated checks of the rules and the security (Part C)
```

## Words you will meet

| Word | Meaning here |
|---|---|
| **Supabase** | A hosted service that gives you a Postgres database, sign-in, and an automatic web API for your tables |
| **Project** | One Supabase backend. You make one for development now, and later one for staging and one for production |
| **Postgres / SQL** | The database, and the language you talk to it in |
| **Table** | A spreadsheet-like list of rows, such as `machines` or `bookings` |
| **Function** | Code that runs inside the database. The booking rules are functions, so nobody can skip them |
| **RLS (row-level security)** | Rules that say which rows a person may see. With it on, Alice cannot read Bob's bookings |
| **anon key** (also called the publishable key) | The key the app carries. It is safe to ship **only because RLS is on** |
| **service_role key** (also called the secret key) | A master key that skips all the rules. **It never goes in the app or in git** |
| **Migration** | A SQL file that changes the database. Apply them in order and never edit one that you have already applied |

---

## Part A: first run in the dashboard

### A1. Make an account and a project

1. Go to [supabase.com](https://supabase.com) and sign up (signing in with GitHub is easiest).
2. Create an organization if it asks (any name, Free plan).
3. Click **New project** and fill in:
   - **Name:** `wishywashy-dev`
   - **Database password:** click generate, then **save it in a password manager now**. You cannot read it again later.
   - **Region:** Southeast Asia (Singapore)
4. Click create and wait about two minutes until the project dashboard appears.

Free projects can be paused after a period of inactivity, and you can resume them from the dashboard (verify the
current limits on supabase.com/pricing).

### A2. Find your URL and keys

Open **Project Settings** (the gear icon), then **API Keys** (older dashboards call this **API**). You need:

- **Project URL**, which looks like `https://abcdefghijkl.supabase.co`
- the **anon** key (or **publishable** key)

Do not copy the service_role key anywhere yet. Later in the Terminal you will store these two in environment
variables for that session only. Never put them in a file inside this repo.

### A3. Run the SQL

1. In the left menu click **SQL Editor**, then **New query**.
2. In VS Code open the first file below, select everything (Cmd+A), copy (Cmd+C).
3. Paste into the SQL Editor and click **Run**. You should see **Success. No rows returned**.
4. Repeat for each file, **in this order**:

| # | File | What it does |
|---|---|---|
| 1 | `supabase/migrations/20261111100000_schema.sql` | Creates the tables |
| 2 | `supabase/migrations/20261111100100_security.sql` | Turns on RLS and takes away every permission the app should not have |
| 3 | `supabase/migrations/20261111100200_functions.sql` | Creates the booking rules |
| 4 | `supabase/migrations/20261111100300_schedule.sql` | Schedules the minute-by-minute job (it prints a notice and does nothing until pg_cron is on, see A7) |
| 5 | `supabase/seed.sql` | Adds 4 laundromats and 39 machines |

If the editor warns that a table has no RLS after step 1, either choice is fine, because step 2 turns it on.

If something fails halfway, read the red error, then run `supabase/dev_reset.sql` (it wipes the WishyWashy tables,
which is fine while learning) and start again from step 1.

### A4. Look at what you built

- **Table Editor** (left menu): open `laundromats` and `machines`. You should see 4 laundromats and 39 machines.
  Each table should show that RLS is enabled.
- **Database > Functions**: you should see `book_machine`, `cancel_booking`, `can_check_in`, `check_in`,
  `get_slots` and `get_now_start`.
- **Advisors** (under Database, or in the left menu): run the Security Advisor. It should not report tables
  without RLS.

### A5. Make a test user

The app has sign-in screens now (see [docs/dev/AUTH_IMPLEMENTATION.md](../docs/dev/AUTH_IMPLEMENTATION.md)), but a hand-made user is still the quickest way to test the Terminal steps below:

1. **Authentication > Users > Add user > Create new user**.
2. Email `test@example.com`, a password you will remember, and tick **Auto Confirm User**.
3. Create it. Copy the user's **UID** if you want it later.
4. Open Table Editor > `profiles`: a row for that user was created automatically.

### A6. Try it from the Terminal

Everything the app will do, it will do through the same web API. Open Terminal and set the values for this session
(replace the three placeholders):

```bash
export SUPABASE_URL="https://YOUR-PROJECT.supabase.co"
export ANON_KEY="YOUR-ANON-OR-PUBLISHABLE-KEY"
export EMAIL="test@example.com"
export PASSWORD="the-password-you-chose"
```

**1. Browse as a signed-out visitor.** Anyone can read laundromats and machines:

```bash
curl -s "$SUPABASE_URL/rest/v1/machines?select=id,label,status,price_minor&laundromat_id=eq.l1&order=label" \
  -H "apikey: $ANON_KEY" | python3 -m json.tool
```

**2. Prove a visitor cannot read bookings.** You should get a "permission denied" error:

```bash
curl -s "$SUPABASE_URL/rest/v1/bookings?select=*" -H "apikey: $ANON_KEY"
```

**3. Sign in** and keep the token:

```bash
TOKEN=$(curl -s "$SUPABASE_URL/auth/v1/token?grant_type=password" \
  -H "apikey: $ANON_KEY" -H "Content-Type: application/json" \
  -d "{\"email\":\"$EMAIL\",\"password\":\"$PASSWORD\"}" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")
echo "${TOKEN:0:20}..."
```

**4. Ask when machine W04 could start** (it frees up in a few minutes, so it can be reserved now), and list
today's free slots for W01:

```bash
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/get_now_start" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"p_machine":"w04"}'

curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/get_slots" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"p_machine":"w01","p_day_offset":0}'
```

If these return `null` or `[]`, it may be outside opening hours (7 AM to 11 PM Singapore time). Try
`"p_day_offset":1` for tomorrow.

**5. Reserve W01 now:**

```bash
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/book_machine" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"p_machine":"w01"}' | python3 -m json.tool
```

You get back a booking with `"status": "confirmed"`. Copy its `id`. In the Table Editor, `bookings` now has a row and
the `w01` machine is `reserved`.

**6. Try to break the rules.** Run step 5 again for another machine and you should get an error saying
`already_holding`. Reserve a time that overlaps an existing booking and you should get `slot_taken`.

**7. See your bookings** (you see only your own):

```bash
curl -s "$SUPABASE_URL/rest/v1/bookings?select=id,machine_id,status,start_time,hold_expires_at" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN" | python3 -m json.tool
```

**8. Cancel it** (replace `BOOKING-ID`). The machine becomes available again:

```bash
curl -s -X POST "$SUPABASE_URL/rest/v1/rpc/cancel_booking" \
  -H "apikey: $ANON_KEY" -H "Authorization: Bearer $TOKEN" -H "Content-Type: application/json" \
  -d '{"p_booking":"BOOKING-ID"}'
```

**Check-in is different.** The app is not allowed to start a cycle, because that will only happen after a real
payment. To try it by hand, reserve a machine again, then in the **SQL Editor** run (this runs as the owner):

```sql
select public.check_in('BOOKING-ID', 'test-payment');
```

The booking becomes `in_progress` and the machine `in_use`. Later, the payment webhook will do this call with the
service_role key.

Error words the functions use, and the app messages they will map to:

| Error | Meaning |
|---|---|
| `machine_unavailable` | The machine cannot be reserved now |
| `already_holding` | You already have a reservation waiting for check-in |
| `slot_taken` | That time is taken, outside opening hours, in the past, or too far ahead |
| `too_many_bookings` | You already have 5 upcoming bookings |
| `not_ready` | It is not time to check in yet, or this is not your booking |
| `machine_busy` | The previous user is still at the machine |
| `not_found` | There is nothing to cancel |
| `not_signed_in` | No user is signed in |

### A7. Turn on the minute-by-minute job

Reservations expire, cycles finish and machines free up as time passes. Every function already catches up before it
does anything, so the backend works without this, but the job keeps the data right when nobody is calling it.

1. **Database > Extensions**, search for **pg_cron**, and switch it on.
2. In the SQL Editor run `supabase/migrations/20261111100300_schedule.sql` again. It should now print
   `Scheduled advance-bookings to run every minute.`
3. Check it: run `select * from cron.job;` and you should see one job called `advance-bookings`.

---

## Part B: how it works

- **Apps only read tables.** Row-level security lets everyone read laundromats and machines, and a signed-in user read
  their own bookings. Nothing else is allowed. The migration also takes away write permissions, so even a mistake in
  a policy cannot open a hole.
- **Writes go through functions.** `book_machine`, `cancel_booking` and `check_in` apply the rules, then change the
  tables. They run with the database's own permissions and use the **server's clock**, so a changed phone clock does
  nothing.
- **Time moves in one place.** `private.advance_bookings()` expires holds, completes cycles, frees machines and holds a
  machine for a booking whose start time has come. Every function calls it first, and the job calls it each minute.
  It is the server version of `LocalBookingService.advance()` in the iOS app.
- **A late previous user does not cost you your booking.** If someone is still on the machine when your booking starts,
  your check-in window starts when they finish, for up to 30 minutes of waiting.
- **Double booking is impossible.** The database has a constraint that refuses two reservations on one machine at
  overlapping times, even if two people tap at the same instant.
- **Rule numbers live in a table.** `booking_rules` holds the 10 minute window, the 15 minute limit and so on, so you
  can change them in the Table Editor without releasing an app.

The rules are the same ones as `ios/wishywashy/Services/Bookings/BookingRules.swift`, with one difference: the limit of
5 upcoming bookings and "one reservation waiting for check-in" are now **per user**, which the phone-only version could
not tell apart.

## Part C: run the automated tests

The tests check 32 things (the rules, the time-passing behaviour and the security). They start a throwaway Postgres,
apply the migrations and seed, and run every test. Nothing is installed on your machine, and nothing touches Supabase.

```bash
cd backend
npm install      # once
npm test
```

You should see a list of checkmarks ending with `All 32 tests passed.` Run it after changing any SQL file.

The tests pretend to be Supabase's sign-in and its three roles (`anon`, `authenticated`, `service_role`) with a small
stand-in in `tests/support/`. That stand-in refuses to run on a real Supabase database.

## Part D: working like a professional later (optional)

Pasting into the SQL Editor is fine for learning. Once you want a repeatable setup, use the Supabase CLI:

```bash
brew install supabase/tap/supabase
cd backend
supabase init                        # once, creates supabase/config.toml
supabase login
supabase link --project-ref YOUR-PROJECT-REF    # the ref is the first part of your project URL
supabase db push                     # applies any migration files the project does not have yet
```

Rules for changing the database from now on:

1. **Never edit a migration you have already applied.** Add a new file with a later timestamp, for example
   `supabase/migrations/20261112090000_add_currency_to_machines.sql`.
2. Run `npm test` before you apply anything.
3. `supabase db push` does not run `seed.sql` on a hosted project. Run the seed from the SQL Editor.
4. `supabase start` (needs Docker) runs a full copy of Supabase on your Mac, which is a safe place to experiment.
5. Make a separate staging project before you have real users, and apply every change there first.

## Part E: connecting the iOS app (not done yet)

Today the app calls `LocalBookingService`. To use this backend it needs:

1. `BookingService` made async, with a transport error for "no network".
2. A `SupabaseBookingService` that calls the functions above and the table reads, and maps the error words to
   `ReserveError` and `CheckInError`.
3. ~~Sign-in screens, and `Session.user` from the signed-in user.~~ Done, opt-in: see [docs/dev/AUTH_IMPLEMENTATION.md](../docs/dev/AUTH_IMPLEMENTATION.md).
4. Loading, error and offline states on each screen.
5. A switch so the sample mode keeps working.

The full plan is the **Supabase implementation guide** in
the Supabase implementation guide in the private product plan (`private/PRODUCT_AND_BACKEND_PLAN.md`, kept on the owner's Mac only).

## What is not built yet

- **Payments.** `check_in` is the call the payment webhook will make. The webhook, creating payments and refunds are
  Edge Functions (see section 9 of the plan).
- **QR check-in.** The app will send a signed token from the machine's QR code.
- **Staff and owners.** Roles, cash recording, and a dashboard.
- **Push notifications** and **machine integrations** (cloud APIs, retrofit controllers).
- **Different currencies and hours per country.** The columns exist on `laundromats` (`currency`, `timezone`,
  `open_hour`, `close_hour`). The app does not read them yet.
- **Sample bookings.** A booking belongs to a signed-in user, so there are none in the seed. Make some with
  `book_machine`.

## Safety checklist

- [ ] The service_role (secret) key is only in your password manager, never in the repo, a screenshot or a chat.
- [ ] Every table has RLS on (Advisors shows no warnings).
- [ ] The database password is saved somewhere safe.
- [ ] `.env` files are never committed (they are in `.gitignore`).
- [ ] You have a separate project for production before real users arrive, and a plan for backups.
