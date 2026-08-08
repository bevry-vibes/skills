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
