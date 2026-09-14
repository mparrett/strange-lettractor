# Claude Worker — Agent & Implementation Plan

## Claude Agent Reference

# Claude Code agent

Strange Lettractor launches Claude Code as an owned external agent. Claude runs
its own tool loop; this is separate from the Anthropic unified-LLM adapter.
The connector is implemented in let-go and does not depend on the unfinished hub
or TUI.

Build with your local let-go, then use a prompt file:

```sh
lgx build
bin/attractor agent claude --prompt-file examples/claude-smoke.md --cwd . --model sonnet
```

Output is a stream of EDN event maps identifying the job and Claude session.
Claude's JSON-lines protocol stays inside the connector. Token deltas are distinct
from complete assistant/result records; consumers must not concatenate all three.
See Claude's [programmatic streaming protocol](https://code.claude.com/docs/en/headless)
for the external message format.
The command exits nonzero for failed, malformed, missing-result, timed-out or
cancelled work. Default timeout is 120000ms; set `--timeout-ms` explicitly for
longer tasks.

Default access is `--tools Read --permission-mode plan`. To authorize editing:

```sh
bin/attractor agent claude --prompt-file task.md --cwd . --tools Read,Edit,Write --permission-mode acceptEdits
```

This is explicit tool authority, not a sandbox. There is no permission-bypass flag.
Permissions needing interaction are denied, not silently approved. Claude's safe
mode disables customization/hooks/MCP for these jobs; normal CLI authentication
is retained. Authenticate using Claude's own CLI; the connector does not copy
credentials or choose a replacement provider. CLI availability does not prove
subscription billing or remaining quota.

## Console use

`attractor console` dispatches the same connector as a hub-owned agent job:
`/agent claude <prompt> [--cwd d] [--model m] [--tools a,b] [--permission-mode p]`
(`/alias claude agent claude` if you want the short form). Job defaults come
from `--agent-cwd`, `--agent-model`, `--agent-tools`, `--agent-permission-mode`
and `--agent-timeout-ms` on the console command. Events render as
`[claude <id>]` lines; `/cancel` with the job focused requests cooperative
cancellation; `/list` shows running and finished jobs. See `docs/console-requirements.md` (SCN-CONSOLE-CONTROL).

Known strictness limit (2026-09-08): a long review run (34 turns) returned a
valid successful `result`, after which the CLI emitted one more record; the
connector reports `:claude-protocol` "record after its terminal result" and
exits 1 although the result text is intact in the event stream. Follow-up:
tolerate records after a valid terminal result (surface them, keep exit 0).

## Workflow and library use

```sh
bin/attractor run examples/claude-smoke.dot --agent claude --model sonnet --auto-approve --cwd .
```

`run` and `resume` accept `--agent claude` plus the same options. This
explicit selection never falls back to mock or an API-key model adapter.
`--mock` cannot be combined with it. `--auto-approve` concerns workflow human
gates; it does not grant Claude additional tool permissions.

The library entry points are `attractor.agents.claude/run!`,
`attractor.agents.registry/run!` (by agent name) and
`attractor.agents.backend/make-backend` (any agent as a codergen backend). Options include `:prompt`,
`:working_dir`, `:model`, `:tools`, `:permission_mode`, `:timeout_ms`,
`:cancelled?`, and `:on_event`. `run!` returns the final text/result or throws a
tagged failure only after its owned command has been joined.

This initial connector is one-shot. Full-fidelity Claude session reuse and
interception of Claude's internal tools by Attractor tool hooks are rejected
explicitly, not silently emulated. Persistent bidirectional sessions and hub
attachment remain follow-up work.

## Process ownership

The local let-go runtime offers buffered `os/sh`, streaming `os/exec*`, and a
boxed `os/exec` command usable through Go interop. That low-level command is not
the framework's already-tested process-group cancellation/timeout contract.
The connector therefore reuses Attractor's existing execution environment for
process-group timeout/cancellation and private stdin, and reads bounded protocol
records incrementally from private output files while the process is running.
Shell glue is limited to quoted argv/redirection in that existing adapter.
Temporary files are removed only after joining; no Go/Python helper is added.

Deterministic tests use a real let-go child process, separately from a live
authenticated Claude trial:

```sh
export LGX_LG="$HOME/development/let-go/lg"
"$LGX_LG" -source-paths src:test test/runner.lg attractor.claude-agent-test
"$LGX_LG" -source-paths src:test test/runner.lg attractor.claude-cli-test
```

The fixture subprocess also uses `LGX_LG`; without it, it resolves `lg` from PATH,
which must likewise be version 1.12.2 or newer.

---

## Claude Worker Implementation Plan

# Claude worker implementation plan

User priority: deliver a reusable let-go Claude connector now; pause the unfinished
hub event-origin work. This executes the external-worker design already discussed,
without requiring the RPC hub or TUI to be complete.

## Contract

`attractor.workers.claude/run!` accepts a prompt, working directory, explicit tool
allowlist/mode, optional model, timeout, cancellation predicate and event callback.
It runs Claude Code's own tool loop, not an Anthropic model completion adapter.
Use installed `claude -p --output-format stream-json --verbose
--include-partial-messages --safe-mode --permission-prompts none`. Default tool
access is Read with plan mode; explicit edit mode may use acceptEdits and a named
allowlist, never bypass permissions or silently select another provider.
Auth stays with the installed Claude CLI; never read or copy credentials.

Let-go owns parsing, event identity, termination, and result validation. Reuse the
existing owned execution environment for process-group timeout/cancellation and
private stdin. Native os/exec offers a low-level boxed command, but os/sh buffers
output and os/exec* has no owned process handle/stdin binding. Reuse the proven
execution environment and stream stdout through a private temporary file
read incrementally by let-go while the owned command runs. Shell syntax is limited
to quoted argv/redirection through the existing execution adapter; no new shell
or Go orchestration implementation. Internal events/output use EDN; JSON lines
exist only at Claude's protocol boundary. Enforce record size/output bounds and
clean only exact owned temporary files after the process is joined.

Expose identified raw protocol records plus normalized text deltas and final
completion. Do not emit aggregate assistant/result text again as token deltas.
Require one valid terminal result and a successful process exit for success;
malformed/truncated streams, is_error, missing result and nonzero exit fail
explicitly. Callback failure must cancel and join the process before returning.

## Delivery steps

- [x] Add worker module `src/attractor/workers/claude.lg`, native subprocess
  fixture `test/fixtures/claude_worker.lg`, focused tests/runner. Red/green proves
  literal prompt transport, live events before exit, fragmented records, UTF-8,
  tool/result records, errors, cancellation and timeout with joined shutdown.
- [x] Add `attractor claude --prompt-file <file> [--cwd <dir>]` entry point,
  plus explicit `--worker claude` selection for existing DOT run/resume backend.
  Add CLI/backend tests. No missing API key means mock when Claude is selected.
- [x] Document short reusable commands and library use; run focused/impacted
  checks and a bounded real Claude prompt through this connector, not `lg -e`.
- [ ] Review the resulting implementation, build and verify CLI use; commit/push
  only connector files once verified. Preserve unfinished hub work separately.

The public hub origin regression remains intentionally failing and is not part of
this connector. Full default-suite reporting must disclose it rather than hide it.
This does not claim completed bidirectional persistent sessions, RPC or TUI.

## Evidence so far

Native subprocess suite: 7 tests / 40 assertions / zero failures. CLI plus
existing CLI regressions: 12 tests / 89 assertions / zero failures. Local let-go
build succeeds. A real `bin/attractor claude` invocation using the checked-in
LICENSE smoke prompt streamed identified protocol/text events and returned
`Apache-2.0` with successful terminal result and process exit 0. No ad hoc
`lg -e` or external shell review wrapper was used for that trial.

The actual compiled DOT smoke also succeeds through `--worker claude`: streamed
records contain a Read call targeting LICENSE, the saved response contains
Apache-2.0, and the checkpoint completes start/inspect/exit with the captured
workflow fingerprint. Connector correctness review found no blocking issues.

Final connector-only HEAD-plus-explicit-files publication candidate passes the
full default suite: 699 tests / 6777 assertions / zero failures, exit 0. Candidate
build/help also pass. The fixture interpreter honors nonblank LGX_LG, otherwise
PATH lg; use a supported runtime for both parent and child processes.
Do not interpret this as a green claim for the dirty console worktree's preserved
two-failure hub regression. Commit/push is the remaining delivery step.

---
