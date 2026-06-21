-- Run this entire file in the Supabase SQL Editor (supabase.com → your project → SQL Editor)

-- 1. Create the fighter_responses table
create table if not exists fighter_responses (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid references auth.users not null,
  fighter_name      text not null,
  tournament_name   text not null,
  attendance_status text not null check (attendance_status in ('Yes', 'Maybe', 'No')),
  combat_notes      text,
  created_at        timestamptz default now(),
  updated_at        timestamptz default now(),
  -- Each fighter can have exactly one response per tournament (upsert key)
  constraint unique_user_tournament unique (user_id, tournament_name)
);

-- 2. Enable Row Level Security
alter table fighter_responses enable row level security;

-- 3. RLS policies
-- Anyone (even logged-out visitors) can read all responses
create policy "anyone can read"
  on fighter_responses for select
  using (true);

-- Logged-in users can insert rows, but only as themselves
create policy "authenticated can insert own"
  on fighter_responses for insert
  with check (auth.uid() = user_id);

-- Logged-in users can update only their own rows
create policy "authenticated can update own"
  on fighter_responses for update
  using (auth.uid() = user_id);

-- Admin delete functions (bypass RLS via security definer)
create or replace function admin_delete_response(response_id uuid)
returns void language plpgsql security definer as $$
begin
  if auth.email() != 'bennykashter@gmail.com' then
    raise exception 'Not authorized';
  end if;
  delete from fighter_responses where id = response_id;
end;
$$;

create or replace function admin_clear_responses()
returns void language plpgsql security definer as $$
begin
  if auth.email() != 'bennykashter@gmail.com' then
    raise exception 'Not authorized';
  end if;
  delete from fighter_responses;
end;
$$;

-- 4. Auto-update the updated_at timestamp on row changes
create or replace function update_updated_at()
returns trigger language plpgsql as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger set_updated_at
  before update on fighter_responses
  for each row execute function update_updated_at();

-- 5. Enable Realtime for this table
-- (Supabase requires the table to be added to the publication)
alter publication supabase_realtime add table fighter_responses;
