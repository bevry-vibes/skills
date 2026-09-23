# python

All Python work runs through [uv](https://docs.astral.sh/uv). uv manages the interpreter, the virtualenv, dependencies, and tool installs — `pip`, `python -m venv`, `virtualenv`, and activation rituals are not used.

## uv is the toolchain

- Environment setup is `uv sync` (creates `.venv` from `pyproject.toml` + `uv.lock`); running is `uv run <command>` — it resolves, syncs, and executes in the project environment in one step, so there is no activate step. Never `pip install` anything, including `pip install -e .` and `pip install -r requirements.txt`.
- Commit `uv.lock` for applications and CLIs, and commit `.python-version` (written by `uv python pin <version>`); `requires-python` in `pyproject.toml` stays the compatibility floor, `.python-version` is the dev pin. In CI use `uv sync --frozen` (or `--locked`) so the environment always matches the committed lock.
- New projects: `uv init --package`; new dependencies: `uv add` / `uv remove` (never hand-edit `pyproject.toml` dependencies and then pip-install). One-off CLI tools: `uvx <tool>`; project CLIs install globally with `uv tool install .` (the `[project.scripts]` entry points become real commands).
- Interpreters are uv's problem too: `uv python install 3.14` fetches one without a system package manager, and `uv run` uses `.python-version` to pick.
- Upgrading dependencies is `uv lock --upgrade`, not editing and reinstalling.
- Repos not yet uv-packaged (a bare `requirements.txt` plus scripts): bootstrap in a run script with `uv venv` + `uv pip install --python .venv/bin/python -r requirements.txt`, falling back to plain `python3` only when uv is absent (see image-cleanup-for-icons' `run.sh` for the pattern) — still never bare pip on the system.

## stdlib first

- Write Python with the standard library first; add a dependency only when the standard library cannot do the job (the rule translation-comparison's harness and the kagi clients run on). `urllib` + `argparse` + `html.parser` cover far more than expected, and a zero-dependency client never breaks on install.
- `from __future__ import annotations` at the top keeps modern union syntax (`str | None`) in annotations on Python 3.9+, where annotations are not evaluated.
- Single-module CLIs stay single-module: `py-modules = ["kagi_translate"]` under `[tool.setuptools]` plus a `[project.scripts]` entry point installs a real command from one file, while the module still runs directly (`uv run kagi_translate.py ...`). uv works fine with the setuptools backend; there is no need to migrate it to hatchling for uv's sake.

## hard-won lessons

- Heavy toolchains — virtualenvs, model weights, big downloaded runtimes — live in `~/.cache/<project>/`, never inside the repo (tts-comparison's rule, learned after a build wiped the in-repo `data/` directory).
- Secrets enter the program through the environment only (e.g. `KAGI_SESSION`), `.env` is gitignored, and `git grep` for token names before committing anything that touched credentials — never commit captured tokens, JWTs, cookies, or traffic logs.
- Long-running batch jobs guard the machine: wrap model-loading runs in a RAM-fit check and a single-run lock (translation-comparison's `memguard.py`) rather than trusting the operator not to run two benchmarks at once.
