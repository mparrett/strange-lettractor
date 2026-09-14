# Console Features — Consolidated

## Console Requirements

# Console extension requirements and evidence

User-requested addition to StrongDM Attractor conformance. All items pending
unless concrete evidence below says otherwise. No conformance story is removed.

| Story | Acceptance / proof obligation | Evidence seam |
|---|---|---|
| CONSOLE-INPUT-01 | Prefix routing, literal escapes, multiline framing, discard/EOF, immutable submission selection; never evaluate during routing | Public reducer transcript tests, SCN-CONSOLE-INPUT |
| CONSOLE-EVAL-01 | Persistent native namespace; values/errors rendered; selected session/run bound at submission; explicit human input only | Verified in-process: SCN-HUB-CONSOLE-OPS and SCN-CONSOLE-CONTROL |
| CONSOLE-CONTROL-01 | Agent text and workflow commands share console; focus and events preserve session/run identity | Verified: SCN-CONSOLE-CONTROL transcript through the real hub with the fixture provider |
| CONSOLE-INPUT-02 | One owned input source, concurrent stream redraw, cancellation, EOF and terminal restoration | Partial: native PTY covers Ctrl-C, EOF and restoration (SCN-CONSOLE-TUI); resize and exception paths pending |
| CONSOLE-WORKER-01 | Qwen invoked through Attractor; bounded live implementer trial and mechanical acceptance | Partial: live Qwen conversation turn through the console hub (SCN-CONSOLE-LINE); bounded implementer trial pending |
| CONSOLE-WORKER-02 | Owned Claude Code subprocess, streaming events, explicit permissions, failure/cancel/exit; no silent fallback | Let-go protocol fixture plus separately recorded live framework trial |
| CONSOLE-WORKER-03 | Codex app-server orchestration and interleaved identified worker events | Verified: transport 4/41 and worker 3/15 against the let-go fake child, `/agent codex` through the hub (SCN-CONSOLE-CONTROL), one live turn via `bin/attractor agent codex` |
| CONSOLE-TUI-01 | tiny-tui full-screen presentation using same dispatcher as line console | Verified: SCN-CONSOLE-TUI headless plus native PTY |
| CONSOLE-HUB-01 | RPC hub owns framework sessions, workers and evaluation; console is a client; disconnect does not implicitly cancel work | Partial: in-process hub owns sessions, evaluation, workflows and workers and client detach leaves work running (SCN-HUB-CONSOLE-OPS, SCN-CONSOLE-CONTROL); separate-process RPC and reconnect/replay pending |

CONSOLE-HUB-01A is the implemented agent-ownership component of CONSOLE-HUB-01,
specified in `docs/hub-session-plan.md`. Its public in-process integration scenario
SCN-HUB-AGENT-OWNERSHIP proves actual agent ownership, scoped client detach,
cancel/shutdown and bounded event history. It does not satisfy the parent story's
separate-process RPC or workflow/evaluation obligations.

## SCN-HUB-AGENT-OWNERSHIP

The in-process `attractor.hub` owns actual agent sessions and native scoped turn
workers. Public requests cover open/list/submit/cancel, client attach/detach and
joined shutdown; bounded event history uses explicit replay cursors. Event origin
is captured at emission and per queued child input, not callback delivery.

Focused native and outside-checkout bundle: 20 tests / 149 assertions, no failures.
Existing affected lifecycle checks: 166/1044/0. Full default suite: 719/6926/0.
Build/help pass. A live tool-free Qwen turn through hub -> agent -> unified client
-> llama.cpp returned `hub connected`, with 7 retained events and 2 text deltas
after detach and attachment of a new observer. This is not a separate-process RPC
or terminal client test.

Actual Claude implemented the bounded origin change through the published
let-go connector. Main stabilized the original failing fixture, strengthened
queued-nil and active/idle-close evidence, and ran the commands. A separate
read-only Claude review approved the agent/test changes; its hub read window
missed the mapping, which main inspected directly. No full TUI/hub story closure.

## SCN-CLAUDE-WORKER

CONSOLE-WORKER-02's standalone/DOT worker component is public as `84c3b7a`.
Native subprocess tests pass 7/40; CLI plus existing CLI tests pass 12/89. Both
compiled direct and real DOT LICENSE trials succeeded through the connector.
See [worker interface and permissions](agent-workers.md). Hub worker attachment
and interleaved console rendering remain pending.

