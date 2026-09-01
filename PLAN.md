# COBOL Context v0 + spec-kit Test Loop (Claude Code CLI)

**What this leads to:** a minimal context layer built with one Python script and a `claude -p` batch (no Java toolchain, setup in hours), tested not by a synthetic Q&A set but by **spec-kit's own output**: the developer runs `/speckit.specify` → `/speckit.plan` → `/speckit.tasks` on real change requests, once without and once with the context docs, and we score the generated `spec.md` / `plan.md` / `tasks.md` files. If the with-context run wins, the same folder becomes the standard harness other teams repeat on their repos.

This replaces the full generator pipeline from the previous plan as the starting point; the parser-based pipeline (cobol-rekt, cb2xml) is now the **upgrade path**, adopted only where v0 scores demand it.

**Definition of done:**
- [ ] `docs/cobol-context/` (v0) generated for the pilot programs
- [ ] `CLAUDE.md` block added
- [ ] 2–3 change requests run through specify → plan → tasks, baseline vs. with-context
- [ ] `eval/runsheet.csv` filled + go/no-go recommendation

---

## 1. Minimal context layer (v0)

### 1.1 Layout
```
docs/cobol-context/
  _index.md            # program inventory: calls, copybooks, DB2/CICS flags
  programs/<PROG>.md   # extracted facts + Claude-drafted purpose
  copybooks/<COPY>.md  # field list (level, name, PIC)
```

### 1.2 Deterministic skeletons — `scripts/extract_structure.py`
Regex-based starter, not a parser — it extracts the facts that anchor everything else (CALL / COPY / PERFORM targets, files, DB2/CICS flags) and writes skeleton pages. Dynamic CALLs are recorded as the variable name; hard programs get verified by hand.

```python
#!/usr/bin/env python3
"""v0 COBOL structure extractor (regex starter, fixed-format).
Usage: python scripts/extract_structure.py <src-dir> [<copybook-dir>]"""
import re, sys, pathlib

SRC = pathlib.Path(sys.argv[1]); CPY = pathlib.Path(sys.argv[2]) if len(sys.argv) > 2 else None
OUT = pathlib.Path("docs/cobol-context")
(OUT / "programs").mkdir(parents=True, exist_ok=True)
(OUT / "copybooks").mkdir(exist_ok=True)

def code(text):  # strip fixed-format comment lines + sequence/ident columns
    return "\n".join(ln[6:72] for ln in text.splitlines()
                     if len(ln) > 6 and ln[6] not in "*/").upper()

def find(root, exts):  # case-insensitive extension match (.CBL mainframe exports are common)
    return sorted(p for p in root.rglob("*") if p.suffix.lower() in exts)

rows = []
for f in find(SRC, {".cbl", ".cob"}):
    t = code(f.read_text(errors="ignore"))
    m = re.search(r"PROGRAM-ID\.\s+([A-Z0-9-]+)", t)
    pid = m.group(1) if m else f.stem.upper()
    calls = sorted(set(re.findall(r"CALL\s+['\"]([A-Z0-9-]+)['\"]", t)))
    dyn   = sorted(set(re.findall(r"CALL\s+(?!['\"])([A-Z][A-Z0-9-]*)", t)))
    copys = sorted(set(re.findall(r"\bCOPY\s+([A-Z0-9-]+)", t)))
    perfs = sorted({p for p in re.findall(r"(?<!-)\bPERFORM +([0-9A-Z][A-Z0-9-]*)", t)
                    if not p.isdigit()}
                   - {"UNTIL", "VARYING", "TIMES", "WITH", "TEST"})
    files = sorted(set(re.findall(r"\bSELECT\s+([A-Z0-9-]+)\s+ASSIGN", t)))
    flags = [k for k, p in [("DB2", r"EXEC\s+SQL"), ("CICS", r"EXEC\s+CICS")] if re.search(p, t)]
    (OUT / "programs" / f"{pid}.md").write_text(f"""# PROGRAM-ID: {pid}
> Source: `{f}` · Extractor: v0 regex — facts below are extracted, verify edge cases

## Purpose (GENERATED-SUMMARY — verify against source)
_TODO_

## Facts (extracted)
- Static CALLs: {', '.join(calls) or 'none'}
- Dynamic CALLs via: {', '.join(dyn) or 'none'}
- Copybooks: {', '.join(copys) or 'none'}
- PERFORM targets: {', '.join(perfs) or 'none'}
- Files (SELECT): {', '.join(files) or 'none'}
- Embedded: {', '.join(flags) or 'none'}

## Structure notes (GENERATED-SUMMARY — verify)
_TODO_
""")
    rows.append(f"| {pid} | {', '.join(calls + dyn) or '-'} | {', '.join(copys) or '-'} | {', '.join(flags) or '-'} | `{f}` |")

(OUT / "_index.md").write_text(
    "# COBOL program inventory (v0)\n\n| Program | Calls | Copybooks | Embedded | Source |\n|---|---|---|---|---|\n"
    + "\n".join(rows) + "\n")

if CPY:
    for c in find(CPY, {".cpy"}):
        t = code(c.read_text(errors="ignore"))
        frows = []
        for m in re.finditer(r"^\s*(\d{2})\s+([A-Z0-9-]+)([^.]*)\.", t, re.M | re.S):
            lvl, name, rest = m.group(1), m.group(2), m.group(3)
            pm = re.search(r"PIC\s+([^\s.]+)", rest)
            notes = ", ".join(re.findall(r"REDEFINES\s+[A-Z0-9-]+|OCCURS\s+\d+|COMP-3|COMP\b", rest))
            frows.append(f"| {lvl} | {name} | {pm.group(1) if pm else '-'} | {notes or '-'} |")
        (OUT / "copybooks" / f"{c.stem.upper()}.md").write_text(
            f"# COPYBOOK: {c.stem.upper()}\n> Source: `{c}` · v0 field list (no offsets — add cb2xml for offsets)\n\n"
            "| Level | Field | PIC | Notes |\n|---|---|---|---|\n" + "\n".join(frows) + "\n")
```

