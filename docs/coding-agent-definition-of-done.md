# Coding agent loop: definition-of-done evidence

Checklist blocks of the upstream coding-agent-loop spec mapped to supporting
tests on the local runtime; this is not a claim of complete coverage. "Wire" means a real session drives
the provider's actual HTTP adapter against `test/fixtures/provider_wire_server.lg`.
Verified 2026-09-10, full suite 916 tests / 8733 assertions / 0 failures.

| Block | Evidence |
|---|---|
| 9.1 Core loop | `agent_loop_contract_test.lg` (sequential inputs, round and turn limits, follow-up), `agent_loop_wire_test.lg` (wire tool turn), `turn_ownership_test.lg` (abort kills processes, CLOSED), `agent_test.lg` loop detection |
| 9.2 Provider profiles | `profiles_test.lg` (tool sets, schemas, system prompts, custom registration and override), `agent_loop_wire_test.lg` (prompt and tools on the wire) |
| 9.3 Tool execution | `tool_hooks_test.lg`, `agent_test.lg` (unknown tool, argument validation), `agent_error_wire_test.lg` (tool failure returned as error result), `llm_contract_test.lg` (parallel ordered execution) |
| 9.4 Execution environment | `environment_contract_test.lg` (interface, 10s default, per-call timeout, SIGTERM then SIGKILL, secret filtering, custom environments), `execution_*_test.lg` |
| 9.5 Tool output truncation | `tool_output_contract_test.lg` (character then line limits, marker, full output in events, overrides), `agent_parity_matrix_wire_test.lg` (large read on the wire) |
| 9.6 Steering | `agent_loop_contract_test.lg`, `agent_loop_wire_test.lg` (steering message as the next user turn on the wire) |
| 9.7 Reasoning effort | `agent_loop_wire_test.lg` (effort change on the next request), `llm_test.lg` (translation per provider) |
| 9.8 System prompts | `project_docs_contract_test.lg`, `prompt_metadata_test.lg`, `profiles_test.lg` |
| 9.9 Subagents | `subagent_lifecycle_test.lg`, `agent_subagent_wire_test.lg` |
| 9.10 Event system | `event_families_test.lg`, `agent_loop_wire_test.lg`, `agent_error_wire_test.lg` (terminal order) |
| 9.11 Error handling | `agent_error_wire_test.lg` (429/503 retried, auth fatal), `session_error_contract_test.lg` (context overflow warning), `turn_ownership_test.lg` (shutdown sequence) |
| 9.12 Parity matrix | **Partial.** `agent_parity_matrix_wire_test.lg` covers the first eight of fifteen rows for each native profile. Other component tests above support individual behaviors, but do not replace the full cross-provider matrix. `make live-parity` now offers ten rows, including error recovery and provider-specific editing. Five live rows remain absent: parallel calls, steering, reasoning changes, subagents, and loop warnings. Native Gemini still awaits credentials. |

Audit 2026-09-12: historical 8/8 gateway runs used generic profiles for registry
aliases. They establish transport behavior, not native profile parity. The live
runner now selects tools and base instructions by protocol and preserves the
configured alias for request routing. New recovery checks require a failed read
followed by a successful read in a later tool round and the recovered file.
Editing checks require the profile's dedicated tool and the exact resulting file.

Focused live follow-up: Responses/GPT-4.1-mini passed both new rows on repeat;
the first editing attempt failed. Messages/Haiku-4.5 passed editing and failed
recovery's exact-file criterion. These results leave model reliability and the
full matrix open. Generated reports remain local under `evidence/`; see
[verification output](verification.md) for retention and reproduction.

Focused run of any row: `make run-<namespace>`, e.g. `make run-agent_parity_matrix_wire`.
