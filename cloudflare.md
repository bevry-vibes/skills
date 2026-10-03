# Cloudflare Workers deployment & operations

Workers is the deployment platform for sites and APIs; Cloudflare Pages is deprecated — build new projects as Workers (static assets + a module worker), and migrate Pages projects per https://developers.cloudflare.com/workers/static-assets/migration-guides/migrate-from-pages/. This file covers wrangler auth and config, domains and routes, secrets, and the gotchas the docs gloss over; project topology lives in the local tweaks, and EmDash-specific deployment in emdash.md.

## Auth & permissions

- `wrangler login` (OAuth) covers script deploys, bindings, and attaching custom domains; the granted scopes are listed in `~/.config/.wrangler/config/default.toml`, and that token works as a Bearer for account-scoped REST endpoints where the scopes match (Pages project/domain APIs, worker domains).
- Zone-scoped REST — DNS record writes, zone route listings — rejects the OAuth scheme outright ("Authentication error" / "method not allowed for this authentication scheme"). Those need an API token with Zone permissions, or the dashboard. Prefer custom domains (below), which provision DNS without raw zone access.
- API tokens scoped to a narrow product (e.g. Workers AI) deploy nothing — run `wrangler whoami` before debugging any "no access" failure.

## Config & secrets

- `wrangler.jsonc` is tracked: name, main, compatibility_date, assets, routes, bindings (D1/R2/KV), crons. Secrets never live in it — build-time config inlines into client bundles. Production secrets go through `wrangler secret put`; local values sit in gitignored `.dev.vars` (wrangler dev reads it beside the config), with a committed `.dev.vars.example` naming every variable.
- `compatibility_date` ≥ 2025-04-01 populates `process.env` from secrets and vars; older dates need the `nodejs_compat_populate_process_env` flag.
- Static-site shape: a thin module worker routes the API paths and falls through to `env.ASSETS.fetch(request)` for everything else. Migrating off Pages, the `functions/` directory folds into that router — Pages Functions' `onRequestGet`/`onRequestPost` exports become plain handler functions, and the file-path routing becomes explicit pathname matching.
- Astro SSR (`@astrojs/cloudflare`): `wrangler deploy` uses a REDIRECTED config — `.wrangler/deploy/config.json` → the adapter-generated `dist/server/wrangler.json`. Routes declared in the repo's `wrangler.jsonc` still flow into the generated config, so keep them and the adapter's `routes` option consistent; observed behaviour when they disagree: the `wrangler.jsonc` routes deploy. Never `wrangler deploy --config wrangler.jsonc` on these projects — explicit config re-bundles `main` from source and fails on Astro virtual modules (`virtual:astro:app`, `astro:middleware`); the generated config wraps the built server output instead. `wrangler triggers deploy` syncs cron triggers without re-uploading.

## Domains & routes

- Custom domains (`routes: [{ pattern, custom_domain: true }]`) provision the DNS record and certificate themselves, work over the wrangler OAuth token, and need the zone in the same account; they fail on conflicting DNS records.
- A zone route on ANOTHER worker outranks your worker's custom domain and even a more-specific exact route on your worker: a wildcard like `*example.org/*` swallows every subdomain of the zone. Fix wildcards to the explicit hostnames the site serves; with that cleared, an exact route plus a custom domain for the same hostname is the robust pair — the route carries the traffic, the custom domain manages DNS and the certificate.
- Plain zone routes (`{ pattern, zone_name }`) need the hostname's proxied DNS record to exist, and intercept requests before the origin — useful for cutovers where the old origin must keep serving.
- Two workers cannot hold identical overlapping routes; the deploy is rejected.

## wrangler under Deno

- Run it as `deno run -A --node-modules-dir=auto npm:wrangler` — the flag materializes wrangler's own dependencies into a node_modules it can resolve. Without it (project on `nodeModulesDir: manual` or none), wrangler's bundler cannot resolve its internals (`path-to-regexp`, the unenv presets) and deploys of bundled code fail.
- `wrangler dev` caches the asset manifest — restart it after rebuilding assets, or it keeps serving the old bundle as the index fallback and the page renders blank.

## Runtime limits & debugging

- Cloudflare isolates cap subrequests (plan for around 10 on a request) and wall clock (~30 s) — write resumable jobs driven by cron triggers, not unbounded loops; background work after the response dies on serverless isolates.
- `wrangler tail --format json` is the deployment debugger. Its output is pretty-printed concatenated JSON — parse with a streaming decoder, not line-by-line.

## Email through Mailgun (shared sender)

- Environment: `MAILGUN_SENDING_KEY`, `MAILGUN_DOMAIN`, `EMAIL_FROM`, optional `MAILGUN_BASE_URL` (EU accounts: `https://api.eu.mailgun.net`).
- Send with a plain fetch — no SDK: HTTP Basic auth (`api:` + key, base64), `POST ${base}/v3/${domain}/messages`, FormData fields `from`/`to`/`subject`/`text`/optional `html`/optional `h:Reply-To`, and an abort timeout around 15 s. Throw with the status and body on failure.
- Magic-link sign-in pattern: a 15-minute HMAC-signed link token, a 7-day signed session cookie, and byte-identical responses for known and unknown addresses (no enumeration). Stateless HMAC means links are not single-use — the expiry bounds the replay window; single-use needs storage.