```bash
python scripts/extract_structure.py src/cbl src/cpy
```

### 1.3 Fill the prose with Claude Code (headless batch)
```bash
for p in docs/cobol-context/programs/*.md; do
  claude -p "Fill the '## Purpose' and '## Structure notes' sections of $p in place. Ground every claim in the Facts section of that file and in the source file it references. Use only paragraph, program and field names that exist there. Do not change the Facts section." \
    --allowedTools "Read,Grep,Edit" --max-turns 10 --output-format json | jq -r '.result' 
done
```
SME spot-checks 3 pages before you trust the rest.

### 1.4 Add to `CLAUDE.md`
```markdown
## COBOL context

`docs/cobol-context/` holds extracted structure for the COBOL codebase.
For any COBOL task: read `_index.md`, then `programs/<PROG>.md`, then
`copybooks/<COPY>.md` for layouts — before opening raw source. Grep this
folder first for impact questions; identifiers appear verbatim.
The "Facts" sections are extracted and authoritative for navigation;
GENERATED-SUMMARY sections must be verified in source. Never invent
program, paragraph, or field names.
```

**Upgrade path (only if v0 scores demand it):** cb2xml for copybook offsets → cobol-rekt (SMOJOL) for exact call graphs, Mermaid flowcharts, data lineage — see the previous plan (`cobol-context-prepass-action-plan-claude-code.md`).

---

## 2. The test loop = spec-kit itself

The measure of success is whether **specs, plans and tasks get better**, not whether Claude answers trivia.

### 2.1 Setup
```bash
uvx --from git+https://github.com/github/spec-kit.git specify init --here --integration claude
```
Branching note: current spec-kit manages git branching via an **opt-in `git` extension** (not installed by default) and tracks the active feature in `.specify/feature.json`, not the checked-out branch. Leave the extension off for the eval — no branch churn between runs. (`--ai` still works but is deprecated in favor of `--integration`.)

Create the **baseline** environment — identical repo, identical spec-kit init, but no context layer:
```bash
git worktree add ../cobol-baseline <commit-before-docs>   # no docs/cobol-context, no CLAUDE.md block
cd ../cobol-baseline && uvx --from git+https://github.com/github/spec-kit.git specify init --here --integration claude
```
The **only** difference between the two environments is the context layer.

### 2.2 Pick 2–3 real change requests (CRs)
Small, realistic changes touching the pilot programs — e.g., "extend ACCT-STATUS from PIC X to PIC XX end-to-end", "add a new reject reason to the nightly batch report". For each CR the SME writes a **sealed ground truth** (not shown to the agent): affected programs, copybooks, paragraphs, files/tables. Store the description as `eval/crs/CR-01.md`; keep the sealed truth **outside both worktrees** (e.g. `~/cobol-eval/CR-01.truth.md`) until scoring.

