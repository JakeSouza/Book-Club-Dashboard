# 📖 The Reading Circle — Book Club Site

A static book-club website hosted free on **GitHub Pages**, with shared ratings, reading progress, member stats, and an in-app **Admin panel** to manage the book list. Shared data is powered by a free **Supabase** backend.

## Features

- Club name across the top of every page
- **Current Book** tab — current book cover centered, title, author, live group rating, your reading status
- **Past Books** tab — grid of past reads, each with its collective group rating (avg ★ + number of raters)
- **Rate &amp; Progress** tab — 1–5 star rating, page-progress slider + number (live %), "finished" checkbox, one-click "Mark as finished"
- **Reader Stats** tab — every member with their average rating and average reading speed (pages/day)
- **Admin tab** (passcode-protected) — add / edit / delete current &amp; past books, with **ISBN or OLID auto-fill** from Open Library (pulls title, author, page count, and cover automatically)
- Real book covers from the **Open Library Covers API** (free, no key), with an auto-generated fallback when no cover exists
- Runs in **demo mode** (browser-only, seeded with sample data) until you connect Supabase

## Files

- `index.html` — the whole site (HTML + CSS + JS, no build step). Copy this from the canvas.
- This README — setup instructions.

---

## 1. Put the site on GitHub (Project Pages)

1. Create a new repository, e.g. `book-club`.
2. Add `index.html` to the repo root.
3. Push to GitHub.
4. Repo → **Settings → Pages → Source: Deploy from a branch → Branch: `main` / root**.
5. Your site goes live at `https://<username>.github.io/book-club/`.

> The `index.html` is self-contained — no dependencies to install.

---

## 2. Enable shared ratings + book list with Supabase (free, \~5 minutes)

Without this, the site runs in **demo mode** (each visitor only sees their own browser data + seeded samples). To let the whole group share ratings, progress, and the book list:

### a. Create a project

