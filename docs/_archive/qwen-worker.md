# Qwen Worker — Development Trials

## First Development Trial

# First Qwen development trial

The first real repository task used the existing let-go DOT engine and native
coding-agent loop with `qwen3.8-27b`, served by llama.cpp. The existing adapter
named `openai-compat` supplied its OpenAI-compatible Chat Completions transport; no
Ollama service was involved. Streaming was disabled for this trial.

Task: preserve a string `reasoning_content` field as normalized response
`:reasoning`, including the empty string; use nil for absent/non-string values.
Keep answer content, tool calls, usage, and raw data unchanged. This also restores
existing high-level generation/step reasoning propagation. Streaming reasoning
normalization was separate, unfinished work at the time of this trial. The later
[deterministic streaming fix](qwen-streaming-reasoning.md) is separate evidence,
not an additional autonomous Qwen development success.

## Outcome: assisted, not autonomous

Two bounded runs each reached 20 model requests. Qwen produced a regression test
and eventually proposed the correct production expression, but could not apply
the exact-match edit: its replacement searches repeatedly had incorrect leading
whitespace. Its first test also lacked a namespace and incorrectly expected a
nested response map. Review feedback helped it correct the test.

Neither DOT run passed its independent deterministic verification stage. Codex
then applied the two-line production change and supplemented Qwen's regression
coverage. Qwen's corrected test failed two assertions before that change.

The worker could modify only the adapter and its new test file, and could execute
only two fixed test commands. These tool allowlists are not an OS sandbox for
arbitrary code executed by tests. The known-good main checkout ran the workflow;
candidate changes lived in a separate `.worktrees` checkout. No private project
notes were included.

## Follow-up breadcrumbs

- Give workers explicit available paths and actionable permission errors.
- Improve exact-edit guidance and mismatch diagnostics without silently relaxing
  edit matching. The generic profile's edit description is currently minimal.
- Bound repeated unsuccessful calls and escalate with the actual tool evidence.
- Preserve a deterministic test gate: reaching the agent turn limit must not be
  interpreted as successful implementation merely because the handler returned.
- Align context budgeting with the server's active context (32,768 in this run),
  not the generic profile's larger default or the model's training maximum.

This trial does not establish unattended self-development readiness or broad
model-quality conclusions.

---

## Streaming Reasoning Fix

# OpenAI-compatible streaming reasoning

The local-model adapter (currently named `openai-compat`, also used with llama.cpp)
preserved `reasoning_content` in non-streaming replies but discarded the same
field in streaming deltas. A deterministic SSE probe containing `Think` followed
by answer text produced no reasoning events and a nil final reasoning value.

The compatible streaming adapter now emits reasoning start/delta/end events for
string values and accumulates exact reasoning into the final response. Empty
strings are retained; absent, null and non-string values are ignored, matching
the existing non-streaming normalization. Reasoning remains separate from visible
answer text and tool-call arguments. Errors suppress subsequent events and do
not fabricate a successful finish.

The reasoning-end event carries the final accumulated `:reasoning` value;
`:reasoning_delta` remains exclusive to incremental events. This follows the
typed-completion clause in pinned unified-LLM spec §3.14 without making a consumer
accumulate the same text twice.

## Mechanical evidence (2026-09-07)

- Missing-reasoning regression: 18 failed assertions, zero test errors before
  the implementation change.
- End-event value regression: three failed assertions before adding that field.
- Final focused suite: seven tests, 57 assertions, zero failures/errors.
- Combined LLM and focused contracts: 90 tests, 551 assertions, zero failures.
- A standalone bundled entrypoint explicitly requiring the adapter and focused
  test namespace passed the same seven tests / 57 assertions outside the repo.
  This verifies packaged bytecode, not native Go AOT lowering.
- Final worktree suite: 577 tests, 4,780 assertions, zero failures.

Run the focused suite with the local runtime:

```sh
/Users/ndn/development/let-go/lg -source-paths src:test -e '(require (quote attractor.qwen-reasoning-test)) (clojure.test/run-tests) (os/exit (if clojure.test/*test-result* 0 1))'
```

The tests exercise low-level streaming, a configured client, the stream
accumulator, and high-level response/text-stream access. They include mixed
reasoning/text/tool chunks, usage-only trailing chunks and errors followed by
late data. The native-provider LLM regression suite is retained unchanged.

## Scope and remaining evidence

This is a local normalization fix, not a live-model or subscription test. No
model calls were made and no let-go runtime changes were required. Native OpenAI
continues using Responses, Anthropic Messages and Gemini generateContent; this
does not replace those adapters with a compatibility API.

Reasoning-history replay and thinking-content-part representation are unchanged.
Repeated `[DONE]` handling and the corresponding accumulated-value fields on
other adapters' segment-end events remain separate streaming audit work. Do not
infer full streaming conformance or native-provider parity from this fix.

---
