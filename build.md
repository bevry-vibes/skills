# build

Build, packaging, and login-autostart for cross-platform menu-bar/tray desktop apps (Tauri v2 or native Rust), distilled from the bevry-vibes menu-bar apps — [aural-keyboard](https://github.com/bevry-vibes/aural-keyboard) (native Rust tray app), [command-centre](https://github.com/bevry-vibes/command-centre) (Tauri v2 + axum + React), and [sumba-bisa](https://github.com/bevry-vibes/sumba-bisa) (Deno/Vite frontend with a `deno compile` server sidecar). Read those as worked examples; this file carries the shared pattern.

## toolchain

- Frontends are Deno-first: tasks live in `deno.json` (`dev`/`build`/`check`, plus `tauri`/`tauri:build` via `deno run -A npm:@tauri-apps/cli`), and npm dependencies come through `npm:` specifiers in the imports map — no package.json scripts.
- Pin each app's Vite dev/preview ports with `strictPort: true`, so a household of Tauri/Vite apps on one machine never collide.
- Tauri build bridge: `build.beforeDevCommand` starts the frontend dev server, `build.devUrl` points at it, `build.beforeBuildCommand` runs the frontend build, `build.frontendDist` points at its output.
- Rust release profile: `strip = true`, `lto = true`, `codegen-units = 1`.

## menu-bar apps

- No Dock icon: `tauri::ActivationPolicy::Accessory` on macOS (Tauri) or `LSUIElement=true` in `Info.plist` (native). Tauri mains also carry `#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]`.
- The tray is code, not config: Tauri's `tray-icon` feature with `TrayIconBuilder` in Rust, or the `tray-icon` crate for native apps (`default-features = false, features = ["gtk"]` on Linux). Keep `app.windows` empty in `tauri.conf.json` and create windows in code.
- Tray icons must be RGBA PNGs (`png` color-type 6) for `Icon::from_rgba`. The `.app` icon set is generated once (`sips` at the required sizes + `iconutil -c icns`) and committed, so normal builds need no icon tooling.
- Linux CI: pin `ubuntu-22.04` (libappindicator is still packaged there) and install `libasound2-dev libgtk-3-dev libappindicator3-dev`.

## login-autostart

Install is an invariant: stop the running instance → place the binary/bundle at a stable path (unlink-then-copy — a running executable cannot be overwritten) → enable login → launch now. Uninstall is the exact reverse: disable login first, stop the daemon, then delete files. Provide symmetric `install`/`uninstall` and `enable`/`disable`/`status` commands, where `status` reads the same registration the other two write.

- **macOS** — install the app bundle at `~/Applications/<App>.app` (`LSUIElement`, code-signed) and write a LaunchAgent plist at `~/Library/LaunchAgents/<label>.plist` (`RunAtLoad`, `ProgramArguments` = the bundle binary + its args). Sign with a stable identity — env override, then a keychain identity, then ad-hoc `-`: the macOS TCC grant keys to the signature's cdhash, so ad-hoc rebuilds re-prompt while a stable identity keeps grants valid across reinstalls.
- **Windows** — register `HKCU\Software\Microsoft\Windows\CurrentVersion\Run` (REG_SZ, value = quoted exe path + its args), with the exe at a stable path under `%LOCALAPPDATA%\Programs\<app>\`.
- **Linux** — user-session apps get an XDG autostart desktop entry (`~/.config/autostart/<id>.desktop`, `Type=Application`, `Exec`, `X-GNOME-Autostart-enabled=true`); daemons and dedicated-user modes get a systemd unit — hardened (`NoNewPrivileges=true`, `ProtectSystem=strict`) and `systemctl enable`d.

## artifacts

Name release artifacts `<app>-<os>-<arch>` archives with a `.sha256` sidecar each; zip macOS app bundles with `ditto -c -k --keepParent` so the bundle survives intact. The release flow itself — version bump, tag, release notes — lives in [commits.md](commits.md).