1. Sign up at [supabase.com](https://supabase.com) and create a new project (free tier, no card needed).
2. Go to **Project Settings → API**. Copy your **Project URL** and the **anon public** key.

### b. Create the tables

Open **SQL Editor** in Supabase and run:

```sql
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
```

### c. Add your keys to `index.html`

Near the top of the `<script>`, edit the `CONFIG` block:

```js
const CONFIG = {
  clubName: "The Reading Circle",
  supabaseUrl: "https://YOURPROJECT.supabase.co",
  supabaseAnonKey: "YOUR_ANON_PUBLIC_KEY",
  ratingsTable: "book_club",
  booksTable: "books",
  adminPasscode: "bookclub2026",   // ← CHANGE THIS
  defaultCurrentBook: { /* ... */ },
  defaultPastBooks: [ /* ... */ ]
};
```

Save, commit, push. The demo banner disappears and ratings/progress/the book list are shared across everyone.

---

## 3. Managing books (the Admin tab)

Books are managed **through the UI**, not by editing code.

1. Click the **⚙️ Admin** tab (it appears after you unlock it).
2. Enter your passcode (`adminPasscode` in `CONFIG` — **change the default `bookclub2026`**).
3. **Add a book**: type an ISBN or OLID → click **🔍 Auto-fill from ISBN / OLID** → title/author/pages/cover fill in automatically → pick "Add to Past Books" or "Set as Current Book" → click **Add book**.
4. **Edit / Delete** any book using the buttons on each row.
5. Setting a new current book automatically pushes the old one into the Past list.
6. Changes save to Supabase (shared with everyone) when configured, or your browser in demo mode.

> The `defaultCurrentBook` / `defaultPastBooks` in `CONFIG` are only used the **first time** the site loads (before anything is saved). After that, the saved list is the source of truth.

### ISBN vs OLID

The site accepts either identifier and auto-detects which one you entered:

- **ISBN** (10 or 13 digits) → e.g. `9780525559474` → cover from `https://covers.openlibrary.org/b/isbn/{ISBN}-L.jpg`
- **OLID** (Open Library ID, starts with `OL`) → e.g. `OL28401522M` → cover from `https://covers.openlibrary.org/b/olid/{OLID}-L.jpg`

You'll find the OLID in the URL of any `openlibrary.org/books/...` page (e.g. `openlibrary.org/books/OL28401522M/...`). Past **`/books/` pages are indexed by OLID, not ISBN** — so if you copied an identifier from a book page's URL, it's an OLID. The site handles both, so just paste what you copied.

The auto-fill also grabs a **direct cover URL** from the Open Library Books API and drops it into the "Cover image URL" field. When that's filled, the cover loads straight from that URL — no Covers-API lookup needed — so it works even for editions where the Covers API has no image.

---

## 4. How member identity works

Each visitor gets a random, anonymous `user_id` stored in their browser's `localStorage`. Ratings and progress are tied to that id, so each person gets one rating per book and can update it anytime. No sign-in required.

> Because the id lives in localStorage, clearing browser data or switching devices/browsers starts a fresh member. That's fine for a casual club. For true per-account identity, add Supabase Auth later.

There's also an optional **Your name** field on the Rate &amp; Progress tab so members are identifiable on the Reader Stats page instead of anonymous.

---

## 5. Reading-speed calculation

Reading speed = book's page count ÷ days from start to finish, averaged across a member's **finished** books.

- `started_at` is recorded the first time you log progress on a book.
- `updated_at` is recorded every save; when you mark a book finished, that becomes the finish timestamp.
- Only finished books contribute a speed (an open reading window has no finish date yet).
- Days are clamped to a minimum of 1 so same-day finishes don't produce absurd numbers.

---

## 6. Privacy &amp; security notes

- The Supabase **anon key** is safe to expose in a static page — it's designed for this. Security is enforced by **Row Level Security**, not by hiding the key.
- The default policies let anyone with the link read/write both tables. For a private club that's usually fine.
- The **Admin passcode** is a client-side gate: it hides the admin UI from non-maintainers, but it is *not* server-side security (it's visible in the JS source). It's good enough for a trusted small club. For true enforcement:
  - Add **Supabase Auth** and create maintainer accounts, then
  - Tighten the `books` write policies to require auth (e.g. `auth.uid() = 'your-maintainer-uid'`).
- **Change the default passcode** (`bookclub2026`) before deploying — it's public in the code.

---

## 7. Troubleshooting

- **"Could not save" / ratings not shared:** double-check `supabaseUrl` (no trailing slash) and `anon key`, and that you ran the SQL incl. the `unique(user_id, book_id)` constraint, the `books` table, and the RLS policies.
- **Covers not loading:** the identifier you pasted was probably an **OLID** from a `/books/` URL, not an ISBN. The site now auto-detects both — just make sure you pasted the identifier itself (e.g. `OL28401522M`), not the whole URL. Best practice: paste ISBN/OLID → click **Auto-fill** → the cover URL gets filled from the API → add the book.
- **Some covers fall back to generated art:** that's expected — not every edition has a cover on Open Library. The `?default=false` flag makes missing covers return a 404 (instead of a blank placeholder), which triggers the auto-generated fallback cover. Try a different edition's ISBN if you want the real cover.
- **Demo banner still showing:** `supabaseUrl` / `supabaseAnonKey` are still empty in `CONFIG`.
- **Open Library lookups don't work in the chat preview:** that's expected — the preview sandbox blocks external requests. They work normally on your deployed GitHub Pages site.

---

## 8. Quick reference — CONFIG block

```js
const CONFIG = {
  clubName: "The Reading Circle",          // shown in header + browser tab
  supabaseUrl: "",                         // https://YOURPROJECT.supabase.co
  supabaseAnonKey: "",                      // anon public key
  ratingsTable: "book_club",                // ratings/progress table
  booksTable: "books",                       // book list table
  adminPasscode: "bookclub2026",            // CHANGE THIS
  defaultCurrentBook: { id, title, author, totalPages, coverUrl, isbn },
  defaultPastBooks:   [ { id, title, author, totalPages, coverUrl, isbn }, ... ]
};
```

Each book object: `{ id, title, author, totalPages, coverUrl, isbn }`

- `id` — unique string; keep it stable once people have rated (it groups ratings)
- `coverUrl` — optional direct image URL; overrides ISBN/OLID covers
- `isbn` — ISBN *or* OLID; auto-detected; drives the cover when no `coverUrl`
- `totalPages` — used for the progress slider, percentage, and reading speed

Happy reading! 📚