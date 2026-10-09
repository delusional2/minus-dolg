-- Минус долг: таблицы и правила доступа. Выполни целиком в Supabase → SQL Editor → Run.
create table if not exists public.tx (
  user_id uuid not null default auth.uid() references auth.users on delete cascade,
  id text not null,
  amount numeric not null,
  name text not null default '',
  cat text not null default 'Другое',
  ts bigint not null,
  src text default '',
  created_at timestamptz default now(),
  primary key (user_id, id)
);

create table if not exists public.settings (
  user_id uuid primary key default auth.uid() references auth.users on delete cascade,
  data jsonb not null default '{}'::jsonb,
  updated_at timestamptz default now()
);

alter table public.tx enable row level security;
alter table public.settings enable row level security;

drop policy if exists "own tx" on public.tx;
create policy "own tx" on public.tx for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "own settings" on public.settings;
create policy "own settings" on public.settings for all
  using (auth.uid() = user_id) with check (auth.uid() = user_id);
