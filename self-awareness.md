# self-awareness

> How an agent infers — never assumes — its own harness, model, and interface, fresh at each session start and after every in-session model change. Required by @./policy.md (identify harness, model, and provider before working) and @./commits.md (fresh co-author identity per session and per model change).

## outputs

Detection must produce, with evidence for each:

- **harness** — the agent runner, e.g. `Cline`
- **interface** — the provider product the harness is configured with, e.g. `Cline Pass`
- **model** — the model id and its display name, e.g. `cline-pass/kimi-k3` → `Kimi K3`
- **co-author trailer** — per @./commits.md - e.g. `Co-authored-by: Cline - Kimi K3 <cline-kimik3@local>`

If any output cannot be inferred with evidence, stop and inform the user. Never guess.

## cline (cli harness)

### detection ladder — least invasive first

Run these in order; stop once every output has evidence.

#### 1. environment variables (zero i/o)

| var(s)                                                                                     | what they evidence                                                     |
| ------------------------------------------------------------------------------------------ | ---------------------------------------------------------------------- |
| `CLINE_WRAPPER_PATH`, `CLINE_BUILD_ENV`, `CLINE_NO_INTERACTIVE`, `CLINE_RUN_AS_HUB_DAEMON` | harness = Cline CLI (`CLINE_WRAPPER_PATH` also gives the install path) |
| `CLINE_CONNECTOR_CLI_LAUNCH`                                                               | harness + launcher binary path (`cline.exe`) + connector cwd           |
| `NODE_EXTRA_CA_CERTS` → `...\.cline\cli-node-extra-ca-certs.pem`                           | corroborates Cline CLI and reveals the `.cline` data root              |
| `OPENTUI_GRAPHICS`                                                                         | corroborates Cline's terminal UI (OpenTUI)                             |
| `USERPROFILE` (win) / `HOME` (unix)                                                        | base for locating `~/.cline/data`                                      |

Verified by full env dump (win32, 2026-08): **no env var exposes the model, provider/interface, or session id** — env alone identifies only the harness and the data root. Re-check with a full `Get-ChildItem env:` dump, as future Cline versions may add such vars.

