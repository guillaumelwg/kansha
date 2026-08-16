# Kansha — MVP Build Spec

Source of truth for scope: Notion "🍸 User stories & scope MVP (Combined)". This document translates that into implementation detail for Claude Code. Story IDs (US-XX) are referenced throughout — cross-check against Notion if anything here seems to drift from scope.

**Stack:** Ruby on Rails 7.1+, Postgres (hosted on Supabase, DB-only — no Supabase Auth/SDK), Devise + devise-passwordless (magic-link auth, no passwords), Hotwire/Turbo (default Rails 7 behavior, no separate JS framework), Tailwind via `tailwindcss-rails`, Resend via `resend-rb` for transactional + nudge email, deployed on Render.

---

## 1. Data model

### `users`

| field | type | notes |
|---|---|---|
| id | uuid/bigint | |
| email | string, unique, indexed | Devise requirement |
| first_name | string | |
| timezone | string | IANA tz name (e.g. `Europe/Paris`), captured client-side at signup |
| created_at / updated_at | timestamp | UTC, Rails default |

Devise fields added by `devise-passwordless` (no `encrypted_password`).

### `entries`

| field | type | notes |
|---|---|---|
| id | uuid/bigint | |
| user_id | fk → users | author |
| body | text | no length cap, no template |
| created_at / updated_at | timestamp | UTC — this is the field any future recap feature groups by |

Hard delete on US-03 (edit/delete) — no soft-delete flag. Keeps future `getEntriesForPeriod`-style queries simple, per the foundations note in Notion.

**Encryption at rest.** `entries.body` is encrypted at rest via Rails 7 Active Record Encryption (application-level, not end-to-end) — protects against DB breach, backup leak, or unauthorized dashboard access. Caveat to communicate to testers: this isn't zero-knowledge — whoever holds the Rails master key/env secrets could technically decrypt, same trust model as Gmail or Notion. True end-to-end encryption was considered and ruled out for MVP: it blocks server-side reads needed for the post-MVP recap (US-16) and turns sharing (US-10→US-13) into a key-exchange problem.

### `shares`

| field | type | notes |
|---|---|---|
| id | uuid/bigint | |
| entry_id | fk → entries | the shared entry |
| sender_id | fk → users | = entry.user_id, denormalized for query simplicity |
| token | string, unique, indexed | random 20+ char slug, used in the share URL |
| recipient_id | fk → users, nullable | set on first claim only |
| claimed_at | timestamp, nullable | set when recipient first authenticates via this link |
| entry_body_snapshot | text, nullable, encrypted | copy of `entry.body` at claim time — populated only when claimed. Decouples the recipient's copy from the live `entries` row, so it survives if the sender later deletes their account or edits/deletes the entry. |
| sender_name_snapshot | string, nullable | copy of sender's `first_name` at claim time, same rationale as above |
| created_at | timestamp | |

A `share` row is created on-demand — only when the user taps "share" on the post-save confirmation screen (US-10), via `POST /entries/:id/shares` — not automatically for every entry. This avoids a sparse table when most entries are never shared. `recipient_id`/`claimed_at` stay nil until someone signs in through `/shares/:token`.

**Claiming is exclusive, not first-view:** the first authenticated visitor claims the share — this sets `recipient_id`/`claimed_at` and populates `entry_body_snapshot`/`sender_name_snapshot`. Any subsequent visitor to the same link, existing user or not, is denied entirely (a "this gratitude has already been claimed" message, not a read-only view or an error) — only the sender and the claimed recipient can ever access the entry via this link. This also means `entry_body_snapshot` must be encrypted the same way as `entries.body` (see Encryption at rest note above).

---

## 2. Routes & pages

