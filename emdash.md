# EmDash deployment & operations

Lessons from deploying and operating EmDash CMS sites (Astro on Cloudflare Workers with D1/R2, and Node with SQLite). Read alongside the official docs at https://docs.emdashcms.com and the cloudflare.md skill — this file covers the EmDash-specific gotchas the docs gloss over; platform-level wrangler, domains, secrets, and runtime lessons live there. Applies when building, seeding, translating, or deploying EmDash sites.

## Environments

- Develop locally on the Node adapter + SQLite + local storage; build for Cloudflare with the `@astrojs/cloudflare` adapter + `@emdash-cms/cloudflare` (`d1({binding:"DB"})`, `r2({binding:"MEDIA"})`). Switch via an env var inside `astro.config` so local dev never needs Cloudflare bindings.
- Deploy is `astro build` then `wrangler deploy`. First deploy auto-creates D1/R2 resources from the configured names; keep binding names (`DB`, `MEDIA`) stable and identical to the adapter config.
- Auth, secrets, and the wrangler-under-Deno gotchas live in cloudflare.md — read it before a first deploy.

## Wrangler config redirection

- With `@astrojs/cloudflare`, `wrangler deploy` uses the adapter-generated `dist/server/wrangler.json` — never deploy `--config wrangler.jsonc` (it re-bundles `main` from source and fails on Astro virtual modules). Routes declared in `wrangler.jsonc` still flow into the generated config: keep them and the adapter's `routes` option consistent — observed when they disagree, the `wrangler.jsonc` routes deploy.
- Domain and route strategy (custom domains, wildcard traps, zone-route precedence) lives in cloudflare.md.

## First boot & seeding

- Migrations run and the bundled seed applies on the FIRST request only when the database is empty AND setup is incomplete. A partially failed bootstrap poisons the gate (collections exist → never retried): if first boot fails, wipe the database and let it re-bootstrap cleanly.
- The seeder defaults content locale to `en`. With i18n enabled, pin `locale` on every seed content entry or all content strands in the wrong locale.
- Seed `$media` URLs are fetched at apply time. After a domain cutover they can become self-referential (your worker now owns the hostname) and abort the whole seed — self-host seed media via the media API (`/_emdash/api/media/file/<storage_key>` serves from R2 without needing a database row), and upload the objects before first boot.
- Re-applying a seed (`emdash seed --on-conflict update`) re-downloads `$media` and creates DUPLICATE media rows — dedupe against live content references afterwards. Verify `--no-content` actually skips content.
- `emdash seed` CLI operates on local SQLite only. For remote databases use the REST API with a Bearer token, or a direct D1 SQL import (order tables child-first for foreign keys; NULL out columns referencing rows you do not import, e.g. revision ids and author ids).
- Commit signing (1Password SSH) fails with "failed to write commit object" when the agent locks — unlock and retry.

## i18n & translations

- Model: Astro i18n routing + one content row per locale joined by `translation_group`. Fields have a `translatable` flag (non-translatable fields sync across the group). Seed entries accept `locale` + `translationOf`; so do the CLI and REST API.
- `prefixDefaultLocale: true` breaks `/_emdash/admin` — keep the default strategy: default locale unprefixed, others under `/{locale}/`.
- The built-in fallback chain aborts when the loader reports "not found" as an ERROR instead of a null entry — implement locale fallback explicitly: query the requested locale, then the default locale, then resolve the sibling slug via `getTranslations(collection, id)`.
- Slugs are per-locale and auto-derived only from `title`/`name` fields, so sibling slugs legitimately differ. Never assume slug parity: resolve sibling URLs via `getTranslations`; strip the locale prefix from entry ids (`en/slug`) before building URLs; `data.id` is the stable ULID and `data.translationGroup` links the group. Mixed-locale listings merge by `translationGroup`, not id.
- `content.create` with `translationOf` rejects duplicate locales ("Translation already exists in locale ...") — resolve the existing sibling and update it instead.
- Admin content-list dates come from the collection's `dateField` — point it at the source datetime field or entries display import timestamps.
- A page whose per-locale paths diverge beyond the locale prefix (e.g. `/kalender` vs `/en/calendar`) needs ONE path map (locale → path) that the language toggle, the nav menu, and the active-state check all derive from. Patching the toggle with per-page conditionals is how the "toggle 404s on the new page" bug class happens — new pages extend the map, never the toggle logic.
- Adding a page touches more than routes: route files for both locales, UI-string dictionary (type + every locale map — dictionary keys are code, International English), nav (menu rows are admin data with locale-agnostic paths; keep label/path translation maps), sitemap, head alternates/feeds, and the locale toggle. Missing any one surfaces later as a menu or toggle bug.
- URL fragments never reach the server. Anything anchor-dependent (locale toggles targeting a renamed path, reveal-on-hash elements) must resolve client-side.

