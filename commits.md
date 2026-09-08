# commits

## how to commit

Each commit must contain one logical change and only work produced in this conversation.

## commit message format

All commits MUST follow the Conventional Commits 1.0.0 specification:

- Format: `<type>(<scope>): <short summary in present tense>`
- Types: `feat`, `fix`, `docs`, `style`, `refactor`, `perf`, `test`, `chore`.
- Breaking Changes: Append `!` to the type or include `BREAKING CHANGE:` in the body.
- Atomicity: One logical change per commit. Do not mix concerns.
- Example: `feat(api): add endpoint for user profile retrieval`

**Title** — Target ≤ 50 characters, hard cap at 72 (the limit `git log --oneline`, `git shortlog`, GitHub's PR list, and most changelog generators assume).

**Body** — A brief meaning/purpose summary of each distinct change in the commit, in the order the diff presents them — one or two lines per change.

**Shell-safe paragraphs** — Each `git commit -m` argument creates one paragraph. Do **not** put `\n` or `\n\n` inside an ordinary quoted `-m` argument: common shells pass those characters literally instead of turning them into line breaks. Use another `-m` for each paragraph, or write a complete message under `.temp/` and pass it with `git commit --file`. For example:

```text
git commit -m "docs(scope): summarize change" -m "Explain the purpose." -m "Co-authored-by: pi - MiniMax-M3 <pi-minimaxm3@local>"
```

## commit identities and verification

A commit has two **separate** identities: an **author / committer** (always the system git user) and a **co-author trailer** (the agent's harness + model). They are on different lines, in different roles, and follow different rules. The two identities are checked together by the **mandatory post-commit verification** below — never commit, amend, or push without running it and reading every line.

### author + committer

**Author + committer = system git identity, always.** `git config --get user.name` / `user.email` is the only author / committer an agent commit may record. The agent's harness and model (`pi`, `grokbuild`, `minimaxcode`, …) must never appear in the author or committer fields.

If either `user.name` and `user.email` are unset or empty, prompt the user for what to configure for them globally, then apply globally. Never assume.

### co-author trailer

**Co-author trailer = agent harness + model, always.** Every agent-authored commit must end with exactly one `Co-authored-by:` trailer identifying the active harness and model. The trailer is a credit line, not a stand-in for the author.

The only ever permitted way to generate this co-author trailer is via [agent-detect](https://github.com/bevry-vibes/agent-detect). If it fails for whatever reason, you must not commit without it, nor guess; your task will now be to fix its co-author trailer generation for your agent.

### signing

Commits and pushes sign through the 1Password SSH agent — unlock 1Password first; the agent intermittently returns errors otherwise.

## github issues, pull requests, and comments

GitHub attributes an issue, pull request, or comment to the account that posted it — an agent-authored post otherwise reads as the user's own words. Every agent-authored issue body, pull request body, or comment must therefore close with an **assisted-by trailer** footer:

```text
---
Assisted-by: pi - MiniMax-M3 <pi-minimaxm3@local>
```

The footer line is the [agent-detect](https://github.com/bevry-vibes/agent-detect) `trailer assisted-by` output, generated fresh for each post the same way the commit co-author trailer is — never guessed or cached. If generation fails, do not post without it; fix the generation first.

## releases

A tagged release carries a full changelog, not just the workflow's stub:

1. **Version bump** — `chore: release <version> — <headline>`; bump the version in the project's manifest (`Cargo.toml`, `package.json`, `deno.json`, …) and refresh its lockfile.
2. **Tag** — annotated `<version>`; the tag message is a one-paragraph summary. The release title is `<version> — <headline>` — never repeat the product name; the tag and repo already carry it.
3. **Push** — `main` + the tag; the release workflow builds and attaches the artifacts. Package registries are immutable (crates.io, npm, …): never re-cut a pushed version — cut a patch bump instead. Registry-publish steps run **before** packaging steps — packaging dirties the tree, and a dirty tree fails the publish.
4. **Stub first** — the release workflow publishes the pushed tag with a fixed one-line body (the stable-release pointer and its download note). Exactly one workflow job may create the release or set `generate_release_notes`: every job that does appends its own generated block to the body (duplicated "Full Changelog" footers).
5. **Full notes** — once that run completes (`gh run watch <run-id> --exit-status`), replace the body with the full changelog: `gh release edit <version> --notes-file .release-notes-<version>.md`.
6. **Drafting** — draft the notes in `.release-notes-<version>.md` at the repo root, sourced from `git log --oneline <prev-tag>..HEAD` plus the commit bodies — verify every claim against a commit message, never invent.
7. **Structure** — lead with the workflow's stable-release line unchanged; no H1 (the release title already renders as the header); only this release's changes, never prior releases'; then a `## What's changed since <prev-tag>` heading with themed `###` sections (new features, platform support, breaking changes, tooling — whatever the release actually contains); close with exactly one **Full Changelog** compare link: `https://github.com/<owner>/<repo>/compare/<prev-tag>...<version>`.
8. The notes file is an artifact — delete it after uploading; never commit it.
9. **Verification** — the workflow runs complete (`gh run watch` / `gh run list`), then `gh release view <version>`: title and body updated, not a draft or prerelease, assets present.
