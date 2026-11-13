# build

Build, packaging, and login-autostart for cross-platform menu-bar/tray desktop apps (Tauri v2 or native Rust), distilled from the bevry-vibes menu-bar apps — [aural-keyboard](https://github.com/bevry-vibes/aural-keyboard) (native Rust tray app), [command-centre](https://github.com/bevry-vibes/command-centre) (Tauri v2 + axum + React), and [sumba-bisa](https://github.com/bevry-vibes/sumba-bisa) (Deno/Vite frontend with a `deno compile` server sidecar). Read those as worked examples; this file carries the shared pattern.

## toolchain

- Frontends are Deno-first: tasks live in `deno.json` (`dev`/`build`/`check`, plus `tauri`/`tauri:build` via `deno run -A npm:@tauri-apps/cli`), and npm dependencies come through `npm:` specifiers in the imports map — no package.json scripts.
- Deno sites built with Vite: keep the Vite major in the `deno.json` imports map. A root `package.json` anchor is not needed on Deno 2.9+ with Vite 8. Add one only if a plugin peer floats to a Vite that needs a Node builtin Deno lacks.
- Pin each app's Vite dev/preview ports with `strictPort: true`, so a household of Tauri/Vite apps on one machine never collide.
- Tauri build bridge: `build.beforeDevCommand` starts the frontend dev server, `build.devUrl` points at it, `build.beforeBuildCommand` runs the frontend build, `build.frontendDist` points at its output.
- Rust release profile: `strip = true`, `lto = true`, `codegen-units = 1`.
- Rust repos that follow the tab convention: add `rustfmt.toml` with `hard_tabs = true`, so `cargo fmt --check` passes without converting the codebase to spaces.

## ci

- Pin the Rust toolchain in `rust-toolchain.toml` (`channel = "1.100.0"`, `components = ["clippy", "rustfmt"]`) and use the same version in CI (`dtolnay/rust-toolchain@1.100.0`). A rustfmt update can otherwise fail `cargo fmt --check` on an unchanged tree.
- Keep each GitHub action on its current major, and read the run annotations. A major that targets a deprecated Node runtime still runs, but GitHub forces a newer Node and warns. At the 2026-11 pass, `actions/checkout@v7`, `actions/upload-artifact@v7`, `actions/cache@v6`, and `softprops/action-gh-release@v3` were current. `Swatinem/rust-cache@v2`, `denoland/setup-deno@v2`, and `step-security/setup-zig@v2` were current.

## menu-bar apps

- No Dock icon: `tauri::ActivationPolicy::Accessory` on macOS (Tauri) or `LSUIElement=true` in `Info.plist` (native). Tauri mains also carry `#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]`.
- The tray is code, not config: Tauri's `tray-icon` feature with `TrayIconBuilder` in Rust, or the `tray-icon` crate for native apps (`default-features = false, features = ["gtk"]` on Linux). Keep `app.windows` empty in `tauri.conf.json` and create windows in code.
- Tray icons must be RGBA PNGs (`png` color-type 6) for `Icon::from_rgba`. The `.app` icon set is generated once (`sips` at the required sizes + `iconutil -c icns`) and committed, so normal builds need no icon tooling.
- Tauri: list `icons/icon.icns` and `icons/icon.ico` in `bundle.icon`. A PNG-only list fails the macOS bundle with `Failed to create app icon: No matching IconType`.
- Tauri merges `src-tauri/Info.plist` into the bundle. Use it for `LSUIElement`, so a launchd start stays a menu-bar agent, and for the Files and Folders purpose strings (`NSDesktopFolderUsageDescription`, `NSDocumentsFolderUsageDescription`, `NSDownloadsFolderUsageDescription`, `NSRemovableVolumesUsageDescription`, `NSNetworkVolumesUsageDescription`).
- Embed the tray template with `include_bytes!` and set `icon_as_template(true)` on macOS. A 44px alpha-only PNG fills the status bar and adapts to light and dark. Do not depend on `default_window_icon()` resolving.
- Linux CI: pin `ubuntu-22.04` (libappindicator is still packaged there) and install `libasound2-dev libgtk-3-dev libappindicator3-dev`.

## login-autostart

Install is an invariant: stop the running instance → place the binary/bundle at a stable path (unlink-then-copy — a running executable cannot be overwritten) → enable login → launch now. Uninstall is the exact reverse: disable login first, stop the daemon, then delete files. Provide symmetric `install`/`uninstall` and `enable`/`disable`/`status` commands, where `status` reads the same registration the other two write.

- **macOS** — install the app bundle at `~/Applications/<App>.app` (`LSUIElement`, code-signed) and write a LaunchAgent plist at `~/Library/LaunchAgents/<label>.plist` (`RunAtLoad`, `ProgramArguments` = the bundle binary + its args). Sign with a stable identity — env override, then a keychain identity, then ad-hoc `-`. The macOS TCC grant keys to the code requirement: an ad-hoc signature has only a cdhash, so every rebuild re-prompts, while a certificate gives `identifier + certificate root` and survives rebuilds.
- **Windows** — register `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` (REG_SZ, value = quoted exe path + its args), with the exe at a stable path under `%LOCALAPPDATA%\Programs\<app>\`.
- **Linux** — user-session apps get an XDG autostart desktop entry (`~/.config/autostart/<id>.desktop`, `Type=Application`, `Exec`, `X-GNOME-Autostart-enabled=true`); daemons and dedicated-user modes get a systemd unit — hardened (`NoNewPrivileges=true`, `ProtectSystem=strict`) and `systemctl enable`d.

## tcc

A macOS grant keys to a code requirement, not to an app name.

- An ad-hoc signature has only a cdhash. The requirement changes on every build, so the user must grant the permission again. A certificate-signed app carries `identifier "<bundle-id>" and certificate root = H"…"`, which survives rebuilds. Sign with a stable identity (see login-autostart).
- A stale row can stay in the Full Disk Access list. Enabling it grants the old signature. TCC then logs `Failed to match existing code requirement` with the stored and current requirements. Reset with `tccutil reset <service> <bundle-id>` (`SystemPolicyAllFiles` for Full Disk Access, `ListenEvent` for Input Monitoring), then add the current app again.
- Diagnose with `log show --predicate 'subsystem == "com.apple.TCC"'`. The log prints both requirements on a mismatch.
- Use the preflight API when one exists: `CGPreflightListenEventAccess` for Input Monitoring, and the Accessibility and Screen Recording equivalents.
- Full Disk Access has no preflight API and no request API. Detect it by opening a protected path and reading nothing. macOS 27 moved the user TCC database into a protected container that is unreadable even with Full Disk Access. `/Library/Preferences/com.apple.TimeMachine.plist` is a working probe; the user Time Machine plist and Safari `History.db` are fallbacks.
- Files and Folders has five categories: Desktop, Documents, Downloads, removable volumes, and network volumes. macOS prompts on first access. The reason comes from the Info.plist purpose strings. There is no per-path grant. A Safari container path needs Full Disk Access.
- PTY sessions inherit the app's TCC identity. Grant the permission to the app bundle, not to the terminal that launched it. TCC caches the decision per process, so relaunch after a grant.

## artifacts

Name release artifacts `<app>-<os>-<arch>` archives with a `.sha256` sidecar each; zip macOS app bundles with `ditto -c -k --keepParent` so the bundle survives intact. The release flow itself — version bump, tag, release notes — lives in [commits.md](commits.md).
