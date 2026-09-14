# Runtime Specification Audits — Consolidated

## Build Audit

# Pinned runtime build audit

The former README cloned a moving fork branch and built it without applying
Attractor's additional runtime patches. A fresh clone at
[`46244c4fa8169b8138aa1c29f31c8a6102ed1755`](https://github.com/nnunley/let-go/commit/46244c4fa8169b8138aa1c29f31c8a6102ed1755)
reproduced both missing capabilities: `net/listen` was unavailable and writing
then reading `{"key" "value"}` through JSON did not preserve the map.

The README now pins that revision and applies both tracked patches before
building. Both patches pass `git apply --check` on the fresh checkout:

| Patch | SHA-256 |
| --- | --- |
| `runtime-patches/net-listener.patch` | `5cc6f3dc98a079026f4afe301a92959b1ba1cd00a9adfd41071cc3129a62abc1` |
| `runtime-patches/json-string-keys.patch` | `8e050ce6ad550cb4c4d58d5c94618fb1c9af32caee85e405b4b236ec626978f2` |

The checkout was built using Go 1.26.5 on darwin/arm64. Runtime tests pass with
`go test ./pkg/rt -run 'Test(Net|Bencode|JSONObjectKeysPreserveStringContents)' -count=1`.
The native `test/probes/net_listener_check.lg run` probe also passes its eleven
checks: ephemeral port binding, bind failure, two clients, coalesced and
fragmented frames, bidirectional bencode, listener and read wakeups, idempotent
close, accepted-connection lifetime, and invalid arguments.

Attractor verification against the new executable:

- `make test LGX_LG=<fresh-checkout>/build/lg`: 1145 tests, 10284 assertions,
  zero failures, exit 0. Log: `/tmp/attractor-pinned-runtime-suite.log`.
- `make build LGX_LG=<fresh-checkout>/build/lg`: exit 0.
  Log: `/tmp/attractor-pinned-runtime-build.log`.
- `test/probes/nrepl_hub_check.lg run`, using the fresh runtime and newly built
  Attractor executable: all ten checks pass, covering shared sessions, two
  clients, disconnect survival, reconnect results, event replay, remote console
  and evaluation, compiled-console attachment, HTTP-peer closure, and cleanup.

The verification checkout was `/tmp/attractor-runtime-check.rAT0iN/let-go`;
the README uses `.worktrees/let-go-pinned` so normal builds can reuse their
runtime. The existing local runtime and environment configuration were not
replaced. These results establish the documented supported build independently
of the older ignored source snapshot.

This establishes a reproducible fork-plus-patches recipe, distinct from upstream
release availability. As checked on 2026-09-12, the latest published upstream
release is [v1.12.2](https://github.com/nooga/let-go/releases/tag/v1.12.2) from July 20.
PRs [#848](https://github.com/nooga/let-go/pull/848),
[#849](https://github.com/nooga/let-go/pull/849),
[#850](https://github.com/nooga/let-go/pull/850),
[#851](https://github.com/nooga/let-go/pull/851),
[#852](https://github.com/nooga/let-go/pull/852),
[#853](https://github.com/nooga/let-go/pull/853),
[#854](https://github.com/nooga/let-go/pull/854), and
[#855](https://github.com/nooga/let-go/pull/855) have merged since that release;
HTTP-timeout PR [#856](https://github.com/nooga/let-go/pull/856) remains open.
No stock-release compatibility claim follows from those merge statuses.

---

## Condition Audit

# Condition audit — 2026-09-12

Scope: pinned Attractor §§10.2–10.5 and §11.9. This remains a partial audit.

| Checklist requirement | Evidence/finding |
|---|---|
| String equality | Existing outcome/context tests plus new exact-string regression. Fixed trimming of resolved values and quoted literal contents. |
| Inequality | Outcome inequality and new padded-string regression exercise inverse comparison. |
| AND clauses | Shared clause scanner splits only outside quoted strings and respects escapes. Evaluation uses `every?` for left-to-right short-circuiting after syntax parsing. Public pipeline regression routes on a quoted `&&` literal. |
| Outcome variable | Existing tests cover keyword success/fail and direct source inspection covers string-keyed outcomes. |
| Preferred label | Existing Yes-label test and new case-sensitive Go/go test. |
| Missing context values | Regressions check missing versus empty/space and qualified-nil fallback. Non-nil false/empty qualified values retain precedence. |
| Empty condition | Existing test accepts empty input independently of outcome. |

## Fixed exact comparison

`evaluate-clause` trimmed both resolved values and parsed literals. Thus a context
value `" ready "` matched the unquoted literal `ready`, and a missing key matched
`" "`. §10.3 requires exact case-sensitive comparison. Clause/literal syntax is
still trimmed, but data values and quoted contents now retain their whitespace.
Quoted literal contents also use the existing DOT string escape decoder, as
§10.5 requires, instead of retaining literal backslash sequences.

Five regression assertions failed before the fix. Conditions now pass 2/26/0;
parity 25/61/0 and engine 46/209/0 also pass. The regression covers padding,
inequality, newline/tab/quote/backslash escapes, missing/empty values, and case.

## Quoted syntax and fallback follow-up

The scanner now recognizes conjunctions outside strings, including escaped
quotes/backslashes. Validation and evaluation share clause parsing and literal
validation. Operator characters inside a quoted literal stay data; malformed
quoting, unsupported operators, invalid keys, and trailing literal text are
rejected. Thirteen assertions failed before these corrections and the nil
fallback change.

Qualified lookup now consults the unqualified spelling when its value is nil,
as §10.4 specifies. False and empty strings do not trigger fallback. Both string
and keyword-keyed maps are covered.

The public pipeline regression parses DOT, validates it, and executes conditional
branching: a value containing `&&` selects its matching branch and excludes the
higher-weight inequality branch. Conditions pass 6/52/0; parity 25/61/0,
lifecycle 8/162/0 and engine 46/209/0 also pass. Native build succeeds.

Compatibility: direct unqualified keys and bare-key truthiness remain supported
as in the existing implementation and §10.5 pseudocode, although the narrower
§10.2 grammar lists only comparisons. Empty clauses also retain the pseudocode's
skip behavior. These compatibility forms do not add new comparison operators.

---

## Execution Audit

# Runtime execution audit — 2026-09-12

This audit compares the original Attractor spec's execution and handler contracts
with current code and tests. It is one part of the completion audit, not a
full-spec certificate.

| Contract | Inspected evidence | Finding |
|---|---|---|
| §11.3 start, traversal, dispatch, terminal outcome | `engine_test.lg`, `parity_test.lg`, `handler_matrix_contract_test.lg`; engine dispatch and stage status writing | Existing execution and handler-matrix coverage; fresh engine run passes 46/209 after the fix below. |
| §11.4 goal-gate enforcement | `test-goal-gate-enforcement`, parity cases 10/11 and resume gate outcomes | Existing success, retry-target and failed-exit evidence. No new defect identified in this inspection. |
| §11.5 retry limits/backoff/jitter | Engine policy construction and delay calculation; `test-pipeline-retry-policy-controls-backoff-without-real-sleep`, named policy limits and jitter test | Existing executable checks. Returned FAIL follows the documented project interpretation of normative §§3.5/3.7, rather than the contradictory checklist wording; `fail_retry_contract_test.lg` records it. |
| §4.11 manager child execution with §3.1 lifecycle and §8 stylesheet | `make-child-runtime`, manager handler and real-child tests | Defect found: child source was parsed and executed without transforms or validation. Fixed and verified below. |
| §2.7 loop restart with §9.5 HTTP checkpoint/context inspection | `hub_workflow_inspection_test.lg`, `pipeline` restart publication callback, hub checkpoint operation | Defect found: hub retained the first segment's log root and manifest, so HTTP read an obsolete checkpoint after restart. Fixed for both fresh and resumed workflows. |

The manager regression uses a real child DOT file and default runtime. Before the
fix, a valid child's `llm_model` stylesheet selection was missing, and a child
without an exit node executed its work handler and let the parent succeed. Three
assertions failed. The manager now applies built-in transforms and raises on
validation errors before creating the child runtime or launching its worker.

Verification:

- `make run-engine`: 46 tests, 209 assertions, zero failures.
- `make build`: successful native CLI build.
- Full suite passes. After removing the fixed test-count assertion at the user's
  request, the engine tests and final-form reader guard also pass in a focused run.
- Compiled CLI, real-file parent and child: valid child exits zero, its prompt
  contains the expanded `Do ChildGoal`, and its checkpoint exists. Invalid child
  exits one and creates no work-stage prompt. Model execution was mocked.
- Probe artifacts: `/var/folders/vk/rkcd0mjn591_03z0856412gh0000gn/T/attractor-manager-audit-xwy7kgl5/`.

This does not establish captured-bundle recovery for manager child source,
inheritance of caller custom transforms into manager children, live model quality,
or completion of the other two specifications. The full completion audit remains
open. Story status alone missed this cross-feature defect.

## Restart inspection follow-up

The new regression runs a real workflow through a restart edge and holds its
second segment at a human gate. Before the fix, hub inspection returned the old
log root and manifest, and checkpoint lookup returned the previous segment's
context. Three assertions failed. The pipeline now provides a wrapper-only
`:on-restarted` observer after publishing the captured bundle in the new root.
The hub verifies publication and the existing workflow fingerprint, then updates
the active log root and manifest under its event lock. Event payloads alone do
not redirect filesystem reads. Both fresh execution and checkpoint resume use
this observer.

Evidence: hub inspection 3/34/0; loop restart contracts 10/198/0; workflow recovery
contracts 52/481/0; CLI 6/57/0. The regression checks the actual checkpoint's
second-segment context while the run is still active, including a resumed run
that immediately crosses a restart edge. These are component/integration tests;
the restart-specific case has not been repeated over HTTP sockets.

---

## Human Interaction Audit

# Human interaction audit

Audited 2026-09-12 against the pinned Attractor specification §§6.1–6.5,
11.8 and human-gate routing in §4.6.

| Contract | Current evidence |
| --- | --- |
| ask, ask_multiple, inform | interviewer_contract_test: complete questions and answers, ordered batches, inform delegation |
| Four question types and option metadata | AutoApprove and console contract cases cover binary, confirmation, freeform and multiple choice |
| AutoApprove | YES for binary questions, first complete option, fallback auto-approved text |
| Console prompt and input | Exact prompt/answer tests plus compiled CLI pseudo-terminal probe |
| Callback | Complete question delivery, unchanged answer and exception propagation |
| Queue | Ordered answer maps, exhausted SKIPPED, overlapping claims and actual parallel human gates |
| Recording | Complete ordered question/answer pairs; only successful answers recorded; inform delegated |
| Timeout | Console timer tests cover default and TIMEOUT; hub tests and terminal probe cover human.default_choice routing |
| Human gate | Real pipelines persist selected route/label; accelerator grammar, no choices, unmatched answers, skipped and timeout outcomes tested |

Two defects corrected during this audit:

* Queue exhaustion previously selected Question.default. Section 6.4 explicitly
  returns SKIPPED; the queue now follows that contract even when a default exists.
* The CLI submitted its local timeout as text after the hub could already have
  expired the question, crashing with unknown-question. Local TIMEOUT is no
  longer submitted, and an answer rejected because its question expired is
  ignored. Other submission errors still propagate. The CLI regression holds
  stdin until the real hub-backed pipeline completes through its default, then
  releases both a TIMEOUT and a late typed answer in separate cases.

Current focused results: interviewer-contract 14 tests/120 assertions;
interviewer-queue 4/23; console-interviewer-timeout 3/11; hub-console-ops 13/85;
CLI 7/61. All pass. The compiled binary builds, and
`test/probes/human_timeout_pty_check.lg run` passes 3 tests/12 assertions.

The terminal probe preserves startup time before EOF and synchronizes stale
input with the first timeout during an intervening tool stage. This proves
discarding input buffered between questions. It cannot prove which question a
person intended when untagged input arrives after the next prompt opens.

Follow-up: CLI conversion of SKIPPED to text did lose EOF/skip semantics,
causing the first edge to execute. The hub now accepts a complete typed
`:answer` map alongside its existing text-only form. The CLI sends that map;
its EOF regression uses a real closed input channel and hub-backed pipeline,
requiring failure without starting the outgoing target. Typed nREPL cases
cover all AnswerValue enums, freeform text and complete selected-option maps;
invalid answers leave the question pending. Existing HTTP text answers pass.
Updated focused results: CLI 8/63, nREPL hub 5/112, hub console operations
13/85 and hub HTTP 6/72, all passing. The rebuilt CLI also passes the expanded
pseudo-terminal probe (4 tests/15 assertions), including EOF with a configured
default: neither outgoing target starts and the command exits with failure.
Integrated verification after these changes: `make test` exits zero with
1051 tests, 9724 assertions and zero failures; output is captured in
`/tmp/attractor-shared-transport-suite.log`. This verifies the current patched
runtime and worktree, not upstream release-runtime or whole-spec completion.

---

## Integration Audit

# Runtime integration audit

Audited 2026-09-12 against pinned Attractor §§11.11–11.13.

Transforms (§11.11): `lifecycle_contract_test` proves built-in expansion and
stylesheet transforms precede custom transforms, custom transforms run in order,
and validation sees the final graph before any handler starts. Fresh run: 8
tests/162 assertions, passing. The HTTP route names in §11.11 differ from the
specific §9.5 API; this implementation follows `/pipelines` and run-ID routes,
whose shared-hub evidence is documented in `shared-http-adapter.md`.

Cross-feature matrix (§11.12): the numbered tests in `parity_test.lg` map to all
22 matrix rows. Parsing/validation rows 1–6 check structure, attributes and
diagnostic severity; execution rows 7–16 exercise traversal, retries, gates,
selection priorities and context handoff. Row 17 now actually interrupts and
resumes, comparing against uninterrupted execution; it found and fixed lost
context logs. Rows 18–19 check resolved model and expanded prompt. The direct
fan-in test for row 20 is supplemented by the real parallel-pipeline case.
Rows 21–22 execute a custom handler and a twelve-node pipeline.

Two normative discrepancies remain explicit: reachability is an error under
§7.2 despite the matrix saying warning; returned FAIL routing follows §§3.5/3.7
as recorded in `fail_retry_contract_test.lg`, while retryable RETRY outcomes
exercise the configured retry count. Fresh parity result: 25 tests/75
assertions, passing. This does not elevate a single tested branch or outcome
to proof of all possible cross-feature combinations.

Smoke (§11.13): `smoke_test.lg` passes 1 test/24 assertions with deterministic
responses. `test/live/attractor_smoke.lg` uses the real agent backend for the
plan/implement/review pipeline and checks routing, nonempty responses, stage
status files, final checkpoint and events. It now retains run artifacts and
an EDN result under `evidence/runtime-smoke-evidence/`, while deleting only the
model's temporary working directory.

Fresh local-model verification passes 1 test/20 assertions against the configured
`llamacpp/qwen3.8-27b` provider. Environment overrides were unset, but the native
provider registry supplied the endpoint; absence of overrides is not absence
of configuration. The initial sandbox DNS failure is recorded separately from
the successful network-enabled run. The successful evidence is
result.edn (local output: `evidence/runtime-smoke-evidence/llamacpp-qwen3.8-27b-1789239367502/result.edn`),
with complete stage artifacts and checkpoint in its sibling `logs/` directory.
The implementation response contains the hello-world source and review confirms
it. This establishes the runtime's real-LLM smoke journey; it does not establish
the other specifications' provider matrices or intended-runtime compatibility.

---

## Parsing & Validation Audit

# Parsing and validation audit — 2026-09-12

Scope: pinned Attractor §§11.1, 11.2, 11.10. Evidence below was read from source
and test bodies, then the relevant suites were run. This covers these checklist
sections at the parser/validation/preparation seam, not full runtime completion.

| Checklist item | Inspected evidence and finding |
|---|---|
| 11.1 attribute blocks | Parser linear/chaining tests and parity cases 1–3 exercise graph, node and edge blocks. |
| 11.1 graph goal/label/stylesheet | Parity cases 2/18 and lifecycle preparation test check values through parsing and transformation. |
| 11.1 multiline node attributes | Parity case 3 checks multiline prompt and label. |
| 11.1 edge label/condition/weight | Edge construction, parity routing cases and scoped-edge regression check fields used by routing. |
| 11.1 chained edges | Parser chaining test checks endpoints and weights on both resulting edges. |
| 11.1 scoped defaults | Node inheritance/restoration tests and new scoped-edge regression. Edge leakage fixed below. |
| 11.1 flattened subgraphs | Parser subgraph test and lifecycle class-derivation test check retained nodes and derived classes. Subgraph metadata also remains available. |
| 11.1 node classes | Lifecycle preparation and stylesheet specificity tests exercise class-based resolution. |
| 11.1 quoted/unquoted values | Linear parser and quoted typed-attribute tests check strings, integers and Booleans. |
| 11.1 comments | Parser fixtures accept both comment forms; `comments-do-not-consume-quoted-prompt-or-edge-text` preserves URL/comment text inside strings while excluding commented declarations from the graph. |
| 11.2 exactly one start | Valid/missing-start tests plus `boundary-identifiers-and-shapes-require-exactly-one-node` cover identifier fallback, shape-based boundaries, duplicate shapes, and a named start competing with another start-shaped node. Duplicate cases raise validation errors. |
| 11.2 exactly one exit | The same boundary test covers named exits, shape-based exits, duplicate shapes and identifier/shape competition, with error-severity terminal diagnostics. |
| 11.2 no incoming start edges | Lifecycle validation fixture includes `exit -> start` and requires `start_no_incoming`. |
| 11.2 no outgoing exit edges | Same fixture requires `exit_no_outgoing`. |
| 11.2 reachability | Validation orphan test, parity case 6 and lifecycle severity/node-ID assertions. Uses normative §7.2 ERROR despite §11.12 saying warning. |
| 11.2 existing edge endpoints | Lifecycle fixture appends `ghost -> missing` to an AST and requires `edge_target_exists`; DOT creates implicit endpoint nodes. |
| 11.2 prompt warning | Lifecycle blank-prompt/label fixture exercises warning. Code follows normative §7.2 prompt **or label**, rather than checklist prompt-only wording. |
| 11.2 condition syntax | Invalid-condition lifecycle fixture requires `condition_syntax`. Full expression semantics remain a separate §11.9 audit. |
| 11.2 validate_or_raise | Lifecycle validation API test checks error exception with complete diagnostics and warning/info preservation on no-error return. |
| 11.2 diagnostic schema | Same test checks canonical rule/severity/message/target fields across all built-in rule families. Graph-wide errors need no node/edge target. |
| 11.10 graph stylesheet parsing | Parity case 18 and public malformed-stylesheet test exercise valid application and rejection diagnostics. |
| 11.10 shape selector | Parity case 18 and reasoning-effort stylesheet test check model/provider/effort. |
| 11.10 class selector | Specificity test and lifecycle preparation check class overrides. |
| 11.10 ID selector | Specificity test checks ID overriding class. |
| 11.10 four-level precedence | `all-selector-levels-compete-through-public-preparation` declares ID, class, shape and universal rules in decreasing priority order, then checks each winning model and an explicit override in one prepared graph. |
| 11.10 explicit attributes | Specificity and custom-property tests retain explicit model/property values. |

## Scoped edge defect

Subgraph `edge [...]` declarations updated the global defaults map. Closing the
subgraph restored node defaults but left edge weights and labels changed. The
new `edge-defaults-are-inherited-and-restored-at-subgraph-boundaries` test failed
before the fix. It checks inherited defaults, later declarations, explicit edge
overrides, nested restoration, top-level restoration and sibling isolation.

Edge defaults now live in each subgraph's scope record and inherit from the
parent when opened. Explicit edge attributes override that scope's defaults.

Verified after the fix: parser 11/46/0; validation 3/4/0; stylesheet 8/46/0;
lifecycle 8/162/0; parity 25/61/0; native build succeeds.

Evidence follow-up: the three gaps identified in this audit now have direct
assertions and pass without production changes. Updated focused results:
parser 12/49/0, validation 4/15/0, stylesheet 9/51/0. The initial cascade test
fixture used an unquoted hyphenated DOT value; it was corrected to a quoted
string before assessing precedence. Broader runtime execution, condition,
provider and release requirements remain outside this audit's scope.

---

## Context, Checkpoint & Artifact Audit

# Context, checkpoint and artifact audit

Audited 2026-09-12 against the pinned Attractor specification §§5.1, 5.3,
5.5–5.6 and §11.7. EDN persistence is the user's explicit format choice;
stage status files retain the external JSON contract.

| Contract | Inspected implementation and behavioral evidence |
| --- | --- |
| Context get/set, string conversion, update merge and append-only logs | context.lg uses one atom holding values/logs; updates preserve unrelated keys. Engine applies outcome updates before checkpoint creation. |
| Serializable deep snapshot and isolated branch clone | context_isolation_contract_test checks nested maps, vectors, lists and sets, separate clone/log identities and subsequent independent mutations; unsupported values fail with their path. |
| Checkpoint state fields and readback | context_test round-trips checkpoint data including optional fidelity and captured-workflow identity; engine writes completed node, retries, outcomes, context and logs. |
| Resume next node, preserve retries and degrade first full-fidelity hop | engine_test named resume cases and workflow_recovery_contract_test cover consumed retries, no repeat of completed failure, captured source recovery and first-hop fidelity. |
| Artifact storage, retrieval, metadata, removal and clearing | context_test covers UTF-8 threshold, inline/file-backed round-trip, missing values, rejected unsupported data and failed deletion retaining registrations. |
| Artifacts survive later handlers and resume | artifact_discovery_test uses fresh stores in later handlers and resumed runs and checks persisted outcome metadata. |

The audit exposed a collision introduced by persistent registration metadata:
both that metadata and a large artifact named `index` used
`artifacts/index.edn`. Three new assertions failed because retrieval returned
the registration map instead of the original payload. Metadata now lives in
`artifacts/.store/index.edn`, outside the artifact filename namespace. Existing
legacy indexes remain readable and are migrated before publishing a conflicting
payload. The regression verifies immediate retrieval, reopening, removal without
losing another artifact, and reading a legacy store before publishing `index`.

Fresh verification after the fix: context 12 tests/49 assertions; artifact
discovery 3/22; context isolation 2/91; workflow recovery 52/481. All pass, as
does the native CLI build and whitespace check. The previous integrated suite
result (1051 tests/9724 assertions) predates this artifact change.

Limits: these checks do not prove process-crash atomicity across payload and
metadata publication or concurrent mutation by independently opened stores.
The original §5.5 store lock protects one store instance; cross-process shared
store coordination is not established here. Existing payloads already destroyed
by the collision cannot be recovered from their metadata. This document is one
part of the completion audit, not a claim of whole-spec completion.

## Resume-log follow-up

The §11.12 parity test named checkpoint-resume originally only reloaded a
completed checkpoint. It now compares an uninterrupted run with a run stopped
after its first work stage and resumed from disk. This exposed dropped log
history: the resumed checkpoint contained only `consumed`, while uninterrupted
execution contained `prepared, consumed`. The engine now restores saved logs
before invoking resume observers or executing the next handler.

The test verifies that only unfinished work executes, prior context reaches the
next handler, and final traversal, retries, log history, semantic outcomes and
application context agree. Optional Outcome defaults added during loading are
compared semantically. Fresh parity checks pass 25 tests/75 assertions and
engine checks pass 46/209 after the fix.

---
