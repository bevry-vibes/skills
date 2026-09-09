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

## writing style

Write all content and all response prose in [ASD-STE100](https://en.wikipedia.org/wiki/Simplified_Technical_English) (Simplified Technical English) style. Content is every document, comment, description, and commit message you author. Response prose is every sentence you write in conversation. Code, code blocks, identifiers, commands, and syntax-directed formats are not prose; keep them as their syntax dictates.

- Use each word with its most common meaning and as one part of speech. When two words share a meaning, choose one and use it everywhere.
- Prefer common words. Use a technical name or technical verb only when the domain requires it. Define it at first use, then reuse it exactly.
- Use International English spelling (IELTS): colour, organisation, analyse. Keep one spelling per word, everywhere.
- Keep sentences short: 20 words or fewer for instructions, 25 words or fewer for descriptions. Write one instruction per sentence.
- Write instructions in the imperative. Write "Run the tests." Do not write "The tests should be run."
- Use active voice and simple tenses: present, past, future, imperative. Do not use contractions. Do not use an -ing form as a noun or a modifier.
- Keep noun clusters to three nouns or fewer. Rewrite a longer cluster with a preposition: "the config for the release workflow", not "the release workflow config format".
- Use the articles a, an, and the. Do not drop them.
- Put a condition before its instruction: "If the build fails, read the log."
- Do not use slang, idioms, metaphors, humour, or culture-specific references.
- Keep paragraphs to one topic and six sentences or fewer.

The rationale mirrors tabs over spaces: readers are distributed, and some are machines. A controlled language gives every reader the same parse of the same text, so the meaning does not depend on the reader's locale or context. These rules trade expressiveness for that guarantee.

## wrapping

Never hard-wrap prose to a fixed column — no manual line breaks inserted to fit a width, and no editor hard word-wrap or "fill paragraph" applied on save. A line is as long as its content needs; the viewer's soft-wrap setting lays out whatever runs long.

Breaking a line for legibility is always fine — a new line within a paragraph, at a clause or sentence boundary, is ordinary prose formatting, and authors should break where it helps the reader. The rule only forbids width-driven wrapping: breaks chosen because a column counter said so, not because the content said so.

The rationale is the same as tabs over spaces — different agents author at different column policies, so any fixed width is churn: a re-wrapped paragraph touches every line of its diff. Break lines for meaning, never for measurement, and the content adapts to the user's viewer preferences, never the other way around. Structured formats keep their meaningful line breaks: code blocks, tables, diffs, and source files stay exactly as their syntax dictates.

## splat naming

Never refer to a to-be-defined name with `X`, `Xxx`, or `XXX`.
Use an asterisk splat (`build*Env`) or the interpolated form matching the language's conventions — `build<Harness>Env` (camelCase), `build<HARNESS>_ENV` (UPPER_SNAKE), `build{Harness}Env` / `build${HARNESS}Env` as the syntax dictates.
Always a real, greppable pattern — never `X`.