### 2.3 Run matrix
For each CR × {baseline, with-context}, in a fresh Claude Code session:
```
/speckit.specify <paste CR description>
/speckit.plan
/speckit.tasks
```
(`/speckit.clarify` allowed if the flow proposes it — count the questions, see rubric.) After each run, copy the generated feature folder out and remove it:
```bash
cp -r specs/* ../eval/runs/CR-01-with-context/   # or CR-01-baseline
rm -rf specs/*
```
The active-feature pointer in `.specify/feature.json` is machine-local and rewritten by the next `/speckit.specify`, so removing the feature folder is enough. If you did install the git extension and it created a feature branch, also `git checkout <main> && git branch -D <feature-branch>` between runs.

### 2.4 Scoring rubric (SME scores the saved spec.md / plan.md / tasks.md)
| Metric | How to score |
|---|---|
| Current-behavior accuracy | spec's description of existing behavior vs. reality: 0 wrong / 1 partial / 2 correct |
| Affected-asset recall | % of programs+copybooks from the sealed truth that appear in spec/plan |
| Hallucinated identifiers | count of nonexistent program/paragraph/field names across all three files |
| Clarification burden | # of questions or `[NEEDS CLARIFICATION]` markers that the code itself could have answered |
| Task executability | % of tasks referencing real files/paragraphs a developer could start without re-research |

`eval/runsheet.csv`:
```
cr_id,variant,behavior_0_2,recall_pct,hallucinated_ids,clarifications,tasks_executable_pct,notes
```

### 2.5 Pass bar (proposal — adjust before running)
- With-context beats baseline on **≥3 of 5 metrics on every CR**
- Affected-asset recall **≥80%**, hallucinated identifiers **≤2 per run**
- No metric materially worse than baseline

### 2.6 Outcomes
- **Pass** → keep the layer, regenerate weekly or on `.cbl/.cpy` change, proceed to scale-out (section 3).
- **Partial** (recall fails on multi-hop impact) → add cb2xml / cobol-rekt call graphs for the affected area only, re-run the failing CR.
- **Fail** → stop; report which metric broke and on what.

---

## 3. Scale-out across teams

Package the whole loop as a single deployable zip (`speckit-cobol-harness.zip`) any team can install into their repo:

```
speckit-cobol-harness/
  README.md                    # workflow: install → generate → run CRs → score
  install.bat / install.sh     # copies payload into the repo, appends the CLAUDE.md block (idempotent)
  PLAN.md                      # this document
  payload/
    scripts/extract_structure.py
    scripts/fill_prose.py      # Purpose sections via claude -p (cross-platform, no jq)
    CLAUDE-block.md
    eval/cr-template.md
    eval/rubric.md
    eval/runsheet.csv
```

Adoption flow per repo: (1) run `install.bat` / `install.sh` in the repo, (2) run the extractor on 5–10 pilot programs, (3) fill prose with `scripts/fill_prose.py` + SME spot-check, (4) run 2 CRs through specify → plan → tasks in both variants, (5) submit the runsheet row. Central owner keeps one aggregated runsheet (a row per repo) — that's the evidence base for mandating the context layer, and for deciding where the cobol-rekt upgrade is worth it.

Fits restricted environments: everything lives in the repo (Markdown + one script), no external services, works air-gapped. When the loop is trusted, the run matrix can move to CI via headless mode (`claude -p "/speckit.specify ..."` etc.) — first verify custom slash commands execute under `claude -p` in the installed CLI version; manual sessions are fine for the first repos.

---

## Risks & fallbacks

| Risk | Symptom | Fallback |
|---|---|---|
| Regex extractor misses (dynamic CALLs, free-format, COPY REPLACING) | wrong/missing facts on hard programs | facts are labeled v0; SME fixes the page by hand; upgrade that area to cobol-rekt |
| Claude-drafted prose hallucinates | plausible-but-wrong Purpose text | grounding prompt + `--allowedTools Read,Grep,Edit` only + SME spot-check; Facts sections stay untouched |
| Ground truth leaks into runs | inflated scores | keep `*.truth.md` outside both worktrees until scoring |
| Baseline contaminated | context present in baseline run | baseline worktree pinned to pre-docs commit; verify `docs/cobol-context` absent before each run |
| spec-kit folder churn between runs | runs overwrite each other | copy `specs/` out and remove the feature folder after every run (section 2.3) |

## Links

- spec-kit: https://github.com/github/spec-kit
- Claude Code headless mode: https://code.claude.com/docs/en/headless · memory/CLAUDE.md: https://code.claude.com/docs/en/memory
- Upgrade-path tools: cobol-rekt https://github.com/avishek-sen-gupta/cobol-rekt · cb2xml https://github.com/bmTas/cb2xml
