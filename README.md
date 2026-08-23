# 📖 The Reading Circle — Book Club Site

A static book-club website hosted free on GitHub Pages, with shared ratings and
reading progress powered by a free Supabase backend.

## Files
- `index.html` — the whole site (HTML + CSS + JS, no build step).
- This README.

## 1. Put the site on GitHub (Project Pages)
1. Create a new repository, e.g. `book-club`.
2. Add `index.html` to the repo root.
3. Push to GitHub.
4. Repo → Settings → Pages → Source: Deploy from a branch → Branch: `main` / root.
5. Live at `https://<username>.github.io/book-club/`.

## 2. Enable shared ratings with Supabase (free, ~3 minutes)
Without Supabase the site runs in demo mode (each visitor sees only their own
browser data + seeded samples). To share ratings across the group:

### a. Create a project
1. Sign up at supabase.com and create a new project (free tier, no card needed).
2. Project Settings → API → copy your Project URL and the anon public key.

### b. Create the table
Open SQL Editor in Supabase and run:

create table book_club (
  id bigint generated always as identity primary key,
  user_id text not null,
  book_id text not null,
  rating int check (rating is null or rating between 1 and 5),
  progress int check (progress is null or progress between 0 and 10000),
  finished boolean not null default false,
  updated_at timestamptz not null default now(),
  unique (user_id, book_id)
);

alter table book_club enable row level security;
create policy "anyone can read"  on book_club for select using (true);
create policy "anyone can insert" on book_club for insert with check (true);
create policy "anyone can update" on book_club for update using (true) with check (true);

### c. Add your keys to index.html
Edit the CONFIG block near the top of the script:

const CONFIG = {
  clubName: "The Reading Circle",
  supabaseUrl: "https://YOURPROJECT.supabase.co",
  supabaseAnonKey: "YOUR_ANON_PUBLIC_KEY",
  table: "book_club",
  currentBook: { /* ... */ },
  pastBooks: [ /* ... */ ]
};

Save, commit, push. The demo banner disappears and ratings/progress are shared.

## 3. Set your books
Edit CONFIG.currentBook and CONFIG.pastBooks. Each book:

{ id: "unique-slug", title: "Book Title", author: "Author", totalPages: 304, coverUrl: "" }

- id — any unique string; keep it stable once people have rated.
- coverUrl — optional. Leave "" for an auto-generated colored cover, or use a
  repo-relative image path like "covers/midnight.jpg".
- totalPages — used for the progress slider and percentage.

To promote the current book to the past list later, move it into pastBooks and
add a fresh currentBook.

## How member identity works
Each visitor gets a random anonymous user_id stored in localStorage. Ratings
and progress are tied to that id — one rating per book per person, editable
anytime. No sign-in required.

## Notes
- The Supabase anon key is safe to expose in a static page; security is enforced
  by Row Level Security, not by hiding the key.
- Default policies let anyone with the link read/write. Fine for a private club.
  To restrict writes, add Supabase Auth and change the policies to auth.uid().