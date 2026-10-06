# zcode

Working policy for ZCode sessions — how the main thread and its subagents divide a task. Every other skill's rules (authorship, commits, conventions) apply to the session as a whole; this file governs the division of labour.

## delegate batches to subagents

- The main thread plans, sequences, and verifies; the batches themselves (a bug fix, a feature slice, a doc pass) run in subagents, so the main context stays a purview of the whole task instead of accumulating every file read and command output.
- One batch = one subagent, with a prompt that carries everything the batch needs — background, file list, constraints, verification steps. Subagents start fresh and inherit nothing.
- Subagent prompts must be self-contained: point at the exact files, state the constraints (file lists are strict when other work is in flight), define the verification the agent must run itself, and require a report of root causes + changes + evidence.
- Resume instead of respawn where appropriate: a batch that continues an agent's own prior work (same file set, same investigation) goes back to that same agent — the context is already loaded there.

## the main thread owns the ground truth

- Subagents never commit, push, or deploy — the main thread verifies their output and owns those steps.
- Verify before hand-off, every time: in the browser or against the running server, before anything is committed, pushed, or deployed. A subagent's own report is a claim, not evidence.
- Verify visual changes visually — a styling or layout change is verified with a screenshot of the rendered page, not by reading the CSS or the HTML. Check the element in its rendered state (hover, crop, overlay) before calling the change done.
- Verify shared changes everywhere they are used — a change to a shared component, style, or module is checked in every consumer of it, the same class or helper in its other contexts, because it can fix one surface and break another.