## SCN-HUB-CONSOLE-OPS

Story: CONSOLE-EVAL-01, CONSOLE-HUB-01 (in-process operations component).
`attractor.hub` serves `:eval/submit` (persistent `attractor.console.user`
namespace with interned `hub`, `request!`, `events-since`, `*session*`,
`*run*`; one evaluation at a time, busy rejected, printed output captured,
errors rendered), `:workflow/run|cancel|list` (hub-owned pipeline runs with
cooperative cancellation) and `:agent/run|cancel|list` (owned external
agent jobs through the registered connectors). Every source shares the
bounded event log. Evidence 2026-09-08: `test/runner.lg attractor.hub-console-ops-test` 6 tests /
33 assertions with the fixture provider, a mock DOT workflow and the let-go
worker fixture, including busy, cancel-leaves-hub-alive and failure paths.
Requires the local runtime's context-aware `eval` (nooga/let-go#833).

## SCN-CONSOLE-CONTROL and SCN-CONSOLE-LINE

Stories: CONSOLE-CONTROL-01, CONSOLE-EVAL-01 (client side), CONSOLE-INPUT-02
(line frontend part). `attractor.console.session` is the frontend-independent
dispatcher (attachment, focus, reducer state, rendering of identified events);
`attractor.console.line` is the streaming line frontend; `attractor console`
starts an in-process hub with the run/resume model, worker and interviewer
configuration. Evidence: `test/runner.lg attractor.console-session-test` 4 / 39 (agent text,
eval values/errors/multiline/selection binding, /run + /claude + /agents +
/focus + /cancel + escapes, interrupt routing, quit detaches without stopping
the hub); `test/runner.lg attractor.console-line-test` 2 / 12 (scripted transcript, EOF).
Live: a Qwen turn through `attractor console --model qwen3.8-27b --provider
openai-compat` (the provider was then still named `ollama`) against llama.cpp returned `console connected` and `turn complete`.

## SCN-CONSOLE-TUI

Story: CONSOLE-TUI-01, CONSOLE-INPUT-02 (TUI part). `attractor.console.tui`
runs the same dispatcher on tiny-tui (pinned `v0.1.3`, `3d2aeaa6`) with an
app-owned reader merging keys and hub-event ticks; Ctrl-C discards a draft,
cancels busy focused work, or quits when idle. Evidence:
`test/runner.lg attractor.console-tui-test` 2 / 13 headless (scripted keys, captured frames);
`test/probes/console_pty_check.lg` 2 / 11 drives the built CLI under a real
pseudo-terminal through script(1): alternate screen entered and restored,
status line, echoed input, mock reply, evaluation, exit 0, and the line
frontend quitting on EOF. Resize and exception-restoration cases are not yet
covered natively.

## Review of the console milestone

An independent read-only review through `bin/attractor claude` reported 18
findings. Fixed with regression tests: workflow/worker entries registered
after launch (fast failures stayed "running"); three independent focus slots
(now one focus plus a remembered agent session, so `/cancel` targets what
`/focus` selected); `/run` without `--auto-approve` building a stdin-reading
interviewer under the frontend (refused until questions arrive as hub events);
eval namespace and `in-ns` shared across hubs in one process (per-hub
namespaces, process-wide eval lock); unbounded text buffers (64 KiB cap,
dropped on terminal events); `drain!` throwing on cursor expiry (resyncs and
reports dropped events); Ctrl-C throwing when the hub cannot answer; the
"final drain" after detach being a no-op; boolean flags consuming values;
`/quit` help promising survival while the CLI stops its in-process hub (now
warns and propagates a real exit code); console model resolution diverging
from run/resume; `:eval_start` sequenced after a fast result; `#uuid` ids;
bare lines for empty text; fixture-only `:scenario` accepted from any request.
Recorded, not fixed: finished sessions/runs/agent jobs are never pruned; reader
futures stay parked after quit (masked by process exit in the CLI).

## SCN-HUMAN-GATES (2026-09-08)

Human gates no longer read stdin under the console. The hub publishes each
`wait.human` question as a `:source :question` event with its options and
`timeout_seconds`; the console renders `[run id] ? text` with `[key] label`
lines and answers through `/answer <key or text>` (focused run first, or the
only waiting run). `/list` marks runs "waiting for an answer"; `--auto-approve`
now merely selects the first option. Evidence: `test/runner.lg attractor.hub-console-ops-test`
12 tests / 68 assertions and `test/runner.lg attractor.console-session-test` 7 / 73. This
closes the console's "cannot answer human gates" limitation and proves
ATTR-HUM-02 at the hub seam; the standalone stdin interviewer is unchanged.

