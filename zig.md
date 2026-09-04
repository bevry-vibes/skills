# zig

Zig 0.16 working notes. Everything here is verified against the stdlib shipped with `zig 0.16.0`.

- `zig env` → dumps the environment; `std_dir` gives the stdlib path to grep for APIs (e.g. `Get-Content ...\lib\std\Io\Dir.zig | findstr /n "fn rename"`).

## APIs that differ from older Zig — verified in 0.16

- **No `std.fmt.fmtSliceHexLower`.** Use `std.fmt.bytesToHex(bytes, .lower)` (returns `[len*2]u8`; `.upper` also exists).
- **No `std.fs.path.absolute`.** `std.fs.path.resolve` and friends exist; for a replace-existing rename use `std.Io.Dir.rename` with relative sub-paths (no absolute paths needed):
  ```zig
  std.Io.Dir.rename(std.Io.Dir.cwd(), tmp_sub, std.Io.Dir.cwd(), final_sub, io) catch return error.FilesystemIoError;
  ```
  `Dir.renameAbsolute` requires absolute paths on both sides. The docs guarantee rename **replaces an existing target** — that's the atomic temp-write + rename pattern.
- **`std.Io.Dir.cwd().readFileAlloc(io, sub, a, @enumFromInt(1 << 24))`** — the max-bytes argument is an `enum` in 0.16 (`@enumFromInt(...)`), not an integer.
- **`std.process.executablePath(io, &buf)`** — takes a `std.fs.max_path_bytes` buffer and returns the length (0 on failure), not the slice.
- **`std.process.spawn(io, .{ .argv = ..., .environ_map = ..., .stdout = .pipe, .stderr = .pipe })`** — child's stdout/stderr are `?Io.File`; wire a reader with `file.reader(io, &buf)`. Spawn's argv wants a slice of `[]const u8`, not a sentinel-terminated pointer.
- **`std.Io.sleep(io, .{ .nanoseconds = ... }, .boot)`** — sleep takes a clock (use `.boot` for elapsed-time semantics).
- **Timestamps:** `std.Io.Clock.Timestamp.now(io, .boot)` / `.real`; `ts.raw.nanoseconds` (i96) or `ts.raw.toSeconds()`. `Timestamp.fromNow(io, .{ .raw = .{ .nanoseconds = ... }, .clock = .boot })` builds future deadlines. `std.time.ns_per_s` is the handy scalar.
- **`std.crypto.hash.Blake3.hash(bytes, &digest, .{})`** — `digest` is `[32]u8`; no packages needed.
- **`std.json.Stringify.valueAlloc(a, value, .{ .whitespace = .indent_2 })`** — deterministic pretty serialization. std.json **preserves object key insertion order** on parse, so re-serializing a parsed object reproduces canonical bytes — which keeps committed-store diffs stable across writers.
- **Doc comments (`///`) must immediately precede a declaration.** A stray `///` where a statement is expected ("expected statement, found 'a document comment'") usually means the comment got orphaned after a splice/insert.
- **`inline for` cannot contain runtime `continue`.** "comptime control flow inside runtime block" — if you need `orelse continue` inside an `inline for`, switch to a plain `for`.
- **`Dir.iterate()` iterates that dir's immediate children only.** To walk a subdirectory you must open it first — `std.Io.Dir.cwd().openDir(io, "subdir", .{ .iterate = true })` and iterate *that*; `cwd().iterate()` will never yield `subdir/*` entries.
- **`std.Io.File.lock` / `tryLock`** — `file.lock(io, .exclusive)` / `file.tryLock(io, .exclusive)` (returns `bool`; `LockError`). Kernel-managed: the lock releases when the process exits/crashes — no stale-lock heuristics. For mutable shared state, lock a separate lock file (never the data file), retry `tryLock` on a bounded budget, then mutate and write atomically (serialize → `data.tmp` → `rename` over the data file — rename replaces an existing target). Readers take no lock: temp+rename makes visibility atomic.

## Gotchas

- **`readFileAlloc` returns empty for `/proc` pseudo-files on Linux.** `/proc/<pid>/comm` / `stat` report `st_size = 0`, and `Dir.readFileAlloc`'s bare reader trusts the size hint — immediate EOF, zero bytes (silently). Open the file and read through an explicitly-buffered reader instead (`file.reader(io, &buf)` then `readSliceShort`).
- **Never free an arena slice that a returned value aliases.** The arena free-list only recycles the most-recent allocation; freeing a slice that a returned `std.json.Value` (or a `?[]const u8` view into the parsed tree) aliases lets the caller's next allocations reclaim and clobber the bytes mid-use. Callers must not free the parsed buffer while derived values live.
- **Mutate `std.json` maps through pointers, not copies.** `ObjectMap` stores its internal header pointer by value — `map.get(key)` returns a *copy*. Mutating that copy (e.g. `swapRemove`) updates the copy's pointer field while the stored map still points at the freed header (dangling read on the next `get`). Use `getPtr(key)` for mutations.
- **Keep test asserts structural (expect/print), not timing-based.** Release-mode test builds will bite tests that only pass in Debug modes.
