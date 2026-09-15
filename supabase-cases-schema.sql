-- Run this once in Supabase: Dashboard → SQL Editor → New query → paste → Run.
--
-- Moves charter/sale files ("cases") OUT of the single shared `workspace`
-- row into their own table — one row per file. Before this, saving ANY
-- file rewrote the entire shared dataset in one go, so two people editing
-- two DIFFERENT files at the same time could silently overwrite each
-- other's work (last save wins, on everything). With one row per file,
-- saving file A only ever touches file A's row.
--
-- Nothing else moves: feedback, the fleet list, staff initials, and the
-- preference-list sync settings still live in `workspace` as before —
-- those change far less often and weren't the source of the problem.
--
-- The app detects this table automatically and migrates the existing
-- files out of `workspace.data.cases` into it the first time it loads
-- afterwards — no manual data copying needed. It keeps working exactly
-- as before (still using the old shared copy) until you run this script.

create table if not exists cases (
  id text primary key,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Row Level Security: only people logged in (via Supabase Auth) can read
-- or write case files at all — nothing is public. Any logged-in user can
-- read/write/delete any file, same trust model as the `workspace` table.
alter table cases enable row level security;

create policy "Logged-in users can read cases"
  on cases for select
  to authenticated
  using (true);

create policy "Logged-in users can insert cases"
  on cases for insert
  to authenticated
  with check (true);

create policy "Logged-in users can update cases"
  on cases for update
  to authenticated
  using (true)
  with check (true);

create policy "Logged-in users can delete cases"
  on cases for delete
  to authenticated
  using (true);

-- Keep updated_at current on every save (same helper function used by
-- workspace-schema.sql — safe to redeclare if this runs on its own).
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists cases_set_updated_at on cases;
create trigger cases_set_updated_at
  before update on cases
  for each row
  execute function set_updated_at();

-- ---------------------------------------------------------------------
-- AFTER running this script:
--
-- 1. Enable Realtime for this table so a saved file shows up live for
--    everyone else without a manual refresh: Dashboard → Database →
--    Replication → find "cases" → toggle it on (same place "workspace"
--    was already enabled).
--
-- 2. Just reload the app (on any device, logged in) — it detects the new
--    table, copies the existing files into it automatically, and starts
--    using it from then on. The old copy inside the `workspace` row is
--    left untouched (harmless, just unused) rather than deleted.
-- ---------------------------------------------------------------------
