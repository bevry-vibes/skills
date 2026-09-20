# Bevry's Skills for AI Agents

When creating a new project using an agent, direct them to this repository or one of its specific skills to bootstrap your project.

If you are an agent, check if you are permitted:

- @./policy.md our AI policy, mandating which AIs are permitted

If you are initialising a new project, use these once-off to initialise it:

- @./license.md our instructions to AIs on license hygiene
- @./conventions.md our instructions on AIs to scaffold a project

Once initialised, reference these in your project's `AGENTS.md` (don't copy, just reference their remote locations and their purpose):

- @./policy.md our AI policy, mandating which AIs are permitted
- @./commits.md our instructions to AIs on commit hygiene
- @./plans.md our instructions to AIs on plan conventions
- @./build.md our instructions to AIs on building, packaging, and login-autostart for menu-bar/tray apps
- @./powershell.md our instructions to AIs on PowerShell 7.6+ work
- @./zig.md our instructions to AIs on Zig 0.16 work
- @./minimax.md our instructions for MiniMax model tweaks

## shared scripts

- @./scripts/menu.ps1 the shared arrow-key console menu (`Read-MenuChoice` / `Read-MultiChoice`) for bevry-vibes PowerShell tools — resolve it per powershell.md "shared console menu", never vendor a copy

## local tweaks pattern

When a referenced skill applies to your project **with your project's tweaks**:

1. Create a local `<name>.md` file at the repo root that:
   - references the remote skill URL (the remote file stays the single source of truth), and
   - lists the project's tweaks underneath it.
2. Your `AGENTS.md` references the **local** file, never the remote URL with inline tweaks.
3. When a skill applies **without tweaks**, `AGENTS.md` keeps the plain remote URL bullet.
4. A decision that a skill does **not** apply is a non-application decision, not a tweak — it stays an `AGENTS.md` bullet with its rationale.

This keeps the remote files authoritative and the tweaks visible separately (so they can be upstreamed). `AGENTS.md` points at the authoritative sources and may also carry this project's own sections — those are project rules, never copies of upstream skills.

The canonical `AGENTS.md` shape (repo-specific sections follow the bullets when needed; there is no footer):

```markdown
# AGENTS.md

This project conforms to Bevry's skills.
Reference their remote URLs only — do not pull their contents into this file.
When a referenced skill applies with your project's tweaks, the local `<name>.md` file at this repo root references the remote URL and lists the tweaks underneath;
this process is documented in the upstream repo's [local tweaks pattern](https://github.com/bevry-vibes/skills#local-tweaks-pattern).

- https://github.com/bevry-vibes/skills/blob/main/<skill>.md — **applies** [when …]. <description>
- [<name>.md](./<name>.md) — **applies**, with this project's tweaks (<summary>)
```

The canonical local `<name>.md` shape:

```markdown
# <name>.md

Local application of the bevry-vibes skills [<name>.md](https://github.com/bevry-vibes/skills/blob/main/<name>.md) — see the upstream [local tweaks pattern](https://github.com/bevry-vibes/skills#local-tweaks-pattern).

## this project's tweaks

<tweak bullets/sections>
```

<!-- LICENSE/ -->

## License

Unless stated otherwise all works are:

- Copyright &copy; [Benjamin Lupton](https://balupton.com)

and licensed under:

- [Reciprocal Public License 1.5](http://spdx.org/licenses/RPL-1.5.html)

<!-- /LICENSE -->
