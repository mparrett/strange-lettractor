# Verification output

Tests, test runners, and reusable regression fixtures belong in Git. Generated
verification reports, model transcripts, and stage logs do not. Live runners
write to the ignored `evidence/` directory; CI may retain it as a job artifact.
Paths to that directory in audit notes describe local output, not files shipped
with a checkout. Historical committed reports remain available in Git history.

Run `make test` for deterministic checks. Live checks require a configured
provider and incur provider usage:

- `make live-parity`: coding-agent tasks selected by `ATTRACTOR_LIVE_MODEL`.
  Optionally select rows with `ATTRACTOR_PARITY_ROWS=error-recovery,provider-edit-format`.
  Reports use a timestamped filename under `evidence/parity-matrix-evidence/`.
- `make live-matrix`: unified-client journeys. See the Makefile for
  the available live targets and `test/live/provider_matrix.lg` for selectors.
- `test/live/attractor_smoke.lg`: runtime smoke with stage artifacts under
  `evidence/runtime-smoke-evidence/`.

Record the command, date, result, and material limitations in concise review or
release notes. Retain raw output locally or in CI when investigation needs it.
Promote a captured response into a regression fixture only when a test uses it
to verify behavior. A green subset does not establish the full specification.
