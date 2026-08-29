-- Run this once in Supabase: Dashboard → SQL Editor → New query → paste → Run.
--
-- This creates ONE shared row that holds the entire Charter Management
-- System's data (all charter files, feedback, settings — everything that
-- used to live in your browser's local storage). Both you and your
-- colleague log in with your own account, but you both read and write
-- this SAME row, so you're always looking at the same data.

create table if not exists workspace (
  id text primary key default 'default',
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz not null default now()
);

-- Seed the one shared row (safe to run even if it already exists).
insert into workspace (id, data)
values ('default', '{}'::jsonb)
on conflict (id) do nothing;

-- Row Level Security: only people who are logged in (via Supabase Auth)
-- can read or write this row at all — nothing is public.
alter table workspace enable row level security;

create policy "Logged-in users can read the workspace"
  on workspace for select
  to authenticated
  using (true);

create policy "Logged-in users can update the workspace"
  on workspace for update
  to authenticated
  using (true)
  with check (true);

-- Automatically keep updated_at current on every save.
create or replace function set_updated_at()
returns trigger as $$
begin
  new.updated_at = now();
  return new;
end;
$$ language plpgsql;

drop trigger if exists workspace_set_updated_at on workspace;
create trigger workspace_set_updated_at
  before update on workspace
  for each row
  execute function set_updated_at();

-- ---------------------------------------------------------------------
-- AFTER running this, create the two logins:
-- Supabase Dashboard → Authentication → Users → Add user
--   - your email + a password
--   - your colleague's email + a password
-- (Email confirmation can be turned off in Authentication → Providers →
-- Email → "Confirm email" if you'd rather they not need to click a
-- confirmation link the first time.)
-- ---------------------------------------------------------------------
