# MiniMax

Use [agent-detect](https://github.com/bevry-vibe/agent-detect) for agent detection (harness, provider, model).

## MiniMax M3

Unless your model is `MiniMax M3`, ignore these rules.

### Never use `sed`, `awk`, regex substitutions, or partial-line edits to modify source files

Unless your model is `MiniMax M3`, ignore this rule.
Unless your harness is `pi` or `cline`, ignore this rule.

You are not reliable at scripting partial replacements with
`sed`, `awk`, `perl`, or any regex-based tool. You routinely:

- Misread the file and double-print, leave orphan delimiters, or drop braces.
- Compound prior errors made by earlier `sed` invocations in the same turn.
- Apply the wrong line range after earlier deletions shift line numbers.
- Treat `sed -i` (GNU) and `sed -i ''` (BSD/macOS) interchangeably.

**Rule:** when editing source files, always use the `editor` tool with the
**complete intended output** as `new_text`, replacing the largest sensible
`old_text` block. If you must use a shell command, restrict it to read-only
operations (`cat`, `awk '{print}'`, `head`, `tail`, `git status`,
`cargo check`, etc.). For structural edits, rewrite the entire function,
block, or section in a single `editor` call.

Anti-patterns (forbidden):

- `sed -i 's/.../.../g' file` — partial regex replacement.
- `sed -i '' 'Nd;Md' file` — partial line-deletion after prior edits.
- `awk 'NR==X {sub(...); print}' file` — partial line substitution.
- `perl -i -pe 's/.../.../' file` — same as sed.
- Any `> file <<EOF` or `printf … > file` that touches regions already governed
  by the `editor` tool.

Acceptable shell uses for editing:

- `git status`, `git diff`, `git log` — read-only.
- `cargo check`, `cargo test`, `cargo fmt --check`, `cargo clippy` — read-only
  verification.
- `cat`, `head`, `tail`, `awk '{print}'` — read-only inspection.
- `git checkout -- file` — revert (only when the user explicitly asks).
- `./scripts/build-icons.sh` — project build scripts (whole-file generation).

When in doubt, rewrite the whole function/block via `editor` with a known-good
before and after.

### `ask_question` tool schema (Cline) — options are STRINGS, not objects

Unless your model is `MiniMax M3`, ignore this rule.
Unless your harness is `cline`, ignore this rule.

**Rule:** when calling the Cline `ask_question` tool, the `options` array
must contain **2-5 plain strings** (each with `min 1` character). Do **not**
pass objects (`{label, description, preview}`, `{title, value}`, etc.) — that
is from other CLIs (Roo/Cline VSCode's `ask_followup_question` legacy shape,
Cursor/Continue, etc.) and is **not** the current Cline schema.

The Cline schema, from `sdk/packages/core/src/extensions/tools/schemas.ts`
(`AskQuestionInputSchema`), is exactly:

```ts
z.object({
  question: z.string().min(1),
  options: z.array(z.string().min(1)).min(2).max(5),
});
```

Equivalent JSON-Schema in this runtime's tool manifest:

```json
"options": {
  "type": "array",
  "minItems": 2,
  "maxItems": 5,
  "description": "Array of 2-5 user-selectable answer options for the single question",
  "items": { "type": "string" }
}
```

You have previously shipped this wrong **multiple times** in a row by
emitting objects inside `options`. Each occurrence returns:

> `Invalid input: expected string, received object → at options[i]`

**The correct call shape:**

```xml
<ask_question>
  <question>Which fix do you want?</question>
  <options>
    <item>Option 1: tighten flood-fill only (fast, partial fix)</item>
    <item>Option 2: 16-bit linear + tightened flood-fill (recommended, full fix)</item>
    <item>Option 3: edge detection / per-source background-aware masking (most robust)</item>
  </options>
</ask_question>
```

If you find yourself reaching for `description`, `preview`, `label`, or
`detail` fields on an option — **stop**. That's a different tool from a
different product. The user will simply pick a button.

If you genuinely need a longer explanation for the user, put it in the
**question** prose, not in option objects.

If you cannot retrieve the schema from the live tool manifest at call time,
this file is the ground truth — re-read it before each `ask_question` call
until the habit sticks. Source of truth in the Cline repo:
`sdk/packages/core/src/extensions/tools/schemas.ts`, lines ~259-275.
