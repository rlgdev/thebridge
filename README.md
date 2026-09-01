# speckit-cobol-harness

**What this leads to:** a minimal context layer for a COBOL codebase (extracted structure as Markdown in `docs/cobol-context/`) plus a repeatable test that measures its value through spec-kit's own output — run `/speckit.specify` → `/speckit.plan` → `/speckit.tasks` on real change requests, once without and once with the context layer, and score the generated spec/plan/tasks files. Full background and the upgrade path: `PLAN.md`.

## Contents
```
install.bat / install.sh       installer (copies payload into a repo, appends CLAUDE.md block)
PLAN.md                        full plan: context layer, test loop, scale-out, risks
payload/
  scripts/extract_structure.py v0 structure extractor (regex, fixed-format COBOL)
  scripts/fill_prose.py        fills Purpose sections via Claude Code headless
  CLAUDE-block.md              the block appended to CLAUDE.md
  eval/cr-template.md          change-request + sealed-truth format
  eval/rubric.md               5 metrics + pass bar
  eval/runsheet.csv            results sheet (header only)
```

## Prerequisites
- Python 3.11+
- Claude Code CLI, authenticated (`npm install -g @anthropic-ai/claude-code`)
- git; `uv`/`uvx` for spec-kit init
- COBOL sources + copybooks exported to files (fixed format)

## Install
```
Windows:      install.bat C:\path\to\repo
Linux/macOS:  ./install.sh /path/to/repo
```
Defaults to the current directory. Idempotent — safe to re-run; the `## COBOL context` block is appended to `CLAUDE.md` only once.

## Workflow

### 1. Generate the context layer
```bash
python scripts/extract_structure.py <src-dir> <copybook-dir>
```
Writes `docs/cobol-context/` (`_index.md`, `programs/`, `copybooks/`). Facts are regex-extracted — dynamic CALLs appear as variable names; verify hard programs by hand.

### 2. Fill the prose
```bash
python scripts/fill_prose.py
```
Drafts the `Purpose` / `Structure notes` sections, grounded in the extracted facts. An SME spot-checks 3 pages before you trust the rest.

### 3. Init spec-kit (both environments)
```bash
uvx --from git+https://github.com/github/spec-kit.git specify init --here --integration claude
```
Leave spec-kit's opt-in `git` extension **off** — the active feature is tracked in `.specify/feature.json`, so runs cause no branch churn.

### 4. Create the baseline environment
```bash
git worktree add ../cobol-baseline <commit-before-docs>
cd ../cobol-baseline && uvx --from git+https://github.com/github/spec-kit.git specify init --here --integration claude
```
Identical repo, identical spec-kit init — the **only** difference is the context layer (no `docs/cobol-context/`, no CLAUDE.md block).

### 5. Run each change request in both environments
Write 2–3 CRs from `eval/cr-template.md` into `eval/crs/`; move each sealed-truth section **outside both worktrees** (e.g. `~/cobol-eval/`). Then, per CR × {baseline, with-context}, in a fresh Claude Code session:
```
/speckit.specify <paste CR description>
/speckit.plan
/speckit.tasks
```
After each run, save the output and reset:
```bash
cp -r specs/* eval/runs/CR-01-with-context/   # or CR-01-baseline
rm -rf specs/*
```

### 6. Score
Score each saved run against the sealed truth using `eval/rubric.md`; one row per (CR, variant) in `eval/runsheet.csv`. Pass bar is in the rubric — agree on it before running.

### 7. Outcomes
- **Pass** — keep the layer, regenerate on `.cbl/.cpy` change, roll the harness to the next repo.
- **Partial** (recall fails on multi-hop impact) — add cb2xml / cobol-rekt call graphs for the affected area (upgrade path in `PLAN.md`), re-run the failing CR.
- **Fail** — report which metric broke and on what; stop there.

## Notes
- Everything lives in the repo (Markdown + two scripts): no external services, works air-gapped.
- Sealed truths stay outside both worktrees until scoring — that's what keeps the numbers honest.

## Links
- spec-kit: https://github.com/github/spec-kit
- Claude Code headless mode: https://code.claude.com/docs/en/headless · memory/CLAUDE.md: https://code.claude.com/docs/en/memory
- Upgrade path: cobol-rekt https://github.com/avishek-sen-gupta/cobol-rekt · cb2xml https://github.com/bmTas/cb2xml
