-- Ritmo + Supabase
-- Ejecutar completo en Supabase > SQL Editor.
-- Este esquema usa auth.users como identidad y aplica RLS por usuario.

create extension if not exists "pgcrypto";

create or replace function public.set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.categories (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  color text not null,
  is_system boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (user_id, name)
);

create table if not exists public.semesters (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  start_date date not null,
  end_date date not null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (start_date <= end_date)
);

create table if not exists public.subjects (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  semester_id uuid not null references public.semesters(id) on delete cascade,
  name text not null,
  has_lab boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.schedule_blocks (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete cascade,
  block_type text not null default 'other' check (block_type in ('theory', 'lab', 'other')),
  weekday smallint not null check (weekday between 0 and 6),
  start_time time not null,
  end_time time not null,
  range_start date,
  range_end date,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (start_time <> end_time),
  check (range_start is null or range_end is null or range_start <= range_end)
);

create table if not exists public.activities (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  category_id uuid not null references public.categories(id) on delete restrict,
  name text not null,
  activity_type text not null default 'Actividad',
  medical_kind text,
  start_time time not null,
  end_time time not null,
  recovery_hours integer not null default 0 check (recovery_hours >= 0),
  notes text,
  care_notes text,
  prep_minutes integer not null default 0 check (prep_minutes >= 0),
  icon text,
  semester_id uuid references public.semesters(id) on delete cascade,
  subject_id uuid references public.subjects(id) on delete cascade,
  block_id uuid references public.schedule_blocks(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (start_time <> end_time),
  check (activity_type = 'Procedimiento médico' or recovery_hours = 0)
);

create table if not exists public.events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  activity_id uuid not null references public.activities(id) on delete cascade,
  event_date date not null,
  start_time time not null,
  end_time time not null,
  is_generated boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  check (start_time <> end_time)
);

alter table public.activities add column if not exists care_notes text;
alter table public.activities add column if not exists prep_minutes integer not null default 0;

create index if not exists categories_user_id_idx on public.categories(user_id);
create index if not exists semesters_user_id_idx on public.semesters(user_id);
create index if not exists subjects_semester_id_idx on public.subjects(semester_id);
create index if not exists schedule_blocks_subject_id_idx on public.schedule_blocks(subject_id);
create index if not exists activities_user_date_idx on public.activities(user_id, created_at);
create index if not exists activities_block_id_idx on public.activities(block_id);
create index if not exists events_user_date_idx on public.events(user_id, event_date);
create index if not exists events_activity_id_idx on public.events(activity_id);

create or replace function public.validate_ritmo_ownership()
returns trigger
language plpgsql
as $$
declare
  owner_id uuid;
begin
  if tg_table_name = 'subjects' then
    select user_id into owner_id from public.semesters where id = new.semester_id;
    if owner_id is distinct from new.user_id then raise exception 'El semestre no pertenece al usuario'; end if;
  elsif tg_table_name = 'schedule_blocks' then
    if new.subject_id is not null then
      select user_id into owner_id from public.subjects where id = new.subject_id;
      if owner_id is distinct from new.user_id then raise exception 'La materia no pertenece al usuario'; end if;
    end if;
  elsif tg_table_name = 'activities' then
    select user_id into owner_id from public.categories where id = new.category_id;
    if owner_id is distinct from new.user_id then raise exception 'La categoría no pertenece al usuario'; end if;
    if new.semester_id is not null then
      select user_id into owner_id from public.semesters where id = new.semester_id;
      if owner_id is distinct from new.user_id then raise exception 'El semestre no pertenece al usuario'; end if;
    end if;
    if new.subject_id is not null then
      select user_id into owner_id from public.subjects where id = new.subject_id;
      if owner_id is distinct from new.user_id then raise exception 'La materia no pertenece al usuario'; end if;
    end if;
    if new.block_id is not null then
      select user_id into owner_id from public.schedule_blocks where id = new.block_id;
      if owner_id is distinct from new.user_id then raise exception 'El bloque no pertenece al usuario'; end if;
    end if;
  elsif tg_table_name = 'events' then
    select user_id into owner_id from public.activities where id = new.activity_id;
    if owner_id is distinct from new.user_id then raise exception 'La actividad no pertenece al usuario'; end if;
  end if;
  return new;
end;
$$;

drop trigger if exists subjects_validate_ownership on public.subjects;
create trigger subjects_validate_ownership before insert or update on public.subjects
for each row execute procedure public.validate_ritmo_ownership();

drop trigger if exists schedule_blocks_validate_ownership on public.schedule_blocks;
create trigger schedule_blocks_validate_ownership before insert or update on public.schedule_blocks
for each row execute procedure public.validate_ritmo_ownership();

drop trigger if exists activities_validate_ownership on public.activities;
create trigger activities_validate_ownership before insert or update on public.activities
for each row execute procedure public.validate_ritmo_ownership();

drop trigger if exists events_validate_ownership on public.events;
create trigger events_validate_ownership before insert or update on public.events
for each row execute procedure public.validate_ritmo_ownership();

 drop trigger if exists profiles_updated_at on public.profiles;
create trigger profiles_updated_at before update on public.profiles
for each row execute procedure public.set_updated_at();

 drop trigger if exists categories_updated_at on public.categories;
create trigger categories_updated_at before update on public.categories
for each row execute procedure public.set_updated_at();

 drop trigger if exists semesters_updated_at on public.semesters;
create trigger semesters_updated_at before update on public.semesters
for each row execute procedure public.set_updated_at();

 drop trigger if exists subjects_updated_at on public.subjects;
create trigger subjects_updated_at before update on public.subjects
for each row execute procedure public.set_updated_at();

 drop trigger if exists schedule_blocks_updated_at on public.schedule_blocks;
create trigger schedule_blocks_updated_at before update on public.schedule_blocks
for each row execute procedure public.set_updated_at();

 drop trigger if exists activities_updated_at on public.activities;
create trigger activities_updated_at before update on public.activities
for each row execute procedure public.set_updated_at();

 drop trigger if exists events_updated_at on public.events;
create trigger events_updated_at before update on public.events
for each row execute procedure public.set_updated_at();

create or replace function public.seed_default_categories(target_user_id uuid)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.categories (user_id, name, color, is_system)
  values
    (target_user_id, 'Estudio', '#d2a52e', true),
    (target_user_id, 'Gym', '#e98269', true),
    (target_user_id, 'Salud', '#a792d0', true),
    (target_user_id, 'Otros', '#83aabb', true)
  on conflict (user_id, name) do nothing;
$$;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'full_name', split_part(new.email, '@', 1)))
  on conflict (id) do nothing;
  perform public.seed_default_categories(new.id);
  return new;
