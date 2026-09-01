-- Run this once in Supabase: Dashboard → SQL Editor → New query → paste → Run.
-- Creates the table that stores client preference lists (used by
-- preference-list.html, in a separate repository/Vercel project), and
-- locks it down so the public form can only ADD entries, never read or
-- change existing ones.

create table if not exists preference_lists (
  id uuid primary key default gen_random_uuid(),
  received_at timestamptz not null default now(),

  client_name text not null,
  yacht_name text not null,
  charter_start_date date,
  charter_end_date date,
  contact_phone text,
  contact_email text,

  travel jsonb,                      -- {arrival:{...}, departure:{...}, hotelBefore:{...}, hotelAfter:{...}}
  charter_party jsonb,               -- [{name, nationality, dob, passportNo, passportExpiry}, ...]

  pace text,                         -- 'Busy, active days' | 'Relaxed, slow-paced' | 'A mixture'
  interests jsonb,                   -- ['Sightseeing', 'Diving', ...]
  sightseeing_wishlist text,

  dining jsonb,                      -- meal times, breakfast/lunch/dinner style, canapes, snacks, dine ashore, cooking style, etc.
  food_grid jsonb,                   -- [{item, like, dislike, notes}, ...]
  special_diets jsonb,               -- ['Vegan', 'Halal', ...]
  special_diets_other text,
  vegetarian_eats jsonb,             -- {eggs, cheese, fish}
  cuisine_style text,
  favorite_dishes text,
  ingredients_avoid text,
  food_detail jsonb,                 -- cuisine tags, fish/bread/salad/fruit types, meat/soup/cheese/veg/dessert preferences

  wines jsonb,                       -- [{country, name, qty}, ...]
  champagne jsonb,                   -- {nonVintage, vintage, qty}
  max_price_per_bottle jsonb,        -- [{type, price}, ...]
  spirits jsonb,                     -- [{type, brand, qty, priceRange}, ...]
  soft_drinks text,
  cocktails text,
  wine_preferences jsonb,            -- style tags, sample wine list, price/qty by color, beers, non-alcoholic beverages

  medical_conditions text,
  doctor_contact text,
  allergies text,

  occasions jsonb,                   -- [{type, date, who, notes}, ...]
  flowers_preference text,
  flowers_frequency text,            -- 'Weekly' | 'Bi-weekly' | 'No additional flowers'
  reading_material text,
  cabins jsonb,                      -- [{deck, cabin, type, guest}, ...]
  additional_notes text,

  website text                       -- honeypot: real visitors never fill this in
);

-- Row Level Security: OFF by default means "no access at all" once enabled,
-- until a policy explicitly allows something. We allow the public
-- ("anon") role to INSERT only — never to read or edit existing rows.
alter table preference_lists enable row level security;

create policy "Public can submit a preference list"
  on preference_lists
  for insert
  to anon
  with check (true);

-- No SELECT / UPDATE / DELETE policy for "anon" is created on purpose —
-- that means the public form can add a preference list but can never read
-- anyone else's back out. Reading these back into the Charter Management
-- System (case detail page) would need the same private "service_role" key
-- pattern already used for the Feedback sync — never put that key in the
-- public form.
