create table if not exists public.user_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reminder_time time not null,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.missed_reminders (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  reminder_id uuid not null references public.user_reminders(id) on delete cascade,
  scheduled_at timestamptz not null,
  created_at timestamptz not null default now()
);

create unique index if not exists missed_reminders_unique
  on public.missed_reminders (user_id, reminder_id, scheduled_at);

alter table public.user_reminders enable row level security;
alter table public.missed_reminders enable row level security;

create policy "Users can manage own reminders"
  on public.user_reminders
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);

create policy "Users can manage own missed reminders"
  on public.missed_reminders
  for all
  using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
