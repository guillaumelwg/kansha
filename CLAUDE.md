# CLAUDE.md — Kansha

Standing instructions for Claude Code on this repo. `spec.md` describes what to build; this file describes how. Read both before starting any slice.

## Stack

- Ruby on Rails 7.1+, Postgres (hosted on Supabase — DB connection only, not using Supabase Auth/SDK)
- Devise + devise-passwordless (magic-link auth, no passwords)
- Hotwire/Turbo — default Rails 7 behavior, no separate JS framework, no React
- Tailwind via `tailwindcss-rails`
- Resend via `resend-rb` for transactional + nudge email
- Deployed on Render

## Dependencies — standing rule

**Before adding any gem, verify it's current and actively maintained** (check last release date / repo activity) rather than relying on pattern-recognition from training data. This applies to every dependency, but especially: `devise-passwordless` (unverified as of spec-writing — confirm it's the right/current package before wiring auth), `resend-rb`. Flag anything uncertain instead of guessing.

## Auditability convention (why this matters here)

I'm supervising this build without deep current Rails fluency (rusty since a bootcamp ~6 years ago). Optimize for code I can read and verify, not for cleverness:

- Simple, conventional Rails patterns — favor what a Rails guide would show over a clever shortcut.
- If logic gets non-trivial, pull it into an explicitly named service object (e.g. `app/services/claim_share.rb`) rather than burying it in a fat controller or a model callback — makes it easier for me to find and review the risky bits.
- No metaprogramming, no clever `send`/`method_missing` tricks, no abstractions "for future flexibility" that aren't needed by a locked user story.
- When implementing anything from the "Known risk zones" section of `spec.md` (timezone logic, sender/recipient identity split, first-claim race, cascading delete), pause and explain the approach in plain language before writing it — these are the spots most likely to be subtly wrong.

## Folder structure

Standard Rails conventions — no deviation unless there's a specific reason, in which case explain it here.

```
app/
  controllers/
  models/
  services/       # non-trivial business logic, named by action (e.g. claim_share.rb)
  views/
  mailers/        # Resend-backed mailers (magic link, nudge)
  javascript/      # Turbo/Stimulus only, no React
config/
  routes.rb
db/
  migrate/
spec/ (or test/)   # see Testing below
```

## Naming & data conventions

- `created_at`/`updated_at` stay UTC (Rails default) — never store local time.
- Timezone lives on `User#timezone`, set once at signup, read wherever "this week"/"this month" logic is needed.
- Hard deletes only for `entries` (no soft-delete flag) — keep future read queries simple.
- Keep "entries I wrote" and "entries shared with me" as two distinct, separately named queries — never merge into one method with a flag.

## Testing / verification

Full test suite is not the goal for a 3-week solo MVP. Use RSpec (or Minitest, whichever ships faster) for the risk-zone logic only — timezone boundaries, claim race, cascading delete. Everything else gets manual QA per the verification checklist (separate doc). Don't over-invest in test scaffolding for straightforward CRUD.

## Commands

Ruby is managed via rbenv (`~/.rbenv`), pinned to 3.3.0 in `.ruby-version`. If a fresh shell reports the macOS system Ruby (2.6.x) instead, `rbenv`'s shims aren't on `PATH` yet — either open a new shell or run `export PATH="$HOME/.rbenv/shims:$PATH"`.

- `bundle install` — install gems
- `bin/dev` — run the app (Puma + Tailwind watcher via Procfile.dev)
- `bin/rails s` — run the app without the Tailwind watcher (CSS won't rebuild on change)
- `bin/rails db:create` / `bin/rails db:migrate` — needs `DATABASE_URL` set (via `.env`, see below)
- `bin/rails console` — REPL

**Database:** `DATABASE_URL` is read from `.env` (via `dotenv-rails`, dev/test only) and Rails automatically merges it into whichever environment is active — see `.env.example` for the format. Point it at the real Supabase connection string (Supabase dashboard → Connect → URI, Session Pooler recommended). Without a real value here, `db:create`/`db:migrate`/`rails s` will fail to connect.

## Session logging

At the end of each Claude Code session, summarize in plain terms: what was built, anything you (Claude Code) were unsure about or made a judgment call on, and any spot where I should manually double-check before moving on. This feeds the build logbook directly — keep it factual, not narrated.
