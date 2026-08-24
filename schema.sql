create table if not exists books (
  id          text primary key,
  title       text not null,
  author      text,
  isbn        text,
  cover_url   text,
  total_pages int,
  status      text not null default 'past'
                check (status in ('current','past')),
  position    bigint not null default 0,
  added_at    timestamptz not null default now(),
  added_by    text
);
create unique index if not exists books_one_current
  on books (status) where status = 'current';

create table if not exists members (
  user_id   text primary key,
  name      text,
  joined_at timestamptz not null default now()
);

create table if not exists book_club (
  id         bigint generated always as identity primary key,
  user_id    text not null references members(user_id) on delete cascade,
  book_id    text not null references books(id) on delete cascade,
  rating     int  check (rating is null or rating between 1 and 5),
  progress   int  check (progress is null or progress between 0 and 10000),
  review     text,
  finished   boolean not null default false,
  started_at timestamptz,
  updated_at timestamptz not null default now(),
  unique (user_id, book_id)
);

alter table books     enable row level security;
alter table members   enable row level security;
alter table book_club enable row level security;

create policy "books_read"   on books for select using (true);
create policy "books_write"  on books for all    using (true) with check (true);

create policy "members_read"  on members for select using (true);
create policy "members_write" on members for all    using (true) with check (true);

create policy "book_club_read"  on book_club for select using (true);
create policy "book_club_write" on book_club for all    using (true) with check (true);