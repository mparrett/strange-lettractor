# Tool Features — Consolidated

## Tool Call Repair

# Tool-call argument repair

The high-level `generate` and `stream` APIs accept `:repair_tool_call` in their
options. This implements unified LLM specification §5.8 for active tools.

```clojure
{:repair_tool_call
 (fn [original-call validation-error]
   ;; Return a complete call with corrected :arguments, or nil to decline.
   ;; Both parsed maps and JSON strings are accepted as arguments.
   (assoc original-call :arguments {"x" 2}))}
```

The callback receives the original tool call and the exception from JSON parsing
or schema validation. It runs once per invalid call. Its result must preserve
the original ID and tool name, and its arguments must pass the same validation
as the initial call. A nil result, thrown exception, malformed call, changed
identity or invalid repaired arguments becomes a tool error returned to the model.
There is no recursive repair loop. Unknown tools and tool execution exceptions
produce ordinary tool errors without calling the repair callback.

Repairs run within the same bounded concurrent dispatch and owned cancellation
scope as tool execution. Results preserve the original model call order and IDs.
Cancellation is checked before repair, after it returns and before execution;
a callback that signals an abort cannot cause the repaired tool to execute or
another model round to start. As with other custom callbacks, noncooperative work
that ignores cancellation cannot be forcibly interrupted by the Lisp layer.
The callback itself is not forwarded to provider adapters or middleware.

The two-argument callback signature and identity restriction are local API choices;
§5.8 requires repair behavior but does not prescribe a callback signature.

Evidence: `make run-tool_repair`, 6 tests / 128 assertions. Covers both high-level
APIs, invalid JSON/schema, failed repair cases, untouched valid/unknown/executor
failures, overlapping repairs, ordered continuation messages and abort during
repair. The initial four regressions failed 30 assertions before implementation.
Existing LLM contracts pass 83/495 and cancellation ownership passes 9/35.
Final full suite: 937 tests / 8991 assertions / zero failures.

---

## Tool Choice Capability Audit

# Tool-choice capability audit

Unified LLM section 5.3 requires capability inspection and rejection when an
adapter does not support a requested tool-choice mode. `make-adapter` accepted
`:supports_tool_choice`, but the client never invoked it; native adapters also
left that field empty.

Native protocol adapters now advertise support for `auto`, `none`, `required`,
and `named`, with an optional configured predicate override. Client completion
and streaming check the selected adapter's predicate after middleware changes
have been applied. Rejection raises non-retryable `:unsupported-tool-choice`
before invoking the adapter. Custom adapters without a capability predicate
retain their existing behavior.

`tool_choice_capability_contract_test.lg` verifies unsupported choices never
reach an adapter, supported choices are delivered intact, and native adapters
expose their modes. Eight assertions failed before the fix; three tests and ten
assertions pass afterward. Existing LLM tests (83/495), middleware routing tests
(4/6), and the build also pass.

The adjacent definition-time audit found that `make-tool` already validates
identifier syntax, the 64-character limit, and an object-root parameter schema.
This does not establish validation for callers bypassing that constructor with
arbitrary maps, nor a complete live tool-choice matrix.

## Required name for named choices

The shared tool-choice reader now rejects `named` choices whose `tool_name`
is missing, non-string, empty, or whitespace-only. Previously those requests
could reach an adapter with a null or unusable tool name. The error is
non-retryable `:invalid-request`, and validation runs before client dispatch
even when a custom adapter has no capability predicate. Keyword-key and
string-key choice maps remain supported.

Two additional tests exercise completion and streaming rejection plus an intact
valid string-key choice. Sixteen assertions failed before the repair; the
namespace now passes five tests/27 assertions. Existing LLM tests (83/495),
middleware routing tests (4/6), and build pass. These checks validate the
required field, not whether the name matches a declared tool.

---

## Tool Hooks

# Tool Hooks — Plan & Implementation

## Implementation Plan

# Tool-call hooks — scoped implementation plan

Status: implemented and verified for ATTR-HOOK-01. The broader iteration and full
Attractor goal remain incomplete.

