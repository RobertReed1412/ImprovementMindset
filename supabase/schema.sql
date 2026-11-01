-- =====================================================================
-- The Improvement Mindset — Workout RAG schema for Supabase
-- Run top-to-bottom in Supabase → SQL Editor. Safe to re-run.
--
-- Matches the CSV exported by the app (ImprovementMindset/WorkoutExport.swift):
--   id, workout_type, duration_minutes, notes, performed_at, logged_at, content
-- =====================================================================


-- 1. pgvector ---------------------------------------------------------
create extension if not exists vector with schema extensions;


-- 2. Raw workout logs (one row per workout logged in the app) ---------
create table if not exists public.workouts (
  id               uuid primary key,
  workout_type     text not null
                   check (workout_type in ('fighting', 'soccer', 'lifting', 'strongman', 'dancing', '')),
  duration_minutes int  not null check (duration_minutes >= 0),
  notes            text,
  performed_at     timestamptz not null,
  logged_at        timestamptz not null default now(),
  content          text not null   -- ready-to-embed sentence built by the app
);

create index if not exists workouts_performed_at_idx on public.workouts (performed_at desc);
create index if not exists workouts_type_idx         on public.workouts (workout_type);


-- 3. Staging table for CSV imports ------------------------------------
-- Every app export contains ALL workouts, so importing straight into
-- `workouts` would fail on duplicate ids. Import into staging instead,
-- then run:  select public.merge_staged_workouts();
create table if not exists public.workouts_staging (like public.workouts);

create or replace function public.merge_staged_workouts()
returns int
language plpgsql
as $$
declare
  inserted int;
begin
  insert into public.workouts
  select * from public.workouts_staging
  on conflict (id) do nothing;
  get diagnostics inserted = row_count;
  truncate public.workouts_staging;
  return inserted;   -- number of NEW workouts added
end;
$$;


-- 4. Embedded chunks (one chunk per workout) --------------------------
-- Column names (content / metadata / embedding) match what n8n's
-- Supabase Vector Store node reads and writes.
-- 1536 dims = OpenAI text-embedding-3-small.
create table if not exists public.workout_chunks (
  id         bigserial primary key,
  content    text not null,
  metadata   jsonb not null default '{}'::jsonb,
  embedding  extensions.vector(1536),
  created_at timestamptz not null default now()
);

-- HNSW works on an empty/small table (ivfflat needs lots of rows first).
create index if not exists workout_chunks_embedding_idx
  on public.workout_chunks using hnsw (embedding extensions.vector_cosine_ops);
create index if not exists workout_chunks_metadata_idx
  on public.workout_chunks using gin (metadata);


-- 5. Similarity search -------------------------------------------------
-- Signature (query_embedding, match_count, filter) is what the n8n
-- Supabase Vector Store node calls. `filter` lets the agent narrow by
-- metadata, e.g. '{"workout_type": "fighting"}'.
create or replace function public.match_workout_chunks(
  query_embedding extensions.vector(1536),
  match_count     int   default 8,
  filter          jsonb default '{}'
)
returns table (id bigint, content text, metadata jsonb, similarity float)
language sql
stable
as $$
  select c.id,
         c.content,
         c.metadata,
         1 - (c.embedding <=> query_embedding) as similarity
  from public.workout_chunks c
  where c.metadata @> filter
  order by c.embedding <=> query_embedding
  limit match_count;
$$;


-- 6. Workouts that still need embedding --------------------------------
-- The n8n ingestion workflow reads this view, so re-running it never
-- creates duplicate chunks.
create or replace view public.workouts_to_embed
with (security_invoker = true) as
select w.*
from public.workouts w
where not exists (
  select 1 from public.workout_chunks c
  where c.metadata->>'workout_id' = w.id::text
);


-- 7. Exact totals for "how many / how much" questions -----------------
-- Vector search is bad at counting, so the agent calls this instead.
-- tz = your local time zone so late-night workouts land on the right day.
create or replace function public.workout_summary(
  start_date date,
  end_date   date,
  tz         text default 'UTC'
)
returns table (
  workout_type  text,
  sessions      bigint,
  total_minutes bigint,
  avg_minutes   numeric,
  first_session date,
  last_session  date
)
language sql
stable
as $$
  select coalesce(nullif(w.workout_type, ''), 'unspecified'),
         count(*),
         sum(w.duration_minutes),
         round(avg(w.duration_minutes), 1),
         min((w.performed_at at time zone tz)::date),
         max((w.performed_at at time zone tz)::date)
  from public.workouts w
  where (w.performed_at at time zone tz)::date between start_date and end_date
  group by 1
  order by 3 desc;
$$;


-- 8. Keep chunks in sync when a workout row is deleted ----------------
create or replace function public.delete_workout_chunks()
returns trigger
language plpgsql
as $$
begin
  delete from public.workout_chunks where metadata->>'workout_id' = old.id::text;
  return old;
end;
$$;

drop trigger if exists workouts_delete_chunks on public.workouts;
create trigger workouts_delete_chunks
  after delete on public.workouts
  for each row execute function public.delete_workout_chunks();


-- 9. Security ----------------------------------------------------------
-- RLS on with no policies = the public anon key can't read anything.
-- n8n uses the service_role key, which bypasses RLS.
alter table public.workouts         enable row level security;
alter table public.workouts_staging enable row level security;
alter table public.workout_chunks   enable row level security;
