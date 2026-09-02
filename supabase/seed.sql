-- Optional starter catalog data so the app isn't empty on first run.
-- Safe to re-run (upserts on primary key). Edit/extend freely -- there is
-- no admin UI for this yet, so managing productions/venues/performances is
-- done by editing this file (or the tables directly) and re-running it.
--
-- IMPORTANT: the cast/performance details below are illustrative placeholder
-- data carried over from the app's original mock data (same names/dates the
-- prototype already shipped with) -- they are NOT verified against real,
-- current listings from these opera houses. Before shipping to real users,
-- replace this with actual data from each company's box office / API, or
-- build an admin flow so a human enters verified listings. Do not present
-- these rows as confirmed real-world performances.

insert into public.venues (id, name, city, country, address, latitude, longitude, website, capacity)
values
  ('v-met', 'Metropolitan Opera House', 'New York', 'USA', 'Lincoln Center, New York, NY 10023', 40.7730, -73.9845, 'https://www.metopera.org', 3800),
  ('v-royal-opera', 'Royal Opera House', 'London', 'United Kingdom', 'Bow St, London WC2E 9DD', 51.5129, -0.1224, 'https://www.rbo.org.uk', 2256),
  ('v-la-scala', 'Teatro alla Scala', 'Milan', 'Italy', 'Via Filodrammatici, 2, 20121 Milano MI', 45.4674, 9.1900, 'https://www.teatroallascala.org', 2030)
on conflict (id) do update set
  name = excluded.name,
  city = excluded.city,
  country = excluded.country,
  address = excluded.address,
  latitude = excluded.latitude,
  longitude = excluded.longitude,
  website = excluded.website,
  capacity = excluded.capacity;

insert into public.productions (
  id, opera_id, opera_title, company, company_id, director, conductor,
  production_year, designer, venue_id, description
)
values
  (
    'p-met-boheme-2023', 'puccini-boheme', 'La Bohème', 'Metropolitan Opera', 'met',
    'Franco Zeffirelli', 'Yannick Nézet-Séguin', 2023, 'Franco Zeffirelli', 'v-met',
    'Franco Zeffirelli''s iconic production of La Bohème returns to the Met.'
  ),
  (
    'p-roh-carmen-2024', 'bizet-carmen', 'Carmen', 'Royal Opera House', 'roh',
    'Barrie Kosky', 'Antonello Manacorda', 2024, 'Katrin Lea Tag', 'v-royal-opera',
    'Barrie Kosky''s bold, dance-driven staging of Bizet''s Carmen.'
  )
on conflict (id) do update set
  opera_title = excluded.opera_title,
  company = excluded.company,
  director = excluded.director,
  conductor = excluded.conductor,
  production_year = excluded.production_year,
  designer = excluded.designer,
  venue_id = excluded.venue_id,
  description = excluded.description,
  updated_at = now();

insert into public.cast_members (id, production_id, name, role, artist_id)
values
  ('c-boheme-1', 'p-met-boheme-2023', 'Anna Netrebko', 'Mimì', 'netrebko-1'),
  ('c-boheme-2', 'p-met-boheme-2023', 'Jonas Kaufmann', 'Rodolfo', 'kaufmann-1'),
  ('c-carmen-1', 'p-roh-carmen-2024', 'Aigul Akhmetshina', 'Carmen', 'akhmetshina-1')
on conflict (id) do update set
  name = excluded.name,
  role = excluded.role,
  artist_id = excluded.artist_id;

insert into public.performances (id, production_id, date, time, ticket_url, ticket_price_range, is_sold_out)
values
  ('perf-boheme-1', 'p-met-boheme-2023', now() + interval '30 days', '7:30 PM', 'https://www.metopera.org/tickets', '$50-$350', false),
  ('perf-carmen-1', 'p-roh-carmen-2024', now() + interval '45 days', '7:00 PM', 'https://www.rbo.org.uk/tickets', '£20-£250', false)
on conflict (id) do update set
  date = excluded.date,
  time = excluded.time,
  ticket_url = excluded.ticket_url,
  ticket_price_range = excluded.ticket_price_range,
  is_sold_out = excluded.is_sold_out;
