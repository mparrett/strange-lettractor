# Attractor Documentation

**Project:** [Attractor](https://github.com/strongdm/attractor) / Strange Lettractor — an agentic workflow orchestration framework implemented in [let-go](https://github.com/nooga/let-go) (Go-based Clojure).

This directory consolidates the project documentation. Files marked *consolidated* were merged from multiple related source files; the original files are preserved in [`_archive/`](_archive/).

---

## NLSpec (Natural Language Spec)

The upstream Attractor spec repository uses **NLSpecs** — human-readable
specifications intended to be directly usable by coding agents to implement
and validate behavior.

The project maintains snapshotted copies of the three NLSpec documents in
[`docs/specs/`](specs/), with implementation evidence tracked against each
checklist item:

| NLSpec | Source |
|---|---|
| [Attractor Specification](specs/attractor-spec.md) | [`strongdm/attractor`](https://github.com/strongdm/attractor) commit `fb57a55` (2026-09-04) |
| [Coding Agent Loop Specification](specs/coding-agent-loop-spec.md) | same source |
| [Unified LLM Client Specification](specs/unified-llm-spec.md) | same source |



## Navigation

- **New to Attractor?** Start with the [Tutorial](tutorial.md).
- **Project overview & future work:** [future_work.md](future_work.md).
- **Iteration tracking:** See [`superpowers/iterations/`](superpowers/iterations/).
- **ASDLC methodology reference:** See [`asdlc-skill/`](asdlc-skill/).

---

## Specifications

The three NLSpec documents from [`strongdm/attractor`](https://github.com/strongdm/attractor)
are maintained in [`docs/specs/`](specs/) with completed Definition-of-Done checklists:

| Document | Checklist Items |
|---|---|
| [Attractor Specification](specs/attractor-spec.md) | 76/76 [x] |
| [Coding Agent Loop Specification](specs/coding-agent-loop-spec.md) | 59/59 [x] |
| [Unified LLM Client Specification](specs/unified-llm-spec.md) | 71/71 [x] |
| [Evaluation Harness Extension](evaluation-harness-extension.md) | Proposed extension: run scoring, independent evaluation, skills, MCP, and constrained generated let-go modules |

## Consolidated Audits & Implementation Docs

### Runtime & Spec Compliance

| Document | Contents | Size |
|---|---|---|
| [`runtime-audits.md`](runtime-audits.md) | *Consolidated* — Build, condition, execution, human interaction, integration, parsing/validation, and state audits (7 original files) | 26 KB |
| [`original-spec-status.md`](original-spec-status.md) | Original Attractor spec reconciliation and status | 6 KB |
| [`coding-agent-definition-of-done.md`](coding-agent-definition-of-done.md) | Coding agent loop evidence mapping | 4 KB |

### Providers & Models

| Document | Contents | Size |
|---|---|---|
| [`provider-model-audits.md`](provider-model-audits.md) | *Consolidated* — Default model, middleware routing, model catalog, prompt metadata, provider error, reference alignment, Anthropic modern model, Gemini aliases, unified core infra, and provider evidence audits (10 original files) | 48 KB |
| [`prompt-caching.md`](prompt-caching.md) | Prompt caching implementation (Anthropic, OpenAI, Gemini) | 4 KB |

### Streaming & Schema

| Document | Contents | Size |
|---|---|---|
| [`stream-schema-audits.md`](stream-schema-audits.md) | *Consolidated* — Stream accumulator, segment completion, HTTP errors, terminal errors, structured-output schema audits (8 original files) | 43 KB |

### Agent Workers

| Document | Contents | Size |
|---|---|---|
| [`agent-workers.md`](agent-workers.md) | *Consolidated* — Codex app-server, Claude agent/worker, Qwen development trials (5 original files) | 23 KB |

### Console

| Document | Contents | Size |
|---|---|---|
| [`console-features.md`](console-features.md) | *Consolidated* — Console requirements, input routing, timeout, workers design (6 original files) | 36 KB |

### Hub & Transport

| Document | Contents | Size |
|---|---|---|
| [`hub-features.md`](hub-features.md) | *Consolidated* — Listener, session plan, worker findings, nREPL investigation, shared hub transport (7 original files) | 52 KB |
| [`http-question-audit.md`](http-question-audit.md) | HTTP human-question audit | 2 KB |

### Tool Features

| Document | Contents | Size |
|---|---|---|
| [`tool-features.md`](tool-features.md) | *Consolidated* — Tool call repair, tool choice capability audit, tool hooks plan (4 original files) | 18 KB |

### Artifact & File Features

| Document | Contents | Size |
|---|---|---|
| [`artifact-store.md`](artifact-store.md) | *Consolidated* — Artifact store contract/plan and implementation (2 original files) | 8 KB |
| [`read-file-contract.md`](read-file-contract.md) | *Consolidated* — File read contract plan and verification results (2 original files) | 9 KB |

### Session & Turn Management

| Document | Contents | Size |
|---|---|---|
| [`session-error-contract.md`](session-error-contract.md) | *Consolidated* — Agent session error contract plan and implementation (2 original files) | 10 KB |
| [`turn-ownership.md`](turn-ownership.md) | *Consolidated* — Turn ownership gap analysis and plan (2 original files) | 7 KB |
| [`subagent-lifecycle-plan.md`](subagent-lifecycle-plan.md) | Subagent lifecycle plan (ITER-0007 component) | 6 KB |
| [`llm-operation-ownership.md`](llm-operation-ownership.md) | LLM cooperative abort and streaming connection ownership | 7 KB |

### Interviewer & Queues

| Document | Contents | Size |
|---|---|---|
| [`interviewer-queues.md`](interviewer-queues.md) | *Consolidated* — Queue implementation plan and contract (2 original files) | 5 KB |

### Let-go Runtime Issues

| Document | Contents | Size |
|---|---|---|
| [`let-go-runtime-issues.md`](let-go-runtime-issues.md) | *Consolidated* — Upstream let-go bug reproductions and workarounds (#801–#856, 10 original files) | 45 KB |

---

## Standalone Design & Guide Documents

| Document | Description | Size |
|---|---|---|
| [`development-repl.md`](development-repl.md) | Local development loop with frontier escalation | 6 KB |
| [`embedded-review.md`](embedded-review.md) | Embedded paired review framework | 13 KB |
| [`recursive-development-plan.md`](recursive-development-plan.md) | Recursive development controller (plan → code → review) | 12 KB |
| [`command-env-isolation.md`](command-env-isolation.md) | Explicit command environment isolation | 3 KB |
| [`context-capacity.md`](context-capacity.md) | Deployment context capacity discovery | 3 KB |
| [`project-docs-budget.md`](project-docs-budget.md) | Project instruction byte budget (32 KB limit) | 3 KB |
| [`usage-aggregation.md`](usage-aggregation.md) | Provider token usage aggregation | 2 KB |
| [`verification.md`](verification.md) | Verification output reference | 1 KB |
| [`code-agents-and-notebooks.md`](code-agents-and-notebooks.md) | Plan-as-code agents and Prime Agent notebook use | 3 KB |

---

## Development Tracking ([`superpowers/`](superpowers/))

| Document | Description |
|---|---|
| [`superpowers/iterations/roadmap.md`](superpowers/iterations/roadmap.md) | Iterative delivery roadmap (ITER-0000 through ITER-0007) |
| [`superpowers/iterations/iteration-log.md`](superpowers/iterations/iteration-log.md) | Detailed component-completion log |
| [`superpowers/iterations/progress.md`](superpowers/iterations/progress.md) | Goal progress and original-spec reconciliation |
| [`superpowers/iterations/requirements/`](superpowers/iterations/requirements/) | Story-level requirements per spec area |
| [`superpowers/iterations/behavior-corpus.md`](superpowers/iterations/behavior-corpus.md) | Behavior-driven scenarios corpus |
| [`superpowers/iterations/behavior-scenarios.md`](superpowers/iterations/behavior-scenarios.md) | Detailed scenario definitions |
| [`superpowers/iterations/coverage-ledger.md`](superpowers/iterations/coverage-ledger.md) | Test coverage ledger |
| [`superpowers/plans/`](superpowers/plans/) | Design plans (dated, organized by area) |
| [`superpowers/specs/`](superpowers/specs/) | Detailed design specifications |

---

## ASDLC Knowledge Base ([`asdlc-skill/`](asdlc-skill/))

A self-contained skill library covering the Agentic Software Development Lifecycle:

| Subdirectory | Contents | Count |
|---|---|---|
| [`asdlc-skill/concepts/`](asdlc-skill/concepts/) | Foundational theories and models | 35 docs |
| [`asdlc-skill/patterns/`](asdlc-skill/patterns/) | Reusable architectural patterns | 17 docs |
| [`asdlc-skill/practices/`](asdlc-skill/practices/) | Concrete workflows and procedures | 12 docs |

---

## Other

| Document | Description |
|---|---|
| [`kilroy-validation.md`](kilroy-validation.md) | Kilroy DOT graph validation results |
| [`kilroy-validation-results.json`](kilroy-validation-results.json) | Raw Kilroy validation output |
| [`future_work.md`](future_work.md) | User-requested extensions beyond conformance baseline |
| [`tutorial.md`](tutorial.md) | Getting started tutorial |
| [`_archive/`](_archive/) | Original files before consolidation (preserved for reference) |

---

*Consolidated 2026-09-13. Original files from the agent fan-out are preserved in `_archive/`.*
