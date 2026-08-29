-- Run this once in Supabase: Dashboard → SQL Editor → New query → paste → Run.
-- Creates the table that stores client feedback, and locks it down so the
-- public form can only ADD entries, never read or change existing ones.

create table if not exists feedback (
  id uuid primary key default gen_random_uuid(),
  received_at timestamptz not null default now(),

  yacht_name text not null,
  charter_start_date date,
  charter_end_date date,
  cruising_area text,

  expectations smallint,             -- 1-5
  rating_yacht smallint,             -- 1-10
  rating_crew smallint,
  rating_service smallint,
  rating_communication smallint,
  rating_organisation smallint,
  rating_itinerary smallint,
  rating_food smallint,
  rating_watertoys smallint,
  rating_overall smallint,

  testimonial text,
  improvements text,
  would_return text,                 -- 'yes' | 'no'
  would_recommend text,              -- 'yes' | 'no'

  website text                       -- honeypot: real visitors never fill this in
);

-- Row Level Security: OFF by default means "no access at all" once enabled,
-- until a policy explicitly allows something. We allow the public
-- ("anon") role to INSERT only — never to read or edit existing rows.
alter table feedback enable row level security;

create policy "Public can submit feedback"
  on feedback
  for insert
  to anon
  with check (true);

-- No SELECT / UPDATE / DELETE policy for "anon" is created on purpose —
-- that means the public form can add feedback but can never read anyone
-- else's feedback back out. Only your Charter Management System, using the
-- separate "service_role" key (never put that key in the public form!),
-- can read everything for the Sync feature.
