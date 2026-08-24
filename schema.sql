-- Book Club schema (idempotent — safe to re-run, never drops data)

create table if not exists books (
  id          text primary key,
  title       text not null,
  author      text,
  isbn        text,
  cover_url   text,
  total_pages int,
  status      text not null default 'past' check (status in ('current','past')),
  position    bigint not null default 0,
  added_at    timestamptz not null default now(),
  added_by    text
);
create unique index if not exists books_one_current on books (status) where status = 'current';

create table if not exists members (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  name       text,
  joined_at  timestamptz not null default now()
);

create table if not exists book_club (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references members(user_id) on delete cascade,
  book_id     text not null references books(id)      on delete cascade,
  rating      int check (rating is null or rating between 1 and 5),
  progress    int check (progress is null or progress between 0 and 10000),
  review      text,
  finished    boolean not null default false,
  started_at  timestamptz,
  updated_at  timestamptz not null default now(),
  unique (user_id, book_id)
);

create table if not exists wishlist (
  id          bigint generated always as identity primary key,
  user_id     uuid not null references members(user_id) on delete cascade,
  work_id     text,
  title       text not null,
  author      text,
  cover_url   text,
  added_at    timestamptz not null default now()
);

alter table books     enable row level security;
alter table members   enable row level security;
alter table book_club enable row level security;
alter table wishlist  enable row level security;

-- policies: drop-if-exists first so re-running doesn't error on duplicates
drop policy if exists "books read"     on books;
drop policy if exists "books write"    on books;
create policy "books read"  on books for select using (true);
create policy "books write" on books for all    using (auth.uid() is not null) with check (auth.uid() is not null);

drop policy if exists "members read"   on members;
drop policy if exists "members write"  on members;
create policy "members read"  on members for select using (true);
create policy "members write" on members for all   using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "ratings read"   on book_club;
drop policy if exists "ratings write"  on book_club;
create policy "ratings read"  on book_club for select using (true);
create policy "ratings write" on book_club for all   using (auth.uid() = user_id) with check (auth.uid() = user_id);

drop policy if exists "wishlist read"    on wishlist;
drop policy if exists "wishlist write"   on wishlist;
drop policy if exists "wishlist delete"  on wishlist;
create policy "wishlist read"   on wishlist for select using (true);
create policy "wishlist write"  on wishlist for insert with check (auth.uid() = user_id);
create policy "wishlist delete" on wishlist for delete using (auth.uid() = user_id);