## SCN-CONSOLE-INPUT

Status: implemented, focused/full/bundle verified; paired final audit clean.
Story: CONSOLE-INPUT-01. Seam: pure public reducer; this is
not evidence of a working CLI, evaluation, or streaming UI.

Feed line/interrupt/EOF events and supplied selection maps to
`attractor.console.input/accept`. Assert exact actions and payload preservation,
including code-looking literals, unknown commands, multiline character literals,
delimiter near misses, draft-only cancellation and selection changes before/after
submission. No models, shell processes or reader evaluation belong at this seam.

Command: `/Users/ndn/development/let-go/lg -source-paths src:test test/runner.lg attractor.console-input-test`.

## Baseline

Before console code: full local-lg `lgx test` completed with 679 tests,
6613 assertions and zero failures (session 71405, exit 0). This proves the
existing baseline only. tiny-tui compatibility evidence is in the design doc;
it does not satisfy CONSOLE-TUI-01.

## Current component evidence

- RED: missing namespace exit 1, then minimal stub 6 tests / 25 pass / 63 fail.
- Focused public reducer: 7 tests / 92 assertions / zero failures, independently
  rerun by main and reviewer. Scope/spec reviews approved by Codex and actual
  external Claude Code CLI (not an Attractor-managed Claude worker).
- Full suite: 686 tests / 6705 assertions / zero failures, exit 0. Exact baseline
  delta is the new 7 tests / 92 assertions; no existing source was modified.
- Standalone focused bundle outside checkout: 7/92/0, exit 0. CLI build/help exit 0.
- No full console command, RPC hub, terminal integration or worker connector is
  delivered by these results. Native-Go AOT remains separate from bundling.

Frontend adapter follow-ups: keep reducer state separate from UI/controller state;
deliver logical lines individually, not pasted multiline strings in one line
event. The current exact escaped-close rule cannot encode a literal backslash
followed by a closing delimiter as a standalone line; revisit framing ergonomics
before declaring unrestricted multiline REPL input complete.

Review adjudication: slash commands are the current frontend vocabulary, not an
exhaustive hub operation registry; revisit capability discovery with RPC design.
Interrupt/EOF intents deliberately differ from typed commands so the client can
apply presentation/disconnect policy before RPC dispatch. Draft discard is visible
as a state transition, not a worker cancellation event. Explicit human eval is
trusted native code; the reader contract is not narrowed by a reviewer suggestion
to disable native evaluation features. The safety boundary is never evaluating
model output or loaded data implicitly. The dev runner intentionally follows the
repository's explicit `run` argument convention; use the documented command.

---

## Console Input Routing

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

---

## Console Timeout

# Console Timeout — Plan & Runtime Request

## Timeout Resolution Plan

# Console timeout — ATTR-HUM-02 (resolved 2026-09-08)

Resolution: the standalone `ConsoleInterviewer` now reads from one owned line
source (`attractor.interviewer/start-line-source!`: a reader future feeding a
channel) and takes each answer with `alts!` against a timeout channel. This
satisfies the design review's constraints below without a runtime change:
there is no per-question reader to abandon, timed and untimed questions share
one reader and buffer, type-ahead across answered questions is preserved,
input arriving after a timeout is discarded before the next question, and EOF
yields SKIPPED. The stdin reader future stays parked until the process exits,
which the CLI accepts; embedded frontends pass their own line channel to
`make-console-interviewer`. Evidence is recorded in the Attractor requirements
ledger (`SCN-HUMAN-TIMEOUT`). nooga/let-go#822 remains a nicety, not a blocker.

The original discovery notes follow for history.

Source: vendored StrongDM Attractor spec §§6.2, 6.4–6.5. A question's
`timeout_seconds` bounds input waiting; use the complete `default` answer when
provided, otherwise return `:timeout`. Preserve existing question rendering and
answer selection. The handler's `human.default_choice` routing is already tested
with injected timeout answers, not native elapsed-time evidence.

