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
  javascript/     # Turbo/Stimulus only, no React
config/
  routes.rb
db/
  migrate/
spec/ (or test/)  # see Testing below
```

## Naming & data conventions
- `created_at`/`updated_at` stay UTC (Rails default) — never store local time.
- Timezone lives on `User#timezone`, set once at signup, read wherever "this week"/"this month" logic is needed.
- Hard deletes only for `entries` (no soft-delete flag) — keep future read queries simple.
- Keep "entries I wrote" and "entries shared with me" as two distinct, separately named queries — never merge into one method with a flag.

## UI/UX approach
- Design and build every screen mobile-first: default styles target a ~375–430px viewport, use Tailwind's `sm:`/`md:` breakpoints to progressively enhance for wider screens, not the reverse.
- Touch targets (buttons, nav items, form controls) minimum 44x44px.
- No hover-dependent interactions — everything must work on tap alone.
- Test each slice at a phone-width viewport before marking it done, not just desktop.

## Design tokens
Locked token set — "Warm ink (sage)" direction, from the Visual Design Foundations deck (Option 1, recommended over Soft dusk and Quiet moss). Reference these on every screen instead of picking colors ad hoc; this is what keeps Slice 1 through Slice 6 visually consistent without a Figma file.

- **Background:** `#F6F1E7`
- **Text ("ink"):** `#2B2B23`
- **Accent (sage — CTAs, links, active states):** `#6E8C74`
- **Muted (secondary text, timestamps, placeholders):** `#8C7B5E`
- **Border/divider:** `#DDD3C0`
- **Typography:** `Fraunces` (serif) for screen titles only (e.g. "New entry") — system sans-serif stack for everything else: inputs, navigation, buttons, body text. Two families, not one — titles carry the tactile-journal warmth, UI chrome stays plain and legible.
- **Mood:** tactile paper journal. Warm without being saccharine, calm without being sleepy. Rounded corners and soft shadows are fine but shouldn't tip into the gamified-pastel look of apps like Finch — see the benchmark deck for what to stay clear of.
- **Spacing:** Tailwind's default scale (4px base unit) — no custom scale. Favor generous vertical spacing between UI groups (16–24px) over dense layouts.

Apply retroactively to Slices 0-2 screens already built (auth, navbar, New Entry, My Gratitudes) as part of the next session touching each, not as a standalone restyle pass — fold it into Slice 2.5 (Profile screen) at minimum, since that's new.

## Testing / verification
Full test suite is not the goal for a 3-week solo MVP. Use RSpec (or Minitest, whichever ships faster) for the risk-zone logic only — timezone boundaries, claim race, cascading delete. Everything else gets manual QA per the verification checklist (separate doc). Don't over-invest in test scaffolding for straightforward CRUD.

**On the Verification Checklist Tracker specifically:** it lives in Notion, not in this repo. You (Claude Code) have no access to it and can't look it up or run its rows directly — don't search the repo for it. Every task brief will paste the relevant checklist criteria inline, in full, in its own "Manual QA" step. Treat that inlined text as the actual checklist for the session; verify against it directly rather than trying to locate an external source. If a brief ever references checklist rows without spelling them out, flag that as a gap in the brief rather than guessing or skipping the check.

## Commands
- `bin/rails s` — dev server (localhost:3000). Uses `.env` (development DB — real Supabase dev instance).
- `bin/rails db:migrate` — run pending migrations. Runs against `.env`'s DATABASE_URL in whatever RAILS_ENV is active.
- `bin/rails tailwindcss:build` — rebuild compiled CSS after adding/changing Tailwind classes. There's no watcher process running by default in this setup (no `bin/dev` yet, no Procfile) — if styles don't seem to apply, rebuild manually.
- `bundle exec rspec` — run the RSpec suite (risk-zone logic only, per Testing section below). No `bin/rspec` binstub yet.
- Test DB is **local Postgres**, not Supabase — see `.env.test` (created Slice 3). `RAILS_ENV=test` would otherwise inherit `.env`'s DATABASE_URL and hit the same Supabase dev database as `development`, which is unsafe for a suite that includes non-transactional tests. Requires local Postgres running (`brew services start postgresql@16`) with a `kansha_test` database (`createdb kansha_test`) and migrated (`RAILS_ENV=test bin/rails db:migrate` — not `db:schema:load`, since `db/schema.rb` includes Supabase-only extensions like `supabase_vault` that don't exist on local Postgres).

## Session logging
At the end of each Claude Code session, summarize in plain terms: what was built, anything you (Claude Code) were unsure about or made a judgment call on, and any spot where I should manually double-check before moving on. This feeds the build logbook directly — keep it factual, not narrated.
