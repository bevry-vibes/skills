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

## splat naming

Never refer to a to-be-defined name with `X`, `Xxx`, or `XXX`.
Use an asterisk splat (`build*Env`) or the interpolated form matching
the language's conventions — `build<Harness>Env` (camelCase),
`build<HARNESS>_ENV` (UPPER_SNAKE), `build{Harness}Env` /
`build${HARNESS}Env` as the syntax dictates. Always a real, greppable
pattern — never `X`.