Source: snapshotted Attractor specification §9.7. This implements ATTR-HOOK-01
and SCN-TOOL-HOOKS within ITER-0007, not completion of that iteration.

## Contract

- Resolve `tool_hooks.pre` and `tool_hooks.post` independently, node attribute
  presence overriding graph defaults. An explicitly empty value disables that hook.
- The codergen handler passes resolved hooks and the current stage directory to
  the agent backend. Refresh this invocation context on every turn, including
  cached full-fidelity sessions. Standalone sessions may supply equivalent options.
- Run pre before each requested tool call, including invalid or unknown calls.
  Nonzero exit, timeout, or execution failure vetoes executor invocation and gives
  the model a bounded error result. Successful pre leaves normal validation intact.
- Run post after each attempted call, including tool errors and pre-veto results,
  so auditing sees every outcome. Post failure never replaces the tool result.
  Cancellation takes precedence: do not launch additional hooks or executors after
  cancellation, and retain existing owned-process cleanup guarantees.
- Hook commands execute through the session execution environment, with a bounded
  default timeout and its normal cwd, environment policy and cancellation handling.
  Do not introduce an unowned shell runner or handwritten Go fixture.
- Add optional `:exec_command_stdin` (command, timeout, cwd, env, input) without
  changing the existing four-argument operation. Local implementation writes input
  to an exclusively created private temporary file, invokes the existing owned
  command runner with safely quoted file redirection, then removes only that file
  and its empty private directory in `finally`. Raw input never enters argv or
  shell evaluation. Custom environments without this capability remain compatible
  when hooks are absent; configured hooks report unsupported capability (pre veto,
  post diagnostic), never silently bypass it. Test multi-MiB input and cleanup.
- Supply JSON on stdin: phase, node/session/call identity, tool name, arguments;
  post additionally receives the raw result and error/skipped flags. Supply compact
  identity metadata as `ATTRACTOR_HOOK_PHASE`, `ATTRACTOR_NODE_ID`,
  `ATTRACTOR_SESSION_ID`, `ATTRACTOR_TOOL_CALL_ID`, `ATTRACTOR_TOOL_NAME`.
  The exact names/schema are this implementation's contract, not specified upstream.
- Preserve literal JSON string keys and shell-sensitive payload text. Work around
  let-go #817 narrowly without lossy keyword conversion. Do not evaluate EDN.
- Append hook outcomes and failures as EDN forms to the stage's `tool-hooks.edn`.
  Keep model-facing tool output bounded and existing start/end events single and
  ordered. Explicitly test logging failures rather than silently swallowing them.
- Serialize in-process stage-log appends under a shared writer lock so parallel descendants
  cannot interleave or lose EDN forms. If a configured pre-hook's required log
  cannot be persisted, veto the executor and emit a hook diagnostic event. A post
  log-write failure emits a diagnostic but preserves the original tool result.
  Standalone sessions without a stage directory use diagnostic events only.
- Descendant coding-agent sessions inherit hooks and stage context; refreshing a
  reused parent must not leave active descendants with stale invocation context.
  Inspect existing ownership/lifetime semantics before choosing the smallest fix.
- Share a refreshable invocation-context cell with descendants, but snapshot its
  immutable value once at each tool-call entry. That snapshot owns the full
  pre/executor/post sequence and log destination. Refresh affects subsequent calls
  only; prove this with a gated active-descendant call across a parent refresh.
- Workflow integration resolves attributes from graph/node `:attrs` and supplies
  a namespaced invocation overlay to the unchanged backend signature. Recompute
  each invocation from backend defaults plus this overlay, never the previous
  stage's effective settings. Do not persist mutable cells in captured workflows.
- Couple cached-session context refresh to successful input admission under the
  existing lifecycle lock. A concurrent rejected caller must not refresh hooks,
  close/evict the active session, or cancel a turn it never admitted. Prove this
  alongside sequential fidelity reuse and captured-workflow recovery.

## Tasks and mechanical evidence

1. Sentinel baseline passed: 609 tests / 5,679 assertions / zero failures, exit 0
   at c373771. Paired independent scope review of this contract.
