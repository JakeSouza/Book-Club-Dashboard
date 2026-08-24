# 📖 Booked and Busy — Book Club Site

A static book-club website hosted free on **GitHub Pages**, with shared ratings, reading progress, member stats, and an in-app **Admin panel** to manage the book list. Shared data is powered by a free **Supabase** backend using a **normalized schema** (one row per book, one row per reader, ratings referencing both via foreign keys).

## Features

- Club name across the top of every page
- **Current Book** tab — current book cover centered, title, author, live group rating, your reading status
- **Past Books** tab — grid of past reads, each with its collective group rating (avg ★ + number of raters)
- **Rate &amp; Progress** tab — 1–5 star rating, page-progress slider + number (live %), "finished" checkbox, one-click "Mark as finished"
- **Reader Stats** tab — every member with their average rating and average reading speed (pages/day)
- **Admin tab** (passcode-protected) — add / edit / delete current &amp; past books, with **ISBN or OLID auto-fill** from Open Library (pulls title, author, page count, and cover automatically)
- Real book covers from the **Open Library Covers API** (free, no key), with an auto-generated fallback when no cover exists

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

## 2. Enable shared data with Supabase (free, \~5 minutes)

Create a free Supabase project, make three tables, then copy two values into your site's `CONFIG`.

### a. Create a Supabase project

