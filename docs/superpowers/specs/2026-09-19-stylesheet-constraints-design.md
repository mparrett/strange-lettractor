# Stylesheet constraints and hierarchical token budgets

Status: design, awaiting review. 2026-09-19.

## Problem

`max_total_tokens` caps one agent session, but nothing in a DOT pipeline can
set it, a capped agent still reports success, a subagent's spend is invisible
to its parent, and there is no ceiling for a whole run. Token spend is a limit
imposed from above: the operator bounds the run, the run bounds its nodes, a
node bounds its subagents.

## Syntax

A constraint is a stylesheet declaration without a colon:

    constraint  = metric operator bound
    metric      = "tokens" | "turns" | "tool_rounds"
    operator    = "<" | "<=" | ">" | ">=" | "=" | "!="
    bound       = integer | percentage | calc

    :root        { tokens <= 1000000; }
    *            { tokens <= 25%; turns <= 40; }
    .cheap       { llm_model: haiku; tokens <= 20000; }
    #deep_review { tokens <= calc(var(--tokens-available) * 0.8); }

The form follows CSS media-query range syntax (`width <= 600px`). Property
declarations (`name: value`) are unchanged.

`:root` is a new selector naming the run itself. It accepts constraints only;
a property under `:root` is a syntax error (graph attributes already provide
run-wide property defaults).

### Computed bounds

A percentage resolves against the enclosing budget, as CSS percentages
resolve against the parent: `tokens <= 80%` is 80% of the tokens the
enclosing level has available when the node starts. Percentages are valid
only for `tokens`.

`calc()` accepts integer and decimal numbers, `+ - * /`, parentheses,
`min(a, b)`, `max(a, b)` and `var(--name)`. The result is floored to an
integer. `var()` reads either an integer custom property that cascades to the
node (`--worker-share: 20000`) or one of the variables the engine sets for
every node run:

| Variable | Value |
|---|---|
| `--tokens-available` | tokens the enclosing level can still spend |
| `--tokens-limit` | the enclosing level's ceiling |
| `--tokens-used` | tokens the run has spent so far |

`N%` is exactly `calc(var(--tokens-available) * N / 100)`. The `--tokens-`
prefix is reserved: declaring such a property is a syntax error.

Bounds are resolved when the node run starts, every time it starts, so a
node revisited by a loop sees the budget as it then stands.

## Levels and combination

Ceilings nest, outermost first: the operator (`--max-tokens N` on the CLI,
`:max_tokens` for library callers), the run (`:root`), the node (any other
selector), the subagent (`max_total_tokens` on `spawn_agent`).

Within the node level, constraints cascade like properties. A node holds at
most one upper bound (`<`, `<=`, `=`) and one lower bound (`>`, `>=`) per
metric, plus any `!=`; higher specificity wins, then later order. So
`#deep_review` may loosen a `*` default.

Across levels nothing is overridden: the effective token ceiling is the
minimum along the chain. A node cannot spend more than the run has left,
whatever its own rule says.

`turns` and `tool_rounds` are per node run and have no enclosing level.

## Ledger

New namespace `attractor.budget`, with no dependency on the agent or engine:

    (make-budget {:label "run" :limit n-or-nil :parent budget-or-nil})
    (charge! budget usage)      ; adds to this budget and every ancestor
    (available budget)          ; min over the chain of (limit - used); nil = unbounded
    (exhausted budget)          ; nil, or the nearest exhausted level {:label :limit :used}

`charge!` takes a normalized usage map and counts `:total_tokens`, falling
back to input plus output when the provider reports no total.

The engine creates one run budget per pipeline run. The agent backend creates
a node budget per node run, child of the run budget, so nodes sharing a
full-fidelity thread (one session) are still metered separately. A session
accepts `:token_budget`; it charges each response's usage and checks
`exhausted` between rounds. `spawn-subagent!` gives the child a budget whose
parent is the spawning session's budget, so child spend rolls up and a child
is bounded by what its parent has left. `:max_total_tokens` stays as sugar
for a session-level budget; the history-summing helper is removed.

Parallel branches charge the same run budget concurrently. The check runs
between rounds, so rounds in flight can overshoot; the cap is soft by design.

## Failure

A node run fails when a limit stopped its agent, or when any constraint is
violated at completion (lower bounds and `=`/`!=` are checked only then):

    {:status :fail :retryable false :category :constraint_violated
     :failure_reason "constraint violated: tokens <= 20000 (used 23114)"}

When an outer level is the one exhausted, the reason names it:
`"run budget exhausted: tokens <= 1000000 (used 1003412)"`. Once the run
budget is exhausted, later LLM nodes fail with that reason without calling
the model. A bound that cannot be resolved — a percentage or
`--tokens-available` with no enclosing ceiling, division by zero, a negative
result — fails the node with `"constraint unresolvable: <text>: <cause>"`.
Failing is deliberate: a budget that silently does not apply costs money.

The session records why it stopped (`:stop_reason`), the backend turns that
into the outcome, and the existing `:token_limit` / `:turn_limit` events gain
the exhausted level. `:fail` outcomes are already not retried by the engine;
edges on `outcome=fail` route as usual, for instance to a tool node that
writes a report.

## Validation

`validate` reports, as `stylesheet_syntax`: an unknown metric, a malformed
bound or `calc()`, an unknown or reserved `var()` name where statically
known, a percentage on a metric other than `tokens`, a property under
`:root`.

## Out of scope

- External agent workers (`--agent claude`, codex) own their loop; their
  nodes are not metered. A constraint matching such a node logs a warning.
- Non-LLM nodes ignore these metrics, so `*` rules stay usable.
- Inequalities in edge conditions and a `tokens_used` context key.
- Cost in currency, wall-clock constraints, a per-node DOT `constraints`
  attribute.

## Tests (written first)

- `budget_test`: charge rolls up; `available` is the chain minimum; unbounded
  levels; usage without a total; `exhausted` names the nearest level.
- `stylesheet_constraints_test`: each operator and bound form parses; each
  syntax error; cascade override per metric and direction; `:root`.
- `constraint_bounds_test`: percentage, `calc`, `var` of custom and engine
  variables, flooring, each unresolvable case.
- Agent loop contract: budget stops the loop, `:stop_reason` recorded,
  subagent spend charges the parent, child bounded by parent's remainder.
- Backend/engine: overshoot yields the fail outcome and reason; lower-bound
  violation; run budget exhaustion fails later nodes unrun; two nodes on one
  thread metered separately; bounds re-resolved on loop re-entry.