2. TDD hook execution and serialization at the real session seam: success, veto,
   thrown/invalid/unknown tool, post failure, bounded errors, exact raw stdin,
   native shell quoting, timeout/cancellation and process cleanup.
3. TDD public workflow wiring: graph defaults, independent overrides, explicit
   disable, fidelity reuse and descendant inheritance. Read actual stage EDN logs
   and compare executor counts and next model requests; no model judge.
4. Paired spec then quality review. Run impacted scenarios and full sentinel suite
   with source frozen; build/bundle smoke checks (not native AOT conformance).
5. Record evidence and update requirement/scenario/corpus/progress artifacts, commit
   scoped files, fast-forward and push public main after verification.

RLM discovery, skill packaging, native HTTP cancellation and broad provider parity
remain separate work. Private `docs/notes.md` must remain untouched.

## Verified transport checkpoint

The optional local environment operation is implemented in `execution.lg`.
`execution_stdin_test.lg` proves SCN-TOOL-HOOKS-STDIN at the native command seam.
Inputs must be strings; existing four-argument execution callers are unchanged.
Cleanup exceptions include `:stdin_cleanup` with exact owned paths and failures.
When a command returned, cleanup failures also retain its complete `:command_result`.
When it threw, its message/category/data are retained, but exception identity is
not preserved if cleanup also fails. Both removal operations are attempted.

Mechanical evidence (local let-go compiler, candidate based on `c373771`):

- Initial RED: 2 passing assertions / 1 failing assertion (missing capability).
- Expanded cleanup/input RED: 51 passing / 2 failing assertions.
- Review regression RED: 62 passing / 7 failing assertions.
- Final focused: 7 tests / 74 assertions / zero failures.
- Impacted execution tests: 36 tests / 185 assertions / zero failures.
- Full default suite: 616 tests / 5,753 assertions / zero failures, exit 0.
- Standalone bundle executed outside the repository: 7 / 74 / zero failures.
- `lgx build` and built CLI `help`: exit 0. This is not native-Go AOT conformance.
- Paired independent scope, spec and quality reviews approved the component.

Focused reproduction:

```sh
/Users/ndn/development/let-go/lg -source-paths src:test test/runner.lg attractor.execution-stdin-test
```

For standalone verification, compile that runner with `-b <output>` and execute
`<output> run`. The argument is required by the runner's command-line entry guard;
an argument-free zero exit with no counters is not test evidence.

The deliberately failing cleanup reproducers left two empty random temporary
directories whose paths were not retained. Their payloads were removed. No broad
cleanup was attempted; the regression now captures owned paths for exact cleanup.
This component creates no new upstream let-go issue and does not complete hooks.

## Standalone hook checkpoint (before workflow integration)

The agent accepts `:tool_hooks` with `:pre`, `:post`, `:node_id`, `:stage_dir`
and optional positive `:timeout_ms` (default 10000). Descendants share the session's
`:tool_hook_context` cell. Each call snapshots the context before its start event.
The external JSON payload uses `phase`, `node_id`, `session_id`, `call_id`,
`tool_name`, `arguments`, plus post-only `result`, `is_error`, and `skipped`.
Arguments retain their provider representation (object or JSON text); result is
the raw executor value before model-output truncation.

Hook outcomes emit `:tool_hook` events; audit-write failures emit
`:tool_hook_error`. No stage directory means events only. Cancellation is distinct
from timeout and aborts the session, including cancellation flags retained inside
a command-cleanup exception. The append lock coordinates this process's writers,
not independent processes sharing a file.

Focused evidence: initial RED 2 tests / 4 pass / 11 fail; final 12 tests / 85
assertions / zero failures. Impacted agent, loop, truncation and session-error
checks: 64 tests / 654 assertions / zero failures. Native shell, actual EDN forms,
eight concurrent sessions, timeouts and running-hook cancellation are included.
Run `/Users/ndn/development/let-go/lg -source-paths src:test test/runner.lg attractor.tool-hook-test`.
The test count includes the final native-cancellation test; a development syntax
error briefly triggered known let-go #807 silent trailing-form truncation and was
corrected before these counts. Workflow inheritance, admission and recovery are
not established by these standalone tests.

## Public workflow integration checkpoint

