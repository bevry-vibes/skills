# conventions

If these files do not exist locally, pull them into your project:

- <https://raw.githubusercontent.com/bevry/base/refs/heads/master/.editorconfig>
- <https://raw.githubusercontent.com/bevry/base/refs/heads/master/.gitattributes>
- <https://raw.githubusercontent.com/bevry/base/refs/heads/master/.gitignore>

Insert any project-specific overrides under the custom segment:

```
# =====================================
# CUSTOM
```

## wrapping

Never hard-wrap prose to a fixed column — no manual line breaks inserted to fit a width, and no editor hard word-wrap or "fill paragraph" applied on save. A line is as long as its content needs; the viewer's soft-wrap setting lays out whatever runs long.

Breaking a line for legibility is always fine — a new line within a paragraph, at a clause or sentence boundary, is ordinary prose formatting, and authors should break where it helps the reader. The rule only forbids width-driven wrapping: breaks chosen because a column counter said so, not because the content said so.

The rationale is the same as tabs over spaces — different agents author at different column policies, so any fixed width is churn: a re-wrapped paragraph touches every line of its diff. Break lines for meaning, never for measurement, and the content adapts to the user's viewer preferences, never the other way around. Structured formats keep their meaningful line breaks: code blocks, tables, diffs, and source files stay exactly as their syntax dictates.

## splat naming

Never refer to a to-be-defined name with `X`, `Xxx`, or `XXX`.
Use an asterisk splat (`build*Env`) or the interpolated form matching the language's conventions — `build<Harness>Env` (camelCase), `build<HARNESS>_ENV` (UPPER_SNAKE), `build{Harness}Env` / `build${HARNESS}Env` as the syntax dictates.
Always a real, greppable pattern — never `X`.