# powershell

All PowerShell work runs on PowerShell 7.6 or later.

## version and syntax

- Every PowerShell script starts with `#Requires -Version 7.6`.
- Use modern syntax where appropriate — pipeline chain operators (`&&` / `||`), ternary / null-coalescing expressions (`?:` / `??` / `??=`), switch expressions, `ForEach-Object -Parallel`, typed class definitions, native-command `2>&1` stderr capture — instead of legacy forms.

## Line endings: never round-trip through Set-Content

A `* -text` `.gitattributes` means git will **not** normalize line endings for you, and the checked-out files are LF — and `Set-Content` has two traps on top of that:

1. `Set-Content -Value <array> -NoNewline` writes every array element **back-to-back with no separator** — the file comes back as one giant line, not an array of lines.
2. `Set-Content` without `-NoNewline` separates array elements with the platform newline (**CRLF on Windows**) and rewrites the whole file — silently converting an LF file to CRLF. A CRLF-converted file shows up as a full-file diff in git.

For any bulk file rewrite (splices, large replacements, line-ending normalization) build the final content as a single string with explicit `` "`n" `` joins and write it as raw bytes:

```powershell
$lines = Get-Content file.ext
$newblock = Get-Content newblock.ext
$content = ($lines[0..4684] -join "`n") + "`n" + $newblock + "`n" +
           ($lines[5000..($lines.Count - 1)] -join "`n")
[System.IO.File]::WriteAllText(
    (Resolve-Path file.ext),
    $content,
    [System.Text.UTF8Encoding]::new($false)   # LF, no BOM
)
```

After any rewrite, verify with `git diff --stat` that the diff stayed small (a full-file diff means a line-ending conversion slipped through) and confirm the file is LF (see the byte check below).

## Targeted edits: Get-Content -Raw + .Replace + byte write

`Get-Content -Raw` yields a single string; a plain `.Replace(old, new)` on it followed by the byte-level write above is the safe way to do targeted edits without disturbing every other line. `.Replace` is **literal** — `-replace` and `[regex]::Replace` are regex, so only use them for small deterministic patterns, and `[regex]::Escape` the needle when in doubt.

## Regex on huge files: use IndexOf slicing, not regex Replace

`[regex]::Replace` over a ~390 KB single string with a non-greedy `.*?` pattern throws `RegexMatchTimeoutException` (the engine's default 15-second budget is exhausted by catastrophic backtracking). Don't tune timeouts — avoid regex for large-block surgery entirely. Anchor with `String.IndexOf` and slice:

```powershell
function Slice($content, $startAnchor, $endAnchor, $replacement, $what) {
    $s = $content.IndexOf($startAnchor)
    if ($s -lt 0) { throw "start anchor `"$what`" not found" }
    $e = $content.IndexOf($endAnchor, $s + $startAnchor.Length)
    if ($e -lt 0) { throw "end anchor `"$what`" not found" }
    return $content.Substring(0, $s) + $replacement + $content.Substring($e)
}
```

## Stale line numbers are a trap when scripting splices

A line-number-based splice (`$lines[0..N] + $block + $lines[M..]`) is only valid for the file state it was computed against. Any prior edit that shifts lines invalidates the numbers silently — the splice lands in the middle of a function and the file is corrupted. Always anchor on **content** (unique surrounding text), not line numbers, and re-verify the boundary lines after each splice.

## Line-ending byte check

To count LF vs CRLF without regex backtick hell:

```powershell
$b = [System.IO.File]::ReadAllBytes((Resolve-Path file.ext))
$lf = 0; $crlf = 0
for ($i = 0; $i -lt $b.Length; $i++) {
    if ($b[$i] -eq 10) {
        if ($i -gt 0 -and $b[$i - 1] -eq 13) { $crlf++ } else { $lf++ }
    }
}
"lf=$lf crlf=$crlf"
```

## sqlite3 CLI patterns

- `sqlite3 -json -batch db "<sql>"` — every result row comes back as a JSON array line; a scalar statement still emits a row, e.g. a `PRAGMA busy_timeout = N;` setter prints `[{"timeout":N}]` (harmless if discarded).
- `SELECT changes() AS c` after a DELETE → `[{"c":N}]`. The count is **connection-local**, so run the DELETE and `SELECT changes()` in ONE `sqlite3` invocation.
- Schema/state spot-checks: `sqlite3 db ".tables"` and `"PRAGMA table_info(<table>)"`.
- **Fresh-store gotcha:** a command that only runs DML fails with "no such table" against a freshly-deleted DB unless the schema is ensured first — run a schema-ensuring command first when recreating the store.

## shared console menu

Interactive console menus (single-choice and multi-choice) use the shared handler in [scripts/menu.ps1](./scripts/menu.ps1) — never a local copy. `Read-MenuChoice` returns the index of the chosen row (-1 for Esc, -2 for Ctrl+C). `Read-MultiChoice` returns one array over the selection — an empty array for "confirmed nothing", `$null` when cancelled or aborted. Options without an `Actions` field behave as checkboxes (`[x]`/`[ ]`, space toggles the row, the ticked rows return the option objects). Options with an `Actions` array render a hybrid radio line beneath the label and detail — `○` unchecked, `●` checked, at most one action set per row, none required: space sets the focused action and clears its siblings, space again unsets it, left/right (or h/l) move between the row's actions — and each set row returns an `@{ Index; Option; Action }` wrapper. An optional `ActionColors` hashtable (action name → ANSI escape, e.g. `$PSStyle.Foreground.Blue`) colors each action text and its checked glyph. Unavailable rows (`Unavailable = $true`, legacy `Locked`) render dim with an `[unavailable]` prefix and group at the end of the list. Resolve the file through a sibling checkout first, then a cache, then a download:

```powershell
$menu = $null
foreach ($candidate in @(
    $env:BEVRY_SKILLS_MENU,
    (Join-Path $PSScriptRoot '../skills/scripts/menu.ps1'),
    (Join-Path $PSScriptRoot '../../skills/scripts/menu.ps1')
)) {
    if ($candidate -and (Test-Path $candidate)) { $menu = $candidate; break }
}
if (-not $menu) {
    $cacheDir = $IsWindows ? (Join-Path $env:LOCALAPPDATA 'bevry-vibes/skills/scripts') : (Join-Path $HOME '.cache/bevry-vibes/skills/scripts')
    $cached = Join-Path $cacheDir 'menu.ps1'
    if (-not (Test-Path $cached)) {
        New-Item -ItemType Directory -Force -Path $cacheDir | Out-Null
        Invoke-WebRequest 'https://raw.githubusercontent.com/bevry-vibes/skills/main/scripts/menu.ps1' -OutFile $cached
    }
    $menu = $cached
}
. $menu
if (-not (Get-Command Read-MenuChoice -ErrorAction Ignore)) { throw "the shared menu loaded from $menu, but Read-MenuChoice did not arrive" }
```

Adjust the two sibling paths for the depth of your script. A tool that must also run without the network keeps its own fallback prompt for the case where the download fails and no copy exists.

When a function or scriptblock returns an array a caller reads as an array (`.Count`, indexing), end the return with the comma guard (`return , @(...)`) — pipeline unrolling collapses a single-element return to a scalar and an empty one to `$null`, and a scalar string still indexes (`'install'[0]` is `'i'`), so the bugs are quiet.
