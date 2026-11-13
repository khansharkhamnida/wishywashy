# Login and register: what was built

Written 12 Nov 2026. Login and register are built and **off by default**. The app opens straight on the tab bar,
exactly as before, unless you turn on live mode.

## In plain words

- **Auth** means "who is using the app". **Supabase Auth** is the service that stores emails and passwords safely, so
  we never keep a password ourselves.
- When someone signs up, Supabase makes a row in `auth.users`. A trigger (`on_auth_user_created`, in
  `backend/supabase/migrations/20261111100000_schema.sql`) then adds a row to `profiles`, using the `display_name`
  the app sends.
- After sign-in, Supabase gives the phone two tokens (long secret strings). The app keeps them in the **Keychain**
  (the iPhone's safe), never in `UserDefaults`.
- Screens talk only to the `AuthService` protocol. Two versions exist:
  `SampleAuthService` (default, always the sample user, no screens) and `SupabaseAuthService` (live mode).

## What is in the code

| Piece | Where |
|---|---|
| Switch and settings (`AppConfig`) | `ios/wishywashy/App/AppConfig.swift` |
| Protocol, errors, session model | `ios/wishywashy/Services/Auth/AuthService.swift` |
| Sample version (default) | `ios/wishywashy/Services/Auth/SampleAuthService.swift` |
| Supabase version (plain `URLSession`, no package) | `ios/wishywashy/Services/Auth/SupabaseAuthService.swift` |
| Keychain storage | `ios/wishywashy/Services/Auth/KeychainStore.swift` |
| Login and Register (VIPER) | `ios/wishywashy/Modules/Auth/` |
| Form rules, friendly messages | `Modules/Auth/AuthValidation.swift`, `AuthMessages.swift` |
| Sign Out row in Profile (live mode only) | `Modules/Profile/` |
| `Session.user` = the signed-in user | `ios/wishywashy/Services/Session.swift` |
| Chooses the root screen | `ios/wishywashy/App/SceneDelegate.swift` |
| Tests | `ios/wishywashyTests/AuthTests.swift` |

**No Swift package was added.** The Supabase Swift SDK is optional. The Auth REST API is small, and a plain
`URLSession` keeps the project free of dependencies. If you want the SDK later, only `SupabaseAuthService.swift` needs
to change, because the screens only know `AuthService`. Ask before adding it.

How it behaves:

- **Sample mode (default):** no login, no Sign Out row, fixed user "Shofia". Nothing is written to the Keychain.
- **Live mode:** a splash screen shows while the saved session is restored, then the tab bar (signed in) or Login
  (signed out). Signing in or out swaps the screen by itself.
- **Login:** email and password, "Forgot password?" (sends Supabase's reset email), "Create an account".
- **Register:** display name, email, password (at least 8 characters), confirm password. Errors show under each field
  after you leave it, and again on submit. Server errors show as short friendly sentences, never the raw message.
- **If the email must be confirmed** (see step 4 below), Register shows "check your email" instead of signing in.
- **Offline or server trouble at launch** keeps you signed in with the saved session. A refused refresh token signs
  you out.
- In live mode, bookings are still **sample data**, kept in a separate store for each signed-in user so accounts never
  mix. Real bookings need the booking service from the plan (step 5), which is not built.

## Turn it on (you need a Supabase project first)

There is no Supabase project yet. If you have not made one, follow **Part A** of
[backend/README.md](../../backend/README.md) (project, SQL files, seed). Then:

1. **Find the two values.** Supabase dashboard > your project > the gear icon **Project Settings** > **API Keys**
   (older dashboards: **API**). Copy the **Project URL** (`https://YOUR-PROJECT-REF.supabase.co`) and the **anon** or
   **publishable** key. Never copy the `service_role` or "secret" key.
2. **Email confirmation, for testing.** Dashboard > **Authentication** > **Sign In / Providers** (older: **Providers**)
   > **Email**. Hosted projects require users to confirm their email by default
   ([Supabase docs](https://supabase.com/docs/guides/auth/passwords), checked 12 Nov 2026). While testing, either:
   - switch **Confirm email** off (new users can sign in at once), or
   - leave it on, but note the built-in mail sender **only delivers to your Supabase team members' addresses and is
     limited to about 2 emails per hour**
     ([Supabase docs](https://supabase.com/docs/guides/auth/auth-smtp), checked 12 Nov 2026). Real users later need
     a custom SMTP service.
   Dashboard menu names change from time to time, so look for the closest match.
3. **Put the values in Xcode, not in the repo.** Xcode > **Product** > **Scheme** > **Edit Scheme...** > **Run** >
   **Arguments** > under **Arguments Passed On Launch** click **+** and add, as one line:

   ```
   -dataSource live -supabaseURL https://YOUR-PROJECT-REF.supabase.co -supabaseAnonKey YOUR-ANON-OR-PUBLISHABLE-KEY
   ```

   Scheme edits that are not "Shared" stay in your own `xcuserdata` folder, which `.gitignore` already skips.
   Do not tick **Shared** for this scheme.
4. Run the app. You should see **Welcome back!**. Tap **Create an account**, register, then open Supabase >
   **Table Editor** > `profiles`: a row with your display name should exist.
5. Go to **Profile** and tap **Sign Out**.

To go back to sample mode, untick or delete those launch arguments.

If you pass `-dataSource live` without the URL and key, the login screen still appears, but signing in shows
"Live mode needs -supabaseURL and -supabaseAnonKey launch arguments." Nothing is sent.

## How it was tested

Run on 12 Nov 2026 with
(`xcodebuild test ... -destination 'platform=iOS Simulator,name=iPhone 17'`): the build succeeded and all tests
passed, including the 18 existing booking tests and the new `AuthTests.swift`.

The new tests use a **fake network and a fake Keychain**, so they prove how the app handles Supabase's answers
(sign in, sign up with and without confirmation, taken email, wrong password, token refresh, offline, sign out,
missing settings, sample mode default, form rules, one friendly message per error). They do **not** prove that a real
Supabase project accepts the requests.

Also looked at by eye in the iPhone 17 simulator: Login and Register in light and dark mode, and that the app
still opens on the Home tab bar in sample mode. The screenshots were deleted afterwards.

## Not verified (be careful)

- **Nothing was run against a real Supabase project.** The response shapes are written from Supabase's documented
  Auth API ([docs](https://supabase.com/docs/reference/auth)) and the tests. The first real sign-up is the real test.
- **The Sign Out row was not seen on screen.** It only appears in live mode with a signed-in user, which needs a
  real project. The code builds and the logic is simple, but check it yourself.
- **Error states on screen** (red field text, banner, loading button) were not captured. The rules are unit tested.
- Keychain on a **real iPhone** was not tried. The Keychain code was only exercised through a fake in tests.
- The **confirmation-email link** opens a web page (your project's Site URL), not the app. The app has no deep
  link yet, so after tapping it the user goes back to the app and signs in. The password-reset link works the
  same way, and there is **no in-app "choose a new password" screen yet**.
- VoiceOver, Dynamic Type at the largest sizes, and iPad layout were not checked.

## Not built yet (decisions for you)

- **Phone number with SMS code.** The plan says this is the main way in for Singapore and the Philippines. Email and
  password is the easy first step. SMS costs money and needs a provider (see the plan, sections 5 and 12).
- **Sign in with Apple.** Needed on iOS if you ever add Google or Facebook sign-in.
- **Delete account.** Apple requires it inside the app once accounts exist. It needs a server function, because
  deleting an auth user needs the service key (plan, section 12, step 4).
- **Real bookings per user** (`SupabaseBookingService`). `AuthService.validAccessToken()` is already there for it.
- **Guest browsing** (look around without an account).
- **Terms and privacy consent** at sign-up.

## Safety notes

- No key, URL, token or password is in the repo. The tests use placeholders only.
- The anon (publishable) key is meant to be inside an app, and it is only safe because row-level security is on
  (it is, in `backend/supabase/migrations/20261111100100_security.sql`). The `service_role` key must never go in the
  app.
- The app never logs emails, passwords or tokens.
