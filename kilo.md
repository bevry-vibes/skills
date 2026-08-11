# Kilo

Use [agent-detect](https://github.com/bevry-vibes/agent-detect) for agent identification (harness, provider, model).

## Kilo

Unless your harness is `kilo`, ignore these rules.

### Commit plan files alongside the work they drive

Unless your harness is `kilo`, ignore this rule.

When the running harness is `kilo`, commit the session's
`.kilo/plans/*.md` plan file(s) alongside the work they drive — a plan
is part of the change it plans, not scratch. Stage and commit them in
the same logical unit as the implementation, with the same co-author
trailer.