Fresh public baseline `f9f7b30`: 644 tests / 5,970 assertions / zero failures.
Native PTY reproduction asked a freeform question with a 0.05-second timeout.
The process remained blocked after a one-second observation and returned only
after explicit input release, reporting 7,782 ms. The exact process was released
and exited zero; no reader/process was abandoned. This confirms the Attractor gap.

## Design review outcome

Do not implement a timed future around blocking `read-line`, or switch per question
between `read-line` and terminal key reads. The former leaves an active reader;
the latter has separate buffering and input binding. Inspection and native EOF
probes identified a runtime capability dependency, documented in
`console-timeout-runtime-request.md`. Filed upstream as
[nooga/let-go#822](https://github.com/nooga/let-go/issues/822), an enhancement rather
than a Clojure compatibility defect. No let-go runtime files have been modified.

The direct native file-deadline alternative was also checked without launching a
read: `(.SetReadDeadline (.File *in*) (.Add (now) 1000000))` returned
`file type does not support deadline` on an allocated PTY (and ordinary tool
stdin). Both probes exited zero; no input flags or blocked workers were retained.

Next design needs an EOF-aware, deadline-capable owned line-input seam. Keep
rendering and answer parsing separate from input outcomes (`:line`, `:timeout`,
`:eof`), but do not claim native completion from an injected adapter. Settle how
partial input is owned/discarded across timeout before implementation. Native
default input must preserve buffered consecutive lines and mixed timed/untimed
prompts; preserve the existing bound-input behavior.

## Required evidence once the input capability is available

- Real no-input timeout, complete default answer, and answer before deadline for
  each question type; no prompt/answer formatting regressions.
- Consecutive questions, mixed timed/untimed input, repeated timeouts then answer,
  and no stale reader consuming a later answer.
- Pipe and canonical TTY behavior, LF/CRLF, EOF with/without trailing newline,
  delayed UTF-8 fragments, and timeout during partial input.
- Explicit cleanup/cancellation without abandoned input workers or changing the
  terminal into raw mode as a hidden side effect.
- Public wait-human handler timeout/default routing and existing interviewer
  contracts, followed by full sentinel, standalone bundle and CLI verification.

ATTR-HUM-02 remains missing. This is a discovered dependency, not completion of
the console feature or a blocker for unrelated Attractor requirements. Continue
artifact discoverability while the runtime capability is being resolved.

---

## Runtime Enhancement Request

# let-go capability request: deadline-aware line input

This is an enhancement request, not a claim that Clojure `read-line` requires a
timeout argument. Attractor's ConsoleInterviewer needs a nonblocking, bounded
line read while keeping let-go as the implementation language.

## Observed on local let-go

The current `read-line` implementation in `pkg/rt/iort.go` calls the IOHandle's
buffered `ReadString('\n')`. It has no deadline/cancellation option and treats
all returned errors as EOF or partial-line completion. Wrapping that call in a
timed future does not cancel the underlying read: an abandoned reader can consume
a subsequent question's answer.

`term/key-pending?` and `term/read-key` are not equivalent line-input primitives:
they use `*keys*` and the native process-wide `keyBuf`, separate from `*in*` and
its buffered reader. Native readiness counts available bytes, not EOF readiness.
The key interface also handles synthetic terminal events.

Bounded reproduction (both commands exit normally):

```sh
printf '' | lg -e '(require (quote [term :as term])) (prn {:pending_at_eof (term/key-pending?) :read_at_eof (term/read-key)})'
printf 'first\nsecond\n' | lg -e '(require (quote [term :as term])) (dotimes [_ 13] (prn {:pending (term/key-pending?) :key (term/read-key)}))'
```

The first prints `{:pending_at_eof false, :read_at_eof nil}`. The second confirms
that consecutive lines are held by the key-source buffer, so switching back to
`read-line` is not a safe per-question timeout strategy.

## Requested capability

A native, EOF-aware deadline/cancellation-capable line reader available to let-go
code, with explicit line/EOF/timeout outcomes and real read errors preserved.
Timed and untimed operations must share input ownership and buffering, honor the
selected input handle (including `*in*`), and not leave a worker reading after a
timeout/cancellation result. No JVM-specific interface is requested.

Please define partial-line behavior across timeout, support canonical TTYs and
pipes, and retain LF/CRLF, final unterminated lines, and staggered UTF-8 bytes.
An owned reader object with explicit close/dispose may be preferable to changing
the established `read-line` return contract; API shape is left to let-go.

Proof should include repeated timeouts followed by an answer, mixed timed/untimed
reads, buffered consecutive lines, EOF, partial lines and split UTF-8/CRLF, plus
cancellation/cleanup with no stale reader consuming later input.

---

---

## Console Workers Design

# Combined console and external workers

Status: proposed design, not implemented. User requested an agent/workflow
console and let-go evaluation in the same console with different escaping.
This extends the project beyond the StrongDM conformance baseline; it does not
replace or satisfy outstanding Attractor requirements by itself.

## Delivery choice

The console is a client of an Attractor RPC hub, not the owner of the framework.
This incorporates the user's architectural correction: investigate let-go nREPL
as the transport before committing to another RPC protocol. The hub owns agent
sessions, workflows, external workers, evaluation namespaces and event streams.
The client owns terminal input, local draft buffers, selection and presentation.
Start with a streaming line client; add the full-screen TUI over the same RPC
client/control contract. A full TUI first would require
editing, terminal restoration, resizing and stream redraw to land together.
Separate agent and language REPL applications would be simpler but contradict
the requested single-console experience. A browser interface is not needed.

Proposed entry point: `attractor console`. Agent identity, run identity and worker
kind accompany streamed output, tool activity, errors and completion. Selection
changes do not relabel events already in flight. Let-go owns orchestration,
terminal rendering, subprocesses and internal `.edn` records.

Client disconnect is not implicit workflow cancellation or hub shutdown. Explicit
cancel/close requests target hub-owned identities. Define reconnect/event replay,
request IDs, subscription lifetimes and multiple-client behavior before claiming
reattachment works. Do not confuse an nREPL evaluation session with an Attractor
agent session; their identifiers and lifecycle responsibilities are distinct.

## Input contract

- Unprefixed input is a message to the selected agent.
- `/help`, `/agents`, `/focus`, `/run`, `/cancel`, `/quit` are control commands.
- `: <forms>` explicitly submits let-go code to a persistent console namespace;
  `:keyword` without the space remains ordinary agent text.
- A leading backslash strips exactly one character and forces literal agent text,
  whether or not the remainder looks like a command. Blank remainder is a no-op.
- `:{` on its own line enters multiline eval; `:}` on its own line submits it.
  Ctrl-C discards an unsubmitted buffer. Within the buffer, `\:}` appends a
  literal `:}` line instead of submitting. Nested `:{` is ordinary code text.
  These are console framing delimiters, not Clojure syntax. Preserve the native
  Clojure reader rather than inventing a restricted EDN language or second parser.
- Prefixes apply at column zero. Unknown slash commands fail explicitly rather
  than becoming prompts. Echo the selected route before execution.

Hub-side evaluation binds the selected session/run at submission time, exposes useful
inspection/control helpers, and keeps language values distinct from agent text.
Code evaluation is trusted local code with the user's authority, not a sandbox.
Never evaluate model output, restored transcripts or loaded `.edn` records.
One eval at a time; errors are rendered without terminating the console. Do not
promise hard interruption of arbitrary native calls without runtime evidence.

## Workers and usage

The hub uses Qwen through the existing unified-model path for bounded discovery and
implementation. Add Claude Code as an owned external coding-agent worker;
continue Codex app-server work as another external worker. A Claude Code worker
is not the Anthropic model adapter: it owns its own tool loop and CLI protocol.
Normalize worker lifecycle/events at the control boundary, not by pretending
every external agent is a single LLM completion call.

Worker configuration explicitly selects backend, model where applicable,
working directory, capabilities and limits. Fail visibly when a worker is
unavailable or unauthenticated; do not silently fall back to a different paid
provider. Do not assume quota or billing identity from executable presence.
Qwen availability and actual worker authentication need live verification.

To conserve Codex availability, prefer external Qwen/Claude tasks with bounded
inputs, named file ownership and mechanical acceptance commands. Reserve Codex
work for integration and difficult review, rather than adding Codex subagents
as a usage-distribution strategy. No automatic commits, pushes, permission
bypasses or new credentials are implied by worker selection.

## Runtime and validation

Use [tiny-tui](https://github.com/abogoyavlensky/tiny-tui) as the preferred TUI
foundation, per the user's suggestion. It is implemented for let-go, integrates
through `lgx.edn`, and provides input, selection, layout/style, terminal cleanup
and scripted-input/headless test seams. Observed tag `v0.1.3` resolves to
`3d2aeaa68e4647187c10cbbcba7df881b81b9a6c`; validate and pin the chosen dependency
before integration rather than following an unpinned branch. Compatibility
evidence: all 202 upstream tests / 410 assertions pass with the local let-go;
the same 202/410 pass from a standalone bundle launched outside the checkout.
The upstream fixed `/tmp` test fixture was relocated inside our uniquely
allocated directory for repeated/bundled runs. This proves current headless
library/bundle compatibility, not native-Go AOT parity or the combined console.
Native PTY smoke: the upstream counter renders, arrow-up changes count to 1,
and `q` exits with `Final count: 1`, cursor/main-screen restoration sequences and
process exit 0. A strict `stty -g` equality check initially failed only because
macOS sets `PENDIN` (`0x20000000`) when returning from raw mode. A no-library
`stty raw; stty <saved-state>` control produces the identical change, while
ordinary shell input does not. This is not evidence of a let-go/library bug;
all other observed terminal fields match. Resize/Ctrl-C/exception native cases
and combined input/stream behavior still need their own acceptance tests.

The inspected `tiny-tui.core/run` loop waits for keyboard messages and treats
Ctrl-C as program exit before calling the app update function. Our streaming
console needs an event source that merges worker events with keys, and routes
Ctrl-C according to input/eval/run state. Reuse the library's widgets/rendering
and terminal lifecycle with a small app-owned adapter; do not assume the stock
blocking loop already provides multi-agent streaming or multiline REPL behavior.
No upstream library edits or replacement toolkit are selected at this stage.

Reuse let-go nREPL facilities after capability checks. The existing runtime guide
documents clone/close/eval/load-file/describe/completions/interrupt operations;
that is not evidence of extensible Attractor operations, reconnectable event
subscriptions, authentication or safe remote exposure. Inspect these capabilities
before selecting nREPL for the entire hub. Prefer explicit framework operations
over encoding every control request as arbitrary evaluated source. Keep trusted
evaluation distinct from ordinary control permissions. Initially local-only;
do not expose an arbitrary-code-evaluation endpoint to the LAN by default.

The TUI owns
one input source and restores terminal state on exit/error. Do not put a future
timeout around blocking `read-line`, or mix competing buffered/key readers.
Noninteractive transcript tests exercise the same command dispatcher and control
layer; native PTY tests must cover EOF, Ctrl-C, resize and terminal restoration.
Client exit restores the terminal and closes its connection/subscriptions, not
the hub or its independently running workflows. Hub shutdown has separate tests.

Mechanical tests must prove prefix/literal/multiline routing; namespace
persistence; no implicit evaluation; session selection captured at submission;
interleaved worker event identity; worker failure/cancel/exit; and regression-free
workflow launch and pinned recovery. CLI-worker protocol fixtures must be let-go.
Live Qwen and Claude trials are separate evidence from deterministic fixtures.

## External design review

An actual Claude Code read-only print/stream-json trial returned a critique with
exit 0 after network approval; the initial sandboxed attempt failed DNS and
terminated. This proves this bounded CLI invocation worked, not a completed
connector, subscription accounting, bidirectional protocol or cancellation.

Accepted findings: exact input routing rules, visibly identified output with
per-session line buffering, and cancellation/control processing independent of
blocked input. Keep selection and identity in the control API from the start;
Claude's suggestion to omit selection entirely is only appropriate to a first
single-worker UI milestone, not a reason to remove the requested multi-worker
design. Bind selected objects at submission, rather than allowing a later focus
change to retarget an in-flight eval. Loading EDN remains data reading, not
implicit execution; an explicit human eval can of course execute user code.

## Sequence

1. Finish and review the isolated subagent lifecycle ownership fix.
2. Review this design and pin the console command/evaluation contract.
3. Validate nREPL as a hub transport, then build the line client with hub-side
   let-go eval and Qwen worker selection. Define disconnect/reconnect ownership.
4. Add and exercise the owned Claude Code worker with permission/error handling.
5. Add full-screen presentation, retaining the transcript frontend for tests and
   non-TTY use; continue Codex app-server integration without claiming existing
   framing work is a complete connector.

The first useful milestone is a console connected to a hub that can message Qwen,
inspect the session through explicit let-go evaluation, stream identified events,
and disconnect without accidentally terminating hub-owned work. Explicit run
cancellation remains available. Full TUI and multi-worker parity remain later work.

---