A `cline` process in your shell's ancestry (walk `ParentProcessId` from the shell's pid) further confirms the harness. The data root is `%USERPROFILE%\.cline\data\` on Windows, `~/.cline/data/` elsewhere.

Cline is open source (Apache-2.0), so the @./policy.md harness check passes.

### data sources (ladder steps 2–4)

| step | source           | path                                             | key fields                                                                      | role                                                                                                                                |
| ---- | ---------------- | ------------------------------------------------ | ------------------------------------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------- |
| 2    | live selection   | `~/.cline/data/settings/providers.json`          | `lastUsedProvider`, `providers.<id>.settings.model`, `providers.<id>.updatedAt` | interface + model selected right now; re-written on every provider/model switch — one small file read, no session resolution needed |
| 3    | own session      | `~/.cline/data/sessions/<id>/<id>.json`          | `pid`, `provider`, `model`, `cwd`, `status`, `messages_path`                    | session snapshot + self-identification                                                                                              |
| 4    | generation truth | `~/.cline/data/sessions/<id>/<id>.messages.json` | last assistant message's `modelInfo.id` / `modelInfo.provider`                  | what actually generated the latest reply                                                                                            |

Step 2 alone yields interface + model; steps 3–4 corroborate and attribute mid-session switches.

⚠ `providers.json` contains live auth tokens. Read only the fields you need; never copy tokens into output, docs, logs, or commits.

### resolving your own session (ladder step 3)

Parallel sessions exist, so do not blindly pick the newest session globally.

1. Walk your process ancestry, nearest first (PowerShell: loop `Get-CimInstance Win32_Process -Filter "ProcessId=$c"` from `$PID`, following `ParentProcessId`).
2. Load every `sessions/*/<id>.json`; select the first session whose `pid` appears in your ancestry and whose `status` is `running`. Corroborate with `cwd` equal to your working directory.
3. Fallback only: newest `running` session with matching `cwd`. If still ambiguous, stop and inform the user (per @./commits.md).

### reference procedure (ladder-ordered; tested on win32 + PowerShell 7.6)

```powershell
#Requires -Version 7.6
$ErrorActionPreference = 'SilentlyContinue'

# 1. harness: CLINE_* env vars (ladder step 1)
$envOk = [bool](Get-ChildItem env: | Where-Object Name -like 'CLINE_*')

# 2. live selection: providers.json (ladder step 2)
$prov  = Get-Content "$env:USERPROFILE\.cline\data\settings\providers.json" -Raw | ConvertFrom-Json
$iface = $prov.lastUsedProvider
$entry = $prov.providers.PSObject.Properties[$iface].Value

# 3. own session via ancestry, nearest first (ladder step 3)
$pids = $(
  $c = $PID
  while ($c) {
    $p = Get-CimInstance Win32_Process -Filter "ProcessId=$c"
    if (-not $p) { break }
    $p.ProcessId
    $c = $p.ParentProcessId
  }
)
$root = "$env:USERPROFILE\.cline\data\sessions"
$sessions = Get-ChildItem $root -Directory | ForEach-Object {
  $j = Join-Path $_.FullName ($_.Name + '.json')
  if (Test-Path $j) { Get-Content $j -Raw | ConvertFrom-Json }
}
$mine = $null
foreach ($ap in $pids) {
  $hit = @($sessions.Where{ $_.pid -eq $ap -and $_.status -eq 'running' })
  if ($hit.Count) { $mine = $hit[0]; break }
}
$mine ??= @($sessions.Where{
  $_.status -eq 'running' -and $_.cwd -eq (Get-Location).Path
} | Sort-Object started_at -Descending)[0]
if (-not $mine) { throw 'cannot identify own cline session; stop and inform the user' }

# 4. generation truth: last assistant modelInfo (ladder step 4)
$raw = Get-Content $mine.messages_path -Raw
$mm  = [regex]::Matches($raw, '"modelInfo":\s*\{\s*"id":\s*"([^"]+)",\s*"provider":\s*"([^"]+)"')
$gen = $mm.Count ? $mm[$mm.Count - 1] : $null
# pre-compute: never chain [index] after ?. — see gotcha below
$lastModel = $null; $lastProvider = $null
if ($gen) { $lastModel = $gen.Groups[1].Value; $lastProvider = $gen.Groups[2].Value }

[pscustomobject]@{
  HarnessEnvVars  = $envOk
  LiveProvider    = $iface
  LiveModel       = $entry.settings.model
  LiveUpdatedAt   = $entry.updatedAt
  SessionId       = $mine.session_id
  SessionProvider = $mine.provider
  SessionModel    = $mine.model
  LastMsgProvider = $lastProvider
  LastMsgModel    = $lastModel
}
```

PowerShell 7.6 syntax used: null-coalescing assignment (`??=`), ternary (`? :`), and `.Where{}`. Gotcha: never chain `[index]` after the null-conditional operator — `$x?.Member[i]` errors `Cannot index into a null array` even when `$x` is non-null, and `$ErrorActionPreference = 'SilentlyContinue'` hides it (the assignment silently never happens). Pre-compute indexed values with `if` instead. Harness shells may be Windows PowerShell 5.1, so save to a file and run via `pwsh -NoProfile -File`; the `#Requires` guard fails fast on older hosts.

### normalisation

- Model id format is `<provider>/<slug>`, e.g. `cline-pass/kimi-k3`.
- Interface display names: `cline-pass` → `Cline Pass`; `cline` → `Cline`.
- Slug → model display name (extend as encountered): `kimi-k3` → `Kimi K3`; `glm-5.2` → `GLM 5.2`; `minimax-m3` → `MiniMax-M3`; `qwen3.8-max` → `Qwen3.8-Max` (closed-weight as of 2026-08 — prohibited per @./policy.md until its scheduled open-weight release lands).
- Trailer email local part: lowercase-alphanumeric harness + model, e.g. `cline-kimik3@local`.

### freshness rules

- Infer at session start, before every commit, and immediately after any user model/provider switch (e.g. `/model`). Escalate only as far up the ladder as needed: env → providers.json → session json → messages.json.
- On a mid-session switch (verified 2026-08 with `kimi-k3` ↔ `qwen3.8-max`): `providers.json` updates (`updatedAt` bumps), the session json's `provider`/`model` follow, and the next assistant message's `modelInfo` carries the new id — all three updated live within the session. If they ever disagree, note the discrepancy, treat the newest evidence as current, and tell the user what you observed.
- Never re-use an identity from a prior session (per @./commits.md).