## Plugins

- Standard format: descriptor (build time) + `definePlugin` entry (runtime). Trusted on Node, sandboxed isolates on Cloudflare (see cloudflare.md for the runtime limits — write resumable jobs, not unbounded loops).
- `ctx.content.create`/`update` stage DRAFT revisions on revision-supporting collections; publish via `ctx.content.publish(collection, id, {_rev})` (capability `content:publish`; `_rev` from `ctx.content.getVersioned`). Forgetting publish is the classic "my row didn't change" bug.
- The plugin content API cannot set `slug`/`status`. Publish refuses slugless routable collections, and slugs auto-derive only from `title`/`name` — give collections a `title` field and populate it with the translated title.
- Durable work: plugin storage collections (indexed where-filters, `updateIf` for claims) + KV locks. Background-after-response dies on serverless isolates — register plugin cron (`ctx.cron.schedule` in `plugin:activate`; the Cloudflare minute Cron Trigger drives it via the scheduled handler) and reclaim stale claims (`running` untouched > 10 min → back to queued).
- Plugin lifecycle/install state + cron schedules live in `_plugin_state` / `_emdash_cron_tasks`. Wiping the database removes cron registration and settings — re-insert state/cron rows (or reinstall) or hooks and drains silently stop.
- Settings schema auto-generates the admin UI; stored in `options` as `plugin:<id>:settings:<key>`. `settings:*` KV keys route there too.
- `content:afterDelete` runs after the row is gone — group/relationship resolution via the deleted row is impossible; persist group/target ids in your own state and scan for them.
- Job updates on claims: use `updateIf` with explicit scalar sets. Spreading whole claim documents back into `put` re-binds nested objects and fails with "Cannot bind [object Object] to SQLite".
- Hook error policy: use `"continue"` for side-effect hooks so one failure doesn't abort the pipeline; log with `ctx.log` (it reaches `wrangler tail`).
- `plugin:activate` never fires for config plugins at boot — it runs only on an explicit admin enable. A cron schedule registered there never lands (and the scheduler never consults plugin state; it runs rows with `enabled = 1`). Register schedules from hooks that DO run (a content hook, an admin page load): `ctx.cron.schedule` is an upsert that re-enables the row, so re-arming self-heals.
- The per-task cron handler object form (`cron: { task: { handler } }`) fails at dispatch with "handler is not a function" — use the function form `cron: async (event, ctx)` and switch on `event.name`.
- `content:afterSave` hooks are deferred (waitUntil) but capped at a 5-second timeout — long provider calls (LLM round-trips are ~9-10 s) belong in cron with a per-tick budget, not in the save hook.
- Plugin routes can return raw HTTP responses: declare the route with `response: "raw"` and return a `Response` (HTML confirm pages, iCalendar feeds) — `public: true` skips auth for visitor-facing ones.
- Trusted local plugins compile into one bundle — sibling plugins import each other's exported modules directly (shared LLM clients, detectors) instead of calling each other over HTTP.

## Debugging playbook

- Dev server returning 200 with a tiny/truncated body = an exception mid-stream; ResponseSentError in the log masks the real error. When dev lies, run `astro check` and `astro build` — builds name missing imports and type errors precisely.
- Wrapper/reroute pages fail the BUILD, not dev, when their relative import depth is wrong (`../templates` vs `../../templates`).
- `astro.config`, plugin sources, and `file:` dependency changes need a full dev-server restart; Vite's dep optimizer caches `file:` packages — restart with `--force` (or delete `node_modules/.vite`) when plugin edits don't load.
- Astro v6+: `Astro.locals.runtime.env` throws — use `import { env } from "cloudflare:workers"` on Workers and keep a Node fallback for local.
- Legacy `.html`-style redirects: middleware in front of routing, skipping `/_emdash` and static assets. On Workers query D1 via `import { env } from "cloudflare:workers"`; locally via node:sqlite.
- `Astro.redirect` after the response stream has started throws ResponseSentError and truncates the body — resolve redirects in frontmatter before rendering, or render a not-found view instead of redirecting.
- Wrangler D1 JSON output has an npm-notice preamble — parse from the first `{`, not line one.
