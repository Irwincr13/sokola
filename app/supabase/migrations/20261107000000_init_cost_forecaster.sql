-- Sokola cost forecaster: initial schema
-- Money is stored as integer cents (ZAR). Every user-owned row carries owner_id
-- so RLS is a single owner_id = auth.uid() check; composite FKs on
-- (parent_id, owner_id) prevent attaching rows to another user's property.

-- ───────────────────────── Enums ─────────────────────────

create type public.title_type as enum ('freehold', 'sectional');

create type public.cost_category as enum (
  'levy', 'special_levy', 'rates', 'electricity', 'water_sanitation',
  'refuse', 'insurance_building', 'insurance_contents',
  'insurance_life_bond', 'maintenance', 'security', 'other'
);

create type public.cost_frequency as enum ('monthly', 'quarterly', 'annual', 'once');

create type public.rate_type as enum ('prime_linked', 'fixed');

-- ───────────────────────── Tables ─────────────────────────

create table public.profiles (
  id           uuid primary key references auth.users on delete cascade,
  display_name text,
  created_at   timestamptz not null default now()
);

create table public.properties (
  id                   uuid primary key default gen_random_uuid(),
  owner_id             uuid not null default auth.uid() references auth.users on delete cascade,
  name                 text not null,
  title_type           public.title_type not null,
  municipality         text,
  purchase_price_cents bigint check (purchase_price_cents >= 0),
  transfer_date        date,
  created_at           timestamptz not null default now(),
  unique (id, owner_id)
);

create table public.bonds (
  id              uuid primary key default gen_random_uuid(),
  property_id     uuid not null,
  owner_id        uuid not null default auth.uid(),
  lender          text,
  principal_cents bigint not null check (principal_cents > 0),
  rate_type       public.rate_type not null,
  margin_pct      numeric(5,2),
  fixed_rate_pct  numeric(5,2),
  term_months     int not null check (term_months between 12 and 360),
  start_date      date not null,
  created_at      timestamptz not null default now(),
  foreign key (property_id, owner_id) references public.properties (id, owner_id) on delete cascade,
  check (
    (rate_type = 'prime_linked' and margin_pct is not null)
    or (rate_type = 'fixed' and fixed_rate_pct is not null)
  )
);

create table public.cost_items (
  id               uuid primary key default gen_random_uuid(),
  property_id      uuid not null,
  owner_id         uuid not null default auth.uid(),
  category         public.cost_category not null,
  label            text not null,
  amount_cents     bigint not null check (amount_cents >= 0),
  frequency        public.cost_frequency not null,
  start_date       date not null,
  end_date         date,
  escalation_pct   numeric(5,2) not null default 0,
  escalation_month smallint check (escalation_month between 1 and 12),
  is_estimate      boolean not null default true,
  notes            text,
  created_at       timestamptz not null default now(),
  foreign key (property_id, owner_id) references public.properties (id, owner_id) on delete cascade,
  check (end_date is null or end_date >= start_date),
  unique (id, owner_id)
);

create table public.actuals (
  id                   uuid primary key default gen_random_uuid(),
  cost_item_id         uuid not null,
  owner_id             uuid not null default auth.uid(),
  period_month         date not null check (extract(day from period_month) = 1),
  amount_cents         bigint not null check (amount_cents >= 0),
  is_estimated_reading boolean not null default false,
  created_at           timestamptz not null default now(),
  foreign key (cost_item_id, owner_id) references public.cost_items (id, owner_id) on delete cascade,
  unique (cost_item_id, period_month)
);

-- Public reference data (SARB prime lending rate history). Written by service_role only.
create table public.prime_rates (
  effective_date date primary key,
  rate_pct       numeric(5,2) not null
);

-- ───────────────────────── Indexes ─────────────────────────

create index properties_owner_id_idx  on public.properties (owner_id);
create index bonds_property_id_idx    on public.bonds (property_id);
create index bonds_owner_id_idx       on public.bonds (owner_id);
create index cost_items_property_idx  on public.cost_items (property_id);
create index cost_items_owner_id_idx  on public.cost_items (owner_id);
create index actuals_owner_id_idx     on public.actuals (owner_id);
-- actuals (cost_item_id, period_month) is covered by its unique constraint

-- ───────────────────────── Profile on signup ─────────────────────────

create function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ───────────────────────── Data API grants ─────────────────────────
-- Explicit grants so the project can run with "Automatically expose new tables"
-- turned off. anon gets nothing; RLS below further restricts authenticated.

grant select, update                 on public.profiles    to authenticated;
grant select, insert, update, delete on public.properties  to authenticated;
grant select, insert, update, delete on public.bonds       to authenticated;
grant select, insert, update, delete on public.cost_items  to authenticated;
grant select, insert, update, delete on public.actuals     to authenticated;
grant select                         on public.prime_rates to authenticated;

-- ───────────────────────── Row level security ─────────────────────────

alter table public.profiles    enable row level security;
alter table public.properties  enable row level security;
alter table public.bonds       enable row level security;
alter table public.cost_items  enable row level security;
alter table public.actuals     enable row level security;
alter table public.prime_rates enable row level security;

-- profiles: own row only; inserts happen via the trigger above
create policy "profiles: owner select" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy "profiles: owner update" on public.profiles
  for update to authenticated
  using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

-- properties
create policy "properties: owner select" on public.properties
  for select to authenticated using ((select auth.uid()) = owner_id);
create policy "properties: owner insert" on public.properties
  for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy "properties: owner update" on public.properties
  for update to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy "properties: owner delete" on public.properties
  for delete to authenticated using ((select auth.uid()) = owner_id);

-- bonds
create policy "bonds: owner select" on public.bonds
  for select to authenticated using ((select auth.uid()) = owner_id);
create policy "bonds: owner insert" on public.bonds
  for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy "bonds: owner update" on public.bonds
  for update to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy "bonds: owner delete" on public.bonds
  for delete to authenticated using ((select auth.uid()) = owner_id);

-- cost_items
create policy "cost_items: owner select" on public.cost_items
  for select to authenticated using ((select auth.uid()) = owner_id);
create policy "cost_items: owner insert" on public.cost_items
  for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy "cost_items: owner update" on public.cost_items
  for update to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy "cost_items: owner delete" on public.cost_items
  for delete to authenticated using ((select auth.uid()) = owner_id);

-- actuals
create policy "actuals: owner select" on public.actuals
  for select to authenticated using ((select auth.uid()) = owner_id);
create policy "actuals: owner insert" on public.actuals
  for insert to authenticated with check ((select auth.uid()) = owner_id);
create policy "actuals: owner update" on public.actuals
  for update to authenticated
  using ((select auth.uid()) = owner_id) with check ((select auth.uid()) = owner_id);
create policy "actuals: owner delete" on public.actuals
  for delete to authenticated using ((select auth.uid()) = owner_id);

-- prime_rates: readable by any signed-in user; no write policies
create policy "prime_rates: authenticated read" on public.prime_rates
  for select to authenticated using (true);
