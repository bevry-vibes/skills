# author

Who made an artifact, and how that is stated. One subject across three surfaces: commits, posts, and plans. commits.md's mechanics assume the rules here; conventions.md's writing style governs the prose, this file governs the attribution.

## identities

A commit has two **separate** identities: an **author / committer** (always the system git user) and a **co-author trailer** (the agent's harness + model). They are on different lines, in different roles, and follow different rules. Both identities are checked by the post-commit verification below — never commit, amend, or push without running it and reading every line.

### author + committer

**Author + committer = system git identity, always.** `git config --get user.name` / `user.email` is the only author / committer an agent commit may record. The agent's harness and model (`pi`, `grokbuild`, `minimaxcode`, …) must never appear in the author or committer fields.

If either `user.name` and `user.email` are unset or empty, prompt the user for what to configure for them globally, then apply globally. Never assume.

### co-author trailer — commits

**Co-author trailer = agent harness + model, always.** Every agent-authored commit must end with exactly one `Co-authored-by:` trailer identifying the active harness and model. The trailer is a credit line, not a stand-in for the author.

The only ever permitted way to generate this co-author trailer is via [agent-detect](https://github.com/bevry-vibes/agent-detect). If it fails for whatever reason, you must not commit without it, nor guess; your task will now be to fix its co-author trailer generation for your agent.

### assisted-by trailer — posts, plans, summaries

GitHub attributes an issue, pull request, discussion, or comment to the account that posted it — an agent-authored post otherwise reads as the user's own words. Every agent-authored post therefore closes with an **assisted-by trailer** footer:

```text
---
Assisted-by: pi - MiniMax-M3 <pi-minimaxm3@local>
```

The trailer follows the co-author's rules: the [agent-detect](https://github.com/bevry-vibes/agent-detect) `trailer assisted-by` output, generated fresh for each artifact — never guessed, cached, or copied from history. If generation fails, fix the generation first; do not post without it.

It applies to every artifact a human could otherwise read as their own words:

- issues, pull requests, discussions, and comments — on the project's repository and on any other repository the project files against (an upstream project's tracker included);
- plan introductions — see plans.md;
- session summaries at handoff — see plans.md.

## signing

**Signing is the human's act, and only the human's.** Human commits sign through the 1Password SSH agent — unlock 1Password first; the agent intermittently returns errors otherwise, and a locked agent fails the sign with "failed to write commit object" (unlock and retry).

**Agent-made commits are never signed.** Commit with `git commit --no-gpg-sign` (it overrides a global `commit.gpgsign`). The signature would be the maintainer's, made through their 1Password, asserting a human authored the change — the co-author trailer already states otherwise. And the round-trip costs a 1Password prompt on every commit for a signature that verifies nothing about the agent. An unsigned agent commit states reality; a signed one contradicts it.

## post-commit verification

After every commit, before any push, read the commit back and check all three facts:

```sh
git log -1 --format='author:    %an <%ae>%ncommitter: %cn <%ce>%ntrailers:  %(trailers)%nsignature: %G?'
```

- author and committer are the system git user — never the harness or model;
- exactly one `Co-authored-by:` trailer names the active harness + model;
- the signature state matches this file: signed only when a human made the commit; agent-made commits carry no signature.
