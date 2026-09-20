# Deploying the "Admin creates users" server function

Admin directly creating a Student/Teacher login (username + password) needs
Supabase's **service-role key**, which must never sit inside the website's
code (anyone could open dev tools and steal full database access). So this
one operation runs on a small server-side function instead — Supabase calls
these **Edge Functions**, and they're included in the free tier.

You only set this up once per project.

## 1. Install the Supabase CLI

```bash
npm install -g supabase
```

(Or see https://supabase.com/docs/guides/cli for other install methods —
Homebrew, Scoop, etc.)

## 2. Log in and link this project

From inside this project folder (the one containing the `supabase/` folder):

```bash
supabase login
supabase link --project-ref YOUR_PROJECT_REF
```

`YOUR_PROJECT_REF` is the short id in your Supabase project's URL:
`https://YOUR_PROJECT_REF.supabase.co`

## 3. Deploy the functions

```bash
supabase functions deploy admin-create-user
supabase functions deploy create-workspace
```

`create-workspace` is what powers the "Setting up your college for the
first time?" link on the login screen — it creates a Department+Year
workspace and makes the person filling the form its Admin, in one step
(no manual SQL needed anymore).

That's it — you do **not** need to set any secrets by hand. Supabase
automatically gives every Edge Function `SUPABASE_URL`, `SUPABASE_ANON_KEY`
and `SUPABASE_SERVICE_ROLE_KEY` already, which is exactly what this
function uses.

## 4. Run the schema (if you haven't already)

Run the updated `supabase-schema.sql` in the Supabase SQL Editor — it
already contains everything this function needs (the `profiles` table,
the auto-profile trigger, and the RLS policies).

## 5. Test it

1. Open the app, sign up your own account (Sign Up screen), pick your
   Department + Year.
2. In the Supabase SQL Editor, run the one-time bootstrap block at the
   bottom of `supabase-schema.sql` (fill in your email) to make yourself
   Admin.
3. Sign in again as Admin → go to **Admin Control Center** → **+ Student**
   or **+ Teacher** → fill in a username and password → **Create**.
4. Share that username + password with the student/teacher — they sign
   in with it directly, from any device.

## Troubleshooting

- **"Could not reach the account-creation server function"** — the
  function isn't deployed yet, or `supabase-config.js` has the wrong
  project URL. Re-check step 3 and your `config.js`.
- **"Only an Admin can create accounts."** — the signed-in account's
  `role` in the `profiles` table isn't `admin` yet. Re-run the bootstrap
  block from step 5.2 with the correct email.
- **"That username is already taken."** — usernames are unique across
  the whole project (not just one workspace/Department+Year).