Graph/node attribute resolution, dynamic defaults, full-fidelity refresh,
descendant pinning across refresh, rejected-call isolation, pending cancellation,
parallel stage separation, hook-reported cancellation and captured resume are
verified in `tool_hook_workflow_test.lg`: 11 tests / 47 assertions. The direct
handler cancellation regression failed with a status-codec error before the fix;
cancelled outcomes now bypass that incompatible status-file format. Admission
cancellation evidence waits for the actual successful CAS before releasing its
gate, not merely evaluation of the cancellation predicate.

Combined focused and standalone bundled hooks: 23 tests / 132 assertions.
Impacted agent/engine/status/recovery: 203 / 1579. Final full suite: 639 / 5885.
All report zero failures and exit 0. CLI build/help pass. Paired spec and quality
reviews approve. See [tool-hooks.md](tool-features.md) for usage.

A separately reproduced preexisting completion-handoff cancellation race is
tracked in [turn-ownership-gap.md](turn-ownership.md), CAL-OWN-01. It is not
closed by the rejected/pending admission guard or these hook evidence counts.

---

## Implementation Reference

# Tool-call hooks

Attractor specification §9.7 defines shell hooks around LLM tool calls. Configure
them as graph defaults or node attributes:

```dot
digraph example {
  graph [tool_hooks.pre="true", tool_hooks.post="true"]
  start [shape=Mdiamond]
  work [prompt="Inspect the project"]
  no_pre_check [prompt="Summarize findings", tool_hooks.pre=""]
  exit [shape=Msquare]
  start -> work -> no_pre_check -> exit
}
```

Replace `true` with your hook commands. Each node overrides the corresponding
graph hook independently; an empty value disables that phase. Without a DOT
override, backend-configured defaults still apply. Hook commands use the agent's
execution environment and working directory, not the stage-log directory. Hooks
are executable workflow code, not a security sandbox.

Pre exit zero permits normal tool validation/execution. Nonzero exit, timeout,
execution error, unsupported stdin capability or a required audit-write failure
skips the tool and returns a bounded error to the model. Post observes every
attempted call, including errors and vetoes; its failure cannot replace the tool
result. Cancellation stops further work instead of acting as an ordinary veto.

## Hook input and audit output

Each hook receives these environment variables:

- `ATTRACTOR_HOOK_PHASE` (`pre` or `post`)
- `ATTRACTOR_NODE_ID`
- `ATTRACTOR_SESSION_ID`
- `ATTRACTOR_TOOL_CALL_ID`
- `ATTRACTOR_TOOL_NAME`

Stdin is external-protocol JSON with `phase`, `node_id`, `session_id`, `call_id`,
`tool_name`, and `arguments`. Arguments preserve their provider representation:
either an object or JSON text. Post also receives `result`, `is_error`, and
`skipped`. Result is the raw executor value, before model-output truncation.
Literal string keys are preserved, including empty and slash-containing keys.

Audit records are appended as EDN forms to `<stage-dir>/tool-hooks.edn`. They
contain call identity, phase, hook status and command result, including exit code
and output. Failures also produce hook diagnostic events. The append lock protects
concurrent writers in this process, not separate processes sharing one log file.
Standalone sessions without a stage directory emit events without a stage file.

## Session options

Standalone sessions and backend defaults accept:

```clojure
{:tool_hooks {:pre "true"
              :post "true"
              :timeout_ms 10000}}
```

`timeout_ms` defaults to 10000 and remains subject to the execution environment's
maximum command timeout. Standalone callers can also supply `:node_id` and an
existing `:stage_dir`. Custom environments need the optional five-argument
`:exec_command_stdin` operation `(command timeout cwd env input)` for hooks;
ordinary four-argument command execution is unchanged.

Reused sessions refresh hooks only when the next input is admitted. Descendants
share the refreshable context, but each tool call pins one context for its full
pre/tool/post sequence. A busy rejected caller cannot reconfigure or cancel the
active session. Pinned recovery resolves hooks from captured workflow attributes,
not subsequently edited DOT source.

For mechanical tests and explicit evidence boundaries, see
[the implementation plan](tool-features.md).

---

---
