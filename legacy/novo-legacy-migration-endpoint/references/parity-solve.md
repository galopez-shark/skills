# Subcommand: `/migrate parity-solve <endpoint> cases (<ids>)` (alias `solve-parity`)

> Moved out of `SKILL.md` to save context. Everything here is binding exactly as if it were inline.

After a `verify-parity` run, plan the fixes for the **cases the user chooses** to bring to parity.
The `<ids>` are the row numbers from the verify-parity matrix (e.g. `cases (9,10,11)`). Produces a
**phased roadmap** (one branch per phase — from `main` in serial mode, from the previous
phase's branch when stacked) under a **STRICTER limit than the
default**: **max 300 new lines and max 10 files per phase** (parity fixes must be small and surgical;
split into more phases when needed).

Usage: `/migrate parity-solve cashin cases (9,10,11)`

### Workflow

1. **Require a verify-parity matrix** for the endpoint. If none exists in this session, run
   `verify-parity` first (which checks out `main` and builds the matrix), then continue.
2. **Resolve the selected ids** against the matrix. Reject ids that are `✅ match` or `🟢 mejora
   intencional` (nothing to fix) and confirm the remaining set with the user.
3. **RE-VERIFY each selected case against the Java source FIRST** — read the real Java code /
   `RESPONSE_CODES` before planning any fix. If a case turns out to be intentional or unverifiable,
   flag it (`⚠️`) and drop it from the plan. Never fix from the report summary alone.
4. **Map each confirmed case → the Go change** needed: layer + file(s) + approx new lines
   (error code/message, validation order, missing branch like KYC, response field, etc.). Reuse
   go-bricks / existing helpers; defer to `target.reference_repo` for patterns.
5. **Group changes into phases under the cap** — **≤300 new lines AND ≤10 files per phase** (impl +
   tests). If the selected cases exceed it, split into `parity-1`, `parity-2`, … Each phase includes
   tests, `make check` (0 issues, coverage floor 70%, goal 85%), and a version bump.
6. **Present the roadmap and WAIT for approval.** Before creating any branch, **ASK the user for the
   Jira epic/ticket** for these parity fixes. If they give an epic, **search its children for the
   ticket matching this endpoint, show the candidate, and confirm it** before branching (same as
   Phase START step 2). Then execute phase by phase, creating `feature/{ticket}-parity-{n}` on the
   base of the active mode (see "Phase sequencing"): stacked → on the previous parity phase's branch
   (`gh stack add`); serial → `git checkout main && git pull`, branch from `main`, one phase merged
   before the next.

### Output (roadmap)

```
parity-solve: {endpoint} — cases {ids}

Confirmed for fix (verified vs Java):
  #9  {caso}   → {Go file} ({layer})   ~{X} líneas
  #11 {caso}   → {Go file(s)}          ~{Y} líneas
Dropped:
  #10 {caso}   → 🟢 intencional / no procede ({razón})

Phases (≤300 líneas · ≤10 files c/u):
  Phase parity-1  feature/{ticket}-parity-1   cases #9       ~{X} líneas, {n} files
  Phase parity-2  feature/{ticket}-parity-2   cases #11      ~{Y} líneas, {n} files
```

### Rules

- **Cap is 300 lines / 10 files per phase** — HARD, stricter than the standard 400. Split otherwise.
- **Verify each case against Java before fixing** — messages/codes are immutable, match exactly.
- **Only fix the selected cases** — never touch cases the user didn't choose.
- One branch per phase (base = previous phase if stacked, `main` if serial); tests + `make check` + version bump per phase; no commit without approval.