| Route | Story | Story text | Notes |
|---|---|---|---|
| `GET /` | US-04 | As a user, I navigate the app via a 3-section navbar — New Entry, My Gratitudes, Gratitudes Received — and land on New Entry by default when I open the app | New Entry form. Default landing page, authenticated only. |
| `POST /entries` | US-01 | As a user, I can write a free-text gratitude entry in under 30 seconds — no mandatory fields beyond the text, any length from one line to several paragraphs, with no forced "3 things" template | Creates entry → redirect to `GET /entries/:id` (confirmation screen with share CTA). Does not auto-create a `share` row. |
| `GET /entries/:id` | US-10 | As a user, right after saving any entry, I see a simple prompt offering to share it — with a link I copy and send myself (WhatsApp/email/SMS — my choice of channel) | Post-save confirmation screen. Shows the share CTA only — no token or link yet, since the `share` row doesn't exist until the CTA is clicked (see next row). |
| `POST /entries/:id/shares` | US-10 | As a user, right after saving any entry, I see a simple prompt offering to share it — with a link I copy and send myself (WhatsApp/email/SMS — my choice of channel) | CTA action on the confirmation screen — creates the `share` row + token, then reveals the pre-written share text + copyable link in place (Turbo Stream update, no redirect). Not automatic for every entry, avoiding a sparse `shares` table. |
| `GET /entries` | US-02 | As a user, I can scroll back through my past entries in a simple chronological list | My Gratitudes — plain reverse-chronological list, no search/filter. |
| `GET /entries/:id/edit`, `PATCH`, `DELETE /entries/:id` | US-03 | As a user, I can edit or delete a previous entry | Should, not Must — build after core loop + auth are solid. |
| `GET /shares/:token` | US-12 / US-13 | US-12: As a recipient, I create a lightweight account (same signup as US-07: email + first name) before I can view a shared entry. US-13: As a recipient, I can view a single received gratitude in full — this is also the screen I land on immediately after signing up or logging in via a shared link | Claimed-check happens first, before any auth branching: if the share is already claimed, deny immediately — "already claimed" message, no content shown, no signup/login detour — unless the visitor is authenticated as the original sender or the claiming recipient, who can still view it. Otherwise (not yet claimed): unauthenticated → signup/login screen (below), `return_to` this URL; authenticated → claim (sets `recipient_id`/`claimed_at`, writes the snapshot fields), then render entry detail (headline: "{sender.first_name} sent you a gratitude"). |
| `GET /received` | US-14 | As a signed-up user, I can see a history of gratitudes other people have sent me | Gratitudes Received — list of claimed shares where `recipient_id == current_user.id`, rendered from `entry_body_snapshot`/`sender_name_snapshot` on the `share` row, not a live join to `entries`. |
| `GET /received/:share_id` | US-13 | As a recipient, I can view a single received gratitude in full — this is also the screen I land on immediately after signing up or logging in via a shared link | Same detail view as above, reached from the received list. |
| Devise passwordless routes | US-07/08 | US-07: As a user, I sign up with my email and first name (magic-link, no password) before writing my first entry. US-08: As a user, I stay logged in across visits on the same device/browser, without re-verifying by email every time | `/users/sign_in` (single email+name field, "Continue" button), magic-link callback, session cookie persists across visits. |
| `DELETE /account` | US-09 | As a user, I can delete my account, which also removes my entries (including ones I sent or received) | Cascading delete: entries authored, shares sent/received. Confirm destructive-action UX before wiring — this is a real data-loss action. |

Navbar (US-04): New Entry / My Gratitudes / Gratitudes Received. Lands on New Entry by default — the other two are one tap away, not nested.

---

## 3. Auth flow (US-07/08/09/12)
- Single screen, single field beyond email: email + first name, one "Continue" button. No separate signup/login choice — the backend decides:
  - New email → creates `User`, sends magic link.
  - Existing email → sends magic link to existing account (ignores the name field if resubmitted differently — don't silently overwrite `first_name` on login).
- Magic link click → Devise session established → long-lived session cookie. No re-verification unless session is cleared/expired.
- Timezone captured via a hidden form field populated by `Intl.DateTimeFormat().resolvedOptions().timeZone` in JS on page load, submitted with the signup form. Store once, don't ask again.
- `return_to` param carries through the auth flow so a recipient clicking a share link lands on the entry (US-13), not on New Entry.

---

## 4. Email flows (Resend)
1. **Magic link** — transactional, sent on every sign-in attempt (new or returning user).
2. **Nudge (US-06) — post-MVP.** Out of pure MVP scope — add once the core app is functional. 2-3x/week, not daily. No personalization, no streak logic (explicitly out of scope) — a simple scheduled send to all users with an account older than 24h. Trigger via a Render Cron Job hitting a rake task (avoids needing Sidekiq/Redis on a free-tier deploy). Exact days TBD — avoid same weekday pattern people tune out. **Must include an unsubscribe link** in every send — standing requirement, not optional.
3. **Share notification** — none. US-10 is manual copy-link only; automated in-app send is US-11, explicitly deferred post-MVP.

---

## 5. Known risk zones (flagged from prior analysis — check these manually, don't trust first-pass output)
- **Timezone boundaries.** Any "this week" logic must resolve against `user.timezone`, not server time. Test manually with a non-UTC user before considering this done.
- **Sender/recipient identity split.** A `User` can be sender on one `share` and recipient on another. Watch for Claude Code conflating "my entries" (`US-02`, entries where `user_id == current_user.id`) with "entries shared with me" (`US-14`, shares where `recipient_id == current_user.id`) — these must stay two separate queries, never merged. Now more clear-cut in the data itself: My Gratitudes reads from `entries`, Gratitudes Received reads from `shares` snapshot fields — there's no shared table to accidentally conflate.
- **First-claim race on `/shares/:token`.** Only the first authenticated visitor should set `recipient_id`/`claimed_at` and get access. Verify what happens on a second visit by a different user — must be denied entirely (no content, no claim), not view-only and not a generic error.
- **Cascading delete (US-09) — resolved.** Deleting a user removes entries they authored and shares they sent/received as raw rows, but a recipient's Gratitudes Received view is unaffected either way: it renders from `entry_body_snapshot`/`sender_name_snapshot` on their own `share` row, not a live join to `entries`. Verify a sender's account deletion does not remove or blank out an entry from a recipient's Received list — that would indicate the snapshot isn't being used correctly.

---

## 6. Explicitly out of scope (reiterated from Notion — do not build)
Native mobile, streak mechanics, formal A/B infra, in-app automated send (US-11), reply-to-received (US-15), writing prompts (US-17), tag-based (@username) linking, age-adaptive UX.