end;
$$;

 drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
after insert on auth.users
for each row execute procedure public.handle_new_user();

-- Activa las categorías fijas para usuarios que ya existían antes de instalar este esquema.
insert into public.profiles (id, display_name)
select id, coalesce(raw_user_meta_data ->> 'full_name', split_part(email, '@', 1))
from auth.users
on conflict (id) do nothing;

select public.seed_default_categories(id) from auth.users;

alter table public.profiles enable row level security;
alter table public.categories enable row level security;
alter table public.semesters enable row level security;
alter table public.subjects enable row level security;
alter table public.schedule_blocks enable row level security;
alter table public.activities enable row level security;
alter table public.events enable row level security;

drop policy if exists profiles_owner on public.profiles;
create policy profiles_owner on public.profiles for all using (id = auth.uid()) with check (id = auth.uid());

drop policy if exists categories_owner on public.categories;
create policy categories_owner on public.categories for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists semesters_owner on public.semesters;
create policy semesters_owner on public.semesters for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists subjects_owner on public.subjects;
create policy subjects_owner on public.subjects for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists schedule_blocks_owner on public.schedule_blocks;
create policy schedule_blocks_owner on public.schedule_blocks for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists activities_owner on public.activities;
create policy activities_owner on public.activities for all using (user_id = auth.uid()) with check (user_id = auth.uid());

drop policy if exists events_owner on public.events;
create policy events_owner on public.events for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- Realtime para sincronizar cambios entre computador y teléfono.
do $$
begin
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'categories') then
    alter publication supabase_realtime add table public.categories;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'semesters') then
    alter publication supabase_realtime add table public.semesters;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'subjects') then
    alter publication supabase_realtime add table public.subjects;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'schedule_blocks') then
    alter publication supabase_realtime add table public.schedule_blocks;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'activities') then
    alter publication supabase_realtime add table public.activities;
  end if;
  if not exists (select 1 from pg_publication_tables where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = 'events') then
    alter publication supabase_realtime add table public.events;
  end if;
end;
$$;
