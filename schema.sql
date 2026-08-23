-- Ratings / progress (one row per member per book)
create table book_club (
  id bigint generated always as identity primary key,
  user_id text not null,
  book_id text not null,
  rating int check (rating is null or rating between 1 and 5),
  progress int check (progress is null or progress between 0 and 10000),
  finished boolean not null default false,
  started_at timestamptz,
  name text,
  updated_at timestamptz not null default now(),
  unique (user_id, book_id)
);
alter table book_club enable row level security;
create policy "anyone can read"  on book_club for select using (true);
create policy "anyone can insert" on book_club for insert with check (true);
create policy "anyone can update" on book_club for update using (true) with check (true);

-- Book list (one JSON row holding the current + past books)
create table books (
  key text primary key default 'primary',
  state jsonb not null,
  updated_at timestamptz not null default now()
);
alter table books enable row level security;
create policy "anyone can read"  on books for select using (true);
create policy "anyone can write" on books for insert with check (true);
create policy "anyone can update" on books for update using (true) with check (true);