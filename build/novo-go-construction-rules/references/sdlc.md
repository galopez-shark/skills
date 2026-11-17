# SDLC — NovoPayment standard (org-wide alignment)

> Shared construction rules, loaded on demand by `novo-legacy-migration-endpoint` and `novo-go-build`.
> Binding exactly as if they were inline. Where the text says Java, parity or `EST-NN`, see "Reading these rules" in `SKILL.md`.

This skill's phase flow implements NovoPayment's **SDLC Developer Quick Reference**. Keep these
org-wide rules in sync with the per-phase steps above.

### Branching
`[tipo]/[JIRA-ID]-[desc-kebab]`, branched from `main` (serial) or from the previous phase's
branch (stacked — the name is identical either way, only the base differs). Types: `feature/` (nueva funcionalidad),
`fix/` (bug), `hotfix/` (urgente en prod). Lowercase + kebab-case, description 3–5 words, JIRA-ID
mandatory. This repo's migration phases append the phase to the desc (`feature/CEB-XXXX-service`).
- ❌ `feature/login` · `gabriel/fix-bug` (no name prefix) · `Feature/PAY-456-Login` (caps) ·
  `feature/PAY-456` (no desc) · overly long descriptions
- ✅ `feature/CEB-5634-service`

### Commits & PR title
Conventional Commits: `tipo: descripción en minúsculas`. **Valid types (ONLY):**
`feat` · `fix` · `hotfix` · `docs` · `test` · `refactor` (never `chore`/`perf`).
- **Ticket goes in the BODY as `Refs: CEB-XXXX`, NEVER in the subject** (org SDLC + NKH1). The
  title is `tipo: descripción` only. Keep the subject **≤72** chars.

### PR size (reviewable in < 30 min)
- `<200` líneas = ✅ ideal · `200–400` = ⚠️ aceptable (justificar) · `>400` = ❌ dividir antes de review.
- Split by: one endpoint/feature per PR; business logic apart from infra/config; refactors in their
  own PR; tests can land in a prior PR; DB migrations independent. (Matches the ≤400/10-file phase cap.)

### Quality gates (Go) — enforced by `make check`
staticcheck · go vet · gosec · gocyclo · ineffassign · `go test -cover`. Plus **CodeRabbit** on the
PR — review & resolve every comment before requesting merge.

### Testing mix & coverage
**60% unit · 30% integration (APIs/endpoints) · 10% E2E (critical flows).** Coverage **floor 70%**,
**goal 85%**. Exceptions (no tests required): config files, simple constants/enums, generated code,
critical hotfixes (with a documented remediation plan in the PR).

### Deployment (immutable build)
`main → DEV (auto on merge) → UAT (PO approval) → PRD (Prod approval)`. Same artifact promoted across
environments; config is external and per-environment. Migration endpoints follow this after the
handler phase merges.

### Hotfix (expedited)
`hotfix/JIRA-ID-desc` from main → fix mínimo → testing acelerado en DEV → review (puede ser post-merge
en emergencia) → aprobación de Producción → deploy a PRD → post-mortem. Coverage bypass permitido con
plan de remediación documentado en el PR.

### DORA targets
Lead time `<2d` features / `<4h` hotfix · `≥2` deploys/week · change-failure `<5%` · MTTR `<1h`.
