# Code agents as planners and notebooks

This guide shows how to use plan-as-code agents and the Prime Agent Python
notebook with the evaluation-harness workflow. It is operational guidance, not
a normative contract.

Related proposal: [`evaluation-harness-extension.md`](evaluation-harness-extension.md).

## Plan-as-code agents

A plan-as-code agent writes executable code as its plan. The code calls named
tools, branches on results, loops over bounded inputs, and returns structured
outputs. This pattern fits evaluation work because the plan itself can be
checked, run, versioned, and scored.

Prefer let-go Lisp plans, in the spirit of a smolagents-style CodeAgent:

- A plan is data first: quoted forms or source text, stored with a digest.
- Validate shape, namespace allowlist, input/output schemas, timeouts, and
  output limits before evaluation.
- Evaluate only in a custom restricted REPL/runner.
- Keep prompts, code, calls, outputs, digests, and resource use as evidence.
- Score artifacts and verifiable outputs, not internal reasoning.

The existing hub `:eval/submit` path is trusted local evaluation with the
user's authority. It is not the restricted runner. Never submit untrusted
model-drafted plans to it.

Example role mapping:

| Evaluation role | Plan-as-code use |
|---|---|
| Worker | Draft implementation code plus tests as one bounded change. |
| Evaluator | Draft scoring code that reads a frozen evidence packet and returns dimensions. |
| Evolution | Draft a harness, prompt, skill, or tool change as a diff plus validation. |

Let-go plan example. The plan is stored as data; nothing here executes on write:

```clojure
;; A plan is a vector of step maps holding quoted forms.
{:plan/id "score-acceptance"
 :plan/steps
 [{:step/id "read-packet"
   :step/form '(packet/read "runs/abc/evaluation-packet.edn")}
  {:step/id "check-artifacts"
   :step/form '(score/required-artifacts packet [:report :diff])}
  {:step/id "publish"
   :step/form '(score/publish {:packet packet :dimensions dims})}]}
```

Restricted-REPL sketch. Names are illustrative; the behavior is the requirement:

```clojure
(restricted-eval
  {:code plan-source
   :allow-namespaces '[score packet]
   :allow-vars '[score/dimension score/publish packet/read]
   :max-forms 32
   :max-output-bytes 65536
   :timeout-ms 5000
   :bindings {'packet packet}})
```

The restricted runner must:

- Parse with a non-evaluating reader; never eval during validation.
- Reject unknown namespaces and vars, plus `eval`, reader-eval,
  `io`/`os`, shell, network, clocks, randomness, credentials, host atoms,
  and compiler/runtime internals.
- Evaluate in a fresh namespace per run, with no `*session*`/`*run*`
  leakage unless explicitly bound as provided data.
- Serialize evaluations, enforce timeout/cancellation, and capture printed
  output separately from the returned value.
- Return a structured value or a tagged error, never a raw host object.
- Record code digest, allowlist, inputs, outputs, and resource use.

Do not let plan-as-code bypass the extension trust rules. Generated code stays
quarantined until deterministic gates, frozen-anchor comparison, and promotion
policy pass.

### Delegated authority

Authority must be delegated, never ambient:

- Every session, run, and tool call carries a delegate with id, parent,
  scope, capabilities, expiry, and budget.
- Delegates only narrow; a child cannot exceed its parent.
- Runners resolve credentials server-side by reference; delegates never carry
  secrets.
- Resume re-validates delegates; expired or narrowed delegates fail closed.
- Widening scope requires a new grant through human approval or promotion
  policy, recorded as an event.

### Reflection and dynamic definitions

Prime-agent-style agents define helpers as they work. Allow that, but keep it
observable and bounded:

- Expose read-only reflection: list namespaces and vars, describe name,
  args, doc, and schema, and inspect plans, sessions, artifacts, and own
  capabilities.
- Reflection output is data, bounded, and redacted; it must not evaluate
  code, expand untrusted macros, or expose host internals.
- New definitions start as session-local data: parsed without evaluation,
  validated against the allowlist, versioned, and confined to the run's
  scratch namespace.
- Promote a helper to a reusable tool only after tests, review, and
  promotion gates; reflection then shows its provenance and revision.

## Prime Agent Python notebook

The Prime Agent Python notebook is a persistent orchestration REPL. Use it to
drive benchmark matrices, inspect evidence, parse artifacts, compute scores,
and publish reports.

Useful behavior:

- Variables, imports, and helper functions persist across cells.
- Top-level `await` is supported.
- Use Python for loops, parsing, filtering, and reporting.
- Run shell commands through `bash()` handles.
- Do not write shell loops or heredocs.
- Run project tests and CLIs through the project's own environment.
- Keep secrets out of prompts, logs, packets, and reports.

Shell-handle pattern:

```python
handles = {}
for task in tasks:
    handles[task] = bash(f"bin/attractor run {task.dot} --logs-root runs/{task.id}")

results = {}
for task_id, handle in handles.items():
    completed = await handle
    results[task_id] = {
        "exit_code": completed.exit_code,
        "output_tail": handle.tail(50),
    }
```

Evidence pattern:

```python
from pathlib import Path

packet = Path(f"runs/{task.id}/evaluation-packet.edn").read_text()
score = score_packet(packet)
write_score_report(task.id, score)
```

Use the notebook for orchestration and analysis. Do not use it as a substitute
for Attractor checkpoints, artifact storage, evaluator isolation, or promotion
gates.

## Recommended combination

1. Use plan-as-code agents to produce explicit worker and evaluator code.
2. Use the notebook to run task matrices and collect evidence.
3. Validate packets, schemas, digests, budgets, and provenance deterministically.
4. Run independent model evaluation from frozen packets.
5. Compare harness configurations on the same anchor set.
6. Promote only through the configured evaluation and promotion gates.
