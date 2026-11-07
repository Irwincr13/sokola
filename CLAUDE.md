# Sokola

Home-ownership companion for South African homeowners: real cost of owning (bond, levies, rates, insurance, utilities, maintenance), document/warranty tracking, sectional-title specifics. Domain: sokola.co.za.

## Repo layout

- `index.html`, `vercel.json` (root) — **live marketing landing page** (static, waitlist via Tally). Deployed by its own Vercel project. Don't move or rebuild it into the app.
- `app/` — the product: Vite + React + TypeScript + Supabase. Deployed as a **separate** Vercel project with Root Directory = `app`. Lives in a subfolder because Vite needs its own root `index.html`.
  - `src/lib/supabase.ts` — single Supabase client; validates env on startup.
  - `src/auth/` — `AuthProvider` (session state), `useAuth` (hook + context; separate file for fast-refresh), `ProtectedRoute` (redirects to `/login`).
  - `src/pages/` — `Login` (email/password sign-in + sign-up), `Dashboard` (protected placeholder).
  - `supabase/migrations/` — SQL migrations, the source of truth for the schema.
  - `vercel.json` — SPA rewrite to `index.html`.

## Commands (run in `app/`)

- `npm run dev` — local dev at http://localhost:5173 (restart after changing env files)
- `npm run build` — `tsc -b && vite build`; must pass before committing
- `npm run lint` — oxlint

## Environment

`app/.env.local` (git-ignored; template in `app/.env.example`):

- `VITE_SUPABASE_URL` — `https://<ref>.supabase.co`
- `VITE_SUPABASE_ANON_KEY` — the **publishable** key (`sb_publishable_…`)

Anything prefixed `VITE_` is bundled into browser JS. **Never put an `sb_secret_` / service-role key or the DB password in a `VITE_` var** — it bypasses RLS. `supabase.ts` throws if it sees one.

Supabase project: `sokola-dev` (Europe region; no African region available). Email sign-ups enabled; "Automatically expose new tables" is **off**, so every new table needs explicit grants.

## Database conventions

- Money is `bigint` cents in ZAR (`*_cents`). Never floats.
- Every user-owned table has `owner_id uuid not null default auth.uid()`.
- Child tables reference parents with a composite FK `(parent_id, owner_id)` → `(id, owner_id)` so rows can't be attached to another user's data.
- RLS enabled on every table. Owner policies use `(select auth.uid()) = owner_id` for select/insert/update/delete, `to authenticated`. `anon` gets no grants or policies.
- Each new table needs, in its migration: explicit `grant`s to `authenticated`, `enable row level security`, and policies.
- Shared reference data (e.g. `prime_rates`) is read-only to `authenticated`; written by service_role only.
- Forecasts are computed client-side from inputs; don't store computed forecast rows.
- New migrations: `app/supabase/migrations/<YYYYMMDDHHMMSS>_<name>.sql`. Applied manually via the Supabase SQL Editor for now (no GitHub integration / CLI link yet) — never edit an already-applied migration; add a new one.

## Current schema (cost forecaster)

`profiles` (auto-created on signup), `properties` (freehold/sectional), `bonds` (prime-linked or fixed), `cost_items` (category, amount, frequency, escalation % and month), `actuals` (real monthly bills, flags municipal estimated readings), `prime_rates` (reference).

## Status

Scaffold + auth + schema only. No features built yet. Out of scope so far: warranty/asset tracker, shared property access, saved forecast scenarios.

## Style

UI tokens mirror the landing page (amber `#854F0B` primary, warm grays, Inter). Plain CSS in `src/index.css`; no UI framework yet.