1. Go to [supabase.com](https://supabase.com) → **Start your project** / **Sign in** (GitHub or email; no credit card needed; Free tier is plenty).
2. Click **New project**.
3. Fill in the form:
  - **Name:** e.g. `book-club`
  - **Database Password:** set a strong password and save it somewhere safe (your DB password; not used by the site)
  - **Region:** closest to you
  - **Plan:** Free
4. Click **Create new project** and wait \~2 minutes. You'll land on a dashboard with a left sidebar.

> Leave the **Data API** enabled (it's on by default). If you ever turned it off, re-enable it under **Integrations → Data API** and make sure `books`, `members`, and `book_club` are exposed.

### b. Create the three tables

1. Left sidebar → **SQL Editor** → **+ New query**.
2. Paste the SQL below → **Run** (▶). It drops any old tables, creates the three new ones with foreign keys, and adds read/write security policies.

```sql
-- Fresh normalized schema. (Drops old tables — only run if you have no data to keep.
-- If you do have data to keep, ask for a migration script instead.)
drop table if exists wishlist cascade;
drop table if exists book_club cascade;
drop table if exists books cascade;
drop table if exists members cascade;

-- Books: one row per book. status = 'current' (exactly one allowed) or 'past'.
-- position (bigint) orders past books newest-first.
create table books (
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
create unique index books_one_current on books (status) where status = 'current';

-- Members: one row per reader. The reader's name lives here only.
create table members (
  user_id    uuid primary key references auth.users(id) on delete cascade,
  name       text,
  joined_at  timestamptz not null default now()
);

-- Ratings / progress: one row per member per book, referencing both via FKs.
-- Deleting a book or member cascades to its ratings (no orphans).
create table book_club (
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

-- Wishlist: shared "books we want to read next", one row per saved suggestion.
create table wishlist (
  id         bigint generated always as identity primary key,
  user_id    uuid not null references members(user_id) on delete cascade,
  work_id    text,
  title      text not null,
  author     text,
  cover_url  text,
  added_at   timestamptz not null default now()
);

-- Row Level Security.
--   Reads  → public (anyone with the link can see the club shelf, ratings, reviews).
--   Writes → require a signed-in user, and you can only write your own rows.
--   Books  → any signed-in member may add/edit (the Admin passcode still gates the UI).
alter table books     enable row level security;
alter table members   enable row level security;
alter table book_club enable row level security;
alter table wishlist  enable row level security;

create policy "books read"   on books for select using (true);
create policy "books write"  on books for all    using (auth.uid() is not null) with check (auth.uid() is not null);

create policy "members read"  on members for select using (true);
create policy "members write" on members for all   using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "ratings read"  on book_club for select using (true);
create policy "ratings write" on book_club for all   using (auth.uid() = user_id) with check (auth.uid() = user_id);

create policy "wishlist read"   on wishlist for select using (true);
create policy "wishlist write"  on wishlist for insert with check (auth.uid() = user_id);
create policy "wishlist delete" on wishlist for delete using (auth.uid() = user_id);

> **Already created the tables before the review feature?** Just add the column — no need to drop data:
> ```sql
> alter table book_club add column if not exists review text;
> ```

> **Adding the wishlist table to an existing project** (no data loss):
> ```sql
> create table if not exists wishlist (
>   id         bigint generated always as identity primary key,
>   user_id    uuid not null references members(user_id) on delete cascade,
>   work_id    text,
>   title      text not null,
>   author     text,
>   cover_url  text,
>   added_at   timestamptz not null default now()
> );
> alter table wishlist enable row level security;
> create policy "wishlist read"   on wishlist for select using (true);
> create policy "wishlist write"  on wishlist for insert with check (true);
> create policy "wishlist delete" on wishlist for delete using (true);
> ```

3. Confirm via **Table Editor** — you should see `books`, `members`, `book_club` (all empty, which is correct).

### c. Find your Project URL and API key

You need two values: the **Project URL** and a **client-side API key**.

**Project URL** (looks like `https://abcdefghijklmnop.supabase.co`)
- **Easiest:** click **Connect** (top-right) → pick a framework tab (e.g. "ReactJS") → the URL is in the snippet, e.g. `const SUPABASE_URL = "https://…supabase.co"`.
- **Or:** **Integrations → Data API** in the left sidebar → the **API URL** is listed.

**API key** (a long `eyJ...` JWT — use either the new **publishable key** or the legacy **anon key**)
- Go to **Settings → API Keys** in the left sidebar.
- **New projects:** click **Create new API Keys** → copy the **Publishable key** (client-safe).
- **Older projects:** switch to the **Legacy API Keys** tab → copy the **anon** key.
- Never use the `service_role` / secret key in a web page.

### d. Add your keys to `index.html`

Edit the `CONFIG` block near the top of the `<script>`:

```js
const CONFIG = {
  clubName: "Booked and Busy",
  supabaseUrl: "https://YOURPROJECT.supabase.co",   // ← Project URL
  supabaseAnonKey: "YOUR_PUBLISHABLE_OR_ANON_KEY",   // ← API key
  booksTable: "books",
  membersTable: "members",
  ratingsTable: "book_club",
  wishlistTable: "wishlist",
  adminPasscode: "bookclub2026",   // ← CHANGE THIS
};
```

Save, commit, push. The site now reads/writes Supabase directly — no demo/local fallback.

### e. Enable Email auth (so members are the same person on every device)

The schema in step 2b keys `members`, `book_club`, and `wishlist` on Supabase Auth (`uuid` → `auth.users(id)`), and the RLS policies require `auth.uid()` for writes. So you must enable email login:

1. **Dashboard → Authentication → Sign In / Providers** → make sure **Email** is enabled (it's on by default).
2. **Authentication → Settings → "Confirm email"** → turn it **OFF** for instant signup (recommended for a small, trusted club sharing a link). Leave it on if you'd rather members confirm via email before logging in.
3. **Authentication → URL Configuration** → set the **Site URL** to your GitHub Pages URL (e.g. `https://username.github.io/repo-name`).

That's it — no extra keys. The site's header shows a **Sign in / Sign up** bar (email + password). Each member signs up once; their `user_id` becomes their stable `auth.uid()`, so ratings, progress, reviews, and the wishlist follow them across devices.

> The **anon/publishable key** from step 2c is still the only key in the page. Reads use it; authenticated writes attach the user's session token automatically. Security is enforced by RLS (`auth.uid()`), not by hiding keys.

---

## 3. Managing books (the Admin tab)

Books are managed **through the UI** — each book is its own row, so editing one never clobbers another.

1. Click the **⚙️ Admin** tab → enter your passcode → **Unlock**.
2. **Add a book**: type an ISBN or OLID → **🔍 Auto-fill from ISBN / OLID** → title/author/pages/cover fill in → pick "Add to Past Books" or "Set as Current Book" → **Add book**.
3. **Edit / Delete** any book via the buttons on each row. Setting a new current book automatically demotes the old one to the top of Past. Deleting a book also removes its ratings (foreign-key cascade).
4. **Lock** re-secures the panel.

### ISBN vs OLID

- **ISBN** (10/13 digits) → e.g. `9780525559474` → cover from `https://covers.openlibrary.org/b/isbn/{ISBN}-L.jpg`
- **OLID** (starts with `OL`) → e.g. `OL28401522M` → cover from `https://covers.openlibrary.org/b/olid/{OLID}-L.jpg`

`openlibrary.org/books/...` pages are indexed by OLID, so if you copied an identifier from a book page's URL, it's an OLID. The site auto-detects both — just paste what you copied. Auto-fill also grabs a direct cover URL into the "Cover image URL" field, which overrides the Covers-API lookup.

---

## 4. The data model

```
books (one row per book)
  id, title, author, isbn, cover_url, total_pages, status, position, added_at
  status ∈ {current, past}  — exactly one 'current' allowed (partial unique index)

members (one row per reader — keyed by Supabase Auth user id)
  user_id (uuid) → auth.users(id), name, joined_at
  name lives here only — update once, reflected everywhere

book_club (one row per member per book — ratings/progress/review)
  user_id → members(user_id)  on delete cascade
  book_id → books(id)          on delete cascade
  rating, progress, review, finished, started_at, updated_at
  unique (user_id, book_id)

wishlist (one row per saved suggestion — "books we want to read next")
  user_id → members(user_id)  on delete cascade
  work_id (Open Library work OLID), title, author, cover_url, added_at
```

Reader identity is the Supabase Auth `auth.uid()` (uuid) — sign in once, same person on every device. The `members` row is created on first sign-in; the name you enter on the Rate tab is stored once there.

---

## 5. How reader identity works (Supabase Auth)

Members **sign in with email + password** in the header bar. Their `user_id` is the real Supabase Auth `auth.uid()` (a uuid) — so the same account is the same person on every device, browser, or phone. No more random localStorage id.

- First visit → enter email + password → **Sign up** (or **Sign in** if you already have an account). With "Confirm email" turned off, signup logs you in immediately.
- Your `members` row is keyed by your auth id; the name you enter on the Rate tab is stored once and follows you everywhere.
- Ratings, progress, reviews, and wishlist saves are all tagged with your stable auth id — "✓ You've finished" on the current book, the "(you)" row in stats, and your wishlist items all recognize you on any device.
- **Reads stay public** (anyone with the link can see the shelf, ratings, reviews). **Writes require sign-in**, and you can only write your own rows — enforced by RLS, not just the UI.

> Tip: each member signs up once with their own email. The maintainer then sets the current/past books in the Admin tab (still passcode-gated). If you later want server-enforced maintainer-only book edits, tighten the `books write` policy to specific auth ids.

## 6. Reader stats — Total pages read

The Reader Stats tab shows **Total pages read** per member (replacing the old reading-speed metric):

- Sums each member's `progress` across every book row, capped at each book's total pages (so it never over-counts).
- Inclusive — anyone who logs any progress contributes, even if they haven't finished.
- `started_at`/`updated_at` are still recorded for potential future use, but no longer drive a flawed pace metric.

---

## 7. Privacy &amp; security notes

- The Supabase **publishable / anon key** is safe to expose in a static page — security is enforced by **Row Level Security**, not by hiding the key.
- Default policies let anyone with the link read/write all three tables (fine for a trusted small club).
- The **Admin passcode** is a client-side gate (visible in JS source) — good enough for a trusted club, not server-side security. For true enforcement: add **Supabase Auth**, create maintainer accounts, and tighten the `books`/`members` write policies to `auth.uid()`.
- **Change the default passcode** (`bookclub2026`) before deploying.

---

## 7b. Suggestions tab (Open Library, taste-based)

The **💡 Suggestions** tab recommends books based on taste, and keeps a shared wishlist.

**Taste source.** Use the **"Taste from"** dropdown:

- **The whole club** — averages every member's ratings, takes the top-rated books, and recommends other works by those authors + books in those subjects.
- **A single member** — picks that member's own top-rated books instead. Each member who's rated books appears by name; "(you)" marks your own taste. Great for surfacing "books like the ones Marco loved."

Then click **✨ Find recommendations**. Each card shows cover, title, author, a "why" reason, and two buttons:

- **＋ Add to club** — pre-fills the Admin add-book form (title, author, OLID, cover). Enter the **page count**, then **Add book**.
- **🔖 Save** — saves it to the shared wishlist for later.

**🔖 Reading wishlist** (below the suggestions) is a shared "books we want to read next" list:

- Anyone can save a suggestion here; the card shows who nominated it.
- **＋ Add to club** promotes a wishlist item straight into the Admin form.
- The nominator can **✕ Remove** their own entry.

Requirements &amp; notes:

- **Needs ISBNs on the top-rated books** (club or member) — without an ISBN/OLID we can't trace a book to its author. Add ISBNs in Admin, then retry.
- **One-click add needs the page count** — Open Library's work/subject listings don't include page counts, so you fill that one field.
- **Wishlist needs the `wishlist` table** — if you see "run wishlist SQL," add the table (see the ALTER note in step 2b).
- Like covers, this only works on the **deployed site** (Open Library is blocked in some local previews).

## 8. Troubleshooting

- **"Could not save" / nothing shared:** check `supabaseUrl` (no trailing slash) + API key, and that you ran the SQL incl. the FKs, the partial unique index, and the RLS policies. Confirm the **Data API** is enabled and exposes all three tables (**Integrations → Data API**).
- **Covers not loading:** you probably pasted an **OLID** from a `/books/` URL. The site auto-detects both — paste the identifier itself (e.g. `OL28401522M`), not the whole URL. Best practice: paste ISBN/OLID → **Auto-fill** → cover URL is filled → add the book.
- **Some covers fall back to generated art:** expected — not every edition has a cover on Open Library. `?default=false` makes missing covers 404 (not a blank placeholder), triggering the fallback. Try another edition's ISBN for the real cover.
- **Can't find "Settings → API":** keys are now under **Settings → API Keys**; the URL is in **Integrations → Data API** / the **Connect** dialog. See step 2c.
- **Migrating from the old (JSON-blob) schema:** the script in 2b drops and recreates the tables. If you already added books/ratings you want to keep, ask for a migration script (it reads the old `books` JSON blob and the old `book_club` rows, then inserts normalized rows into the new tables).

---

## 9. Quick reference — CONFIG block

```js
const CONFIG = {
  clubName: "Booked and Busy",     // header + browser tab
  supabaseUrl: "",                     // https://YOURPROJECT.supabase.co
  supabaseAnonKey: "",                  // publishable or anon key (client-safe)
  booksTable: "books",
  membersTable: "members",
  ratingsTable: "book_club",
  adminPasscode: "bookclub2026",       // CHANGE THIS
};
```

Happy reading! 📚