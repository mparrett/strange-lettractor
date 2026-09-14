# Console Input — Findings & Plan

## Input Findings

# Console input findings

Inspected 2026-09-06 after fan-in checkpoint `1fe6bd6`.

Update: `1ca62bb` fixes prompt flushing with the existing `term/flush` primitive.
Independent spec/quality reviews approve; 12 interviewer tests / 109 assertions
pass. A real PTY question now displays its prompt, reads supplied text, and exits
successfully. The original failure below is historical; question deadlines remain
unimplemented. Auto-approve's empty-choice fallback now matches upstream §6.4.

## Observed failures

Calling the real console interviewer with a freeform question and
`:timeout_seconds 0.05` immediately throws `io/flush expects 1 arg`.
`src/attractor/interviewer.lg` calls `(io/flush)` in all three input paths;
the local runtime's `pkg/rt/ions.go` requires a writer argument. This is an
application API misuse, not evidence of a let-go Clojure-compatibility bug.

With only that flush call temporarily replaced by a no-op through `with-redefs`
in a diagnostic process, the same question remained blocked after the tool's
one-second observation window, exceeding its 50ms timeout. Supplying
`probe complete` then returned that text normally and the process exited 0.
No process or blocked input reader from this probe remains running.

The human handler constructs questions without `timeout_seconds`, so fixing
console input alone would not connect DOT execution to question deadlines.
However, upstream §4.6 constructs the question the same way and does not define
a DOT attribute supplying that field. Automatic forwarding is an integration
design decision, not a separate demonstrated spec violation. In particular,
reusing the engine's node-attempt deadline risks making its timeout failure race
the interviewer's default-answer handling. The upstream snapshot §§6.4–6.5
does require nonblocking console input for a supplied question timeout, returning
the question default on expiry or `:timeout` when no default exists.

## Native input boundary

Local `pkg/rt/iort.go` implements `read-line` using buffered
`ReadString('\n')`; it does not consult its execution context for cancellation
while the read is blocked. A timed future around that call would not establish
reader cleanup or prevent a late read from consuming a later question's answer.

`term/key-pending?` plus `term/read-key` is not a complete general replacement:
the native readiness check returns false for empty/EOF input, operates on the
terminal key source rather than the bound `*in*` reader, and tokenization may
need additional bytes. A terminal-only implementation would leave redirected
input and reader bindings unproved.

## Proposed direction (not yet approved or implemented)

Prefer a cancellation-aware timed line-input primitive in let-go, with an
explicit distinction between a line, EOF, timeout and I/O failure; preserve
partial data across deadlines and do not close borrowed stdin. Define ownership
and unsupported-reader behavior explicitly. Expose proper `vm.Nil, err` error
returns and prove native supervision cleanup with real pipes/terminal input.

Then keep Attractor's answer parsing and deadline/default policy in let-go:
inject a bounded input operation and clock for deterministic tests; fix prompt
flushing; connect human-node question deadlines/cancellation; cover all
interviewer implementations and public routing. Do not use detached reader
workers or a platform-specific shell command as the portability contract.

An alternative is a project-owned native host extension, but that duplicates
runtime I/O machinery and changes the current lgx/AOT integration. A detached
future is simpler but does not satisfy the joined-cleanup requirement.

The local let-go checkout is user-owned and dirty. No upstream files were
modified; the native API contract and authority to implement it there still
need confirmation. This does not block independent remaining Attractor work.

---

## Framing Contract Plan

# Console input routing implementation plan

Status: implementation, tests, paired quality reviews and final audit verified.
This is a component of the user-requested console extension, not full delivery.

**Goal:** One mechanically tested framing contract for agent messages, commands
and explicit let-go evaluation in both console presentations.

**Architecture:** `attractor.console.input/accept` is a pure reducer returning
`{:state ... :action ...}`. It never invokes a reader, evaluator, agent or shell.
The caller supplies a selection map; completed actions capture it as `:selection`.
Multiline evaluation captures selection when the closing delimiter submits it,
just like single-line evaluation. The later dispatcher must validate that the
captured session is still available. A focus change after submission must not
retarget the action; a focus change while editing affects the eventual selection.

**Tech stack:** local let-go >=1.12.2; clojure.test. No new dependencies here.
tiny-tui remains the presentation library for the later TUI.

## Chunk 1: framing contract

Files: create `src/attractor/console/input.lg`,
`test/attractor/console_input_test.lg`, `test/runner.lg attractor.console-input-test`.

- [x] Write failing tests for plain text, column-zero prefixes, escaped literals,
  known/unknown commands, and blank input.
- [x] Run `/Users/ndn/development/let-go/lg -source-paths src:test test/runner.lg attractor.console-input-test`;
  verify missing implementation, then assertion failures against a minimal stub.
- [x] Implement `accept [state event selection]`; events are `{:type :line :text s}`,
  `{:type :interrupt}`, or `{:type :eof}`. Initial state is `{}`. Actions use
  `:type :agent/:command/:eval/:error/:cancel/:quit` with appropriate `:text`,
  `:command`, `:args`, or `:message`. Idle blank input is a no-op. Preserve all
  nonblank agent/eval payload whitespace. Only ASCII space after `:` enters eval.
  A leading backslash strips exactly one character and forces agent text;
  blank-after-strip is a no-op. Recognize slash command names
  separated by whitespace; preserve arguments after leading separator whitespace.
  Known commands are help, agents, focus, run, cancel, quit. All six emit command
  actions (including quit); EOF alone emits a quit action. Unknown slash commands
  emit errors. Single-line `: ` emits an eval action with empty text.
- [x] Add failing multiline tests; implement exact-line `:{`/`:}` framing,
  newline joining, escaped close, nested open as text, submission-time selection
  capture, interrupt discard, and EOF discard plus quit. Empty multiline
  submission emits explicit eval with empty text. Buffer interrupt clears state
  with nil action: it must not cancel a running worker. Idle interrupt emits cancel
  with current selection. Unknown event types emit errors preserving state.
  EOF always clears state and emits quit.
- [x] Prove purity with code-looking input and Unicode payload preservation.
  Include ordinary backslashes, slash commands and eval prefixes inside multiline
  buffers as verbatim text; delimiter trailing space/CR must prevent framing.
- [x] Run focused tests, full regression suite and standalone focused bundle
  outside checkout. Review code and evidence before commit/push.
  Full suite: `env PATH=/Users/ndn/development/let-go:/opt/homebrew/bin:/usr/local/go/bin:/usr/bin:/bin:/usr/sbin:/sbin /Users/ndn/.local/share/mise/installs/github-abogoyavlensky-lgx/0.1.0-rc2/lgx test`.

## Remaining delivery (not satisfied by reducer tests)

- Persistent native eval namespace and captured session bindings; no implicit eval.
- Agent/workflow controls and identified streaming events.
- Owned input lifecycle, cancellation and EOF with native terminal evidence.
- Qwen live trial, Claude Code worker, Codex app-server, full-screen tiny-tui adapter.
- Original StrongDM requirements stay open in the existing iteration backlog.

---
