# Interviewer Queues — Contract & Evidence

## Queue Implementation Plan

# Shared interviewer queue and contract matrix

Fresh full baseline on public `6d6e813`: 647 tests / 6,034 assertions / zero
failures, exit 0. Atomic runtime findings are filed in let-go #824.
Final focused/bundle: 18 tests / 143 assertions; impacted: 119/924;
full suite: 653/6068, all zero failures, exit 0. CLI build/help pass.
Paired scope/spec/quality approve. Final paired three-tier component audit is clean.

Source: StrongDM Attractor §§4.6, 6.1–6.4; native console deadlines remain the
separate ATTR-HUM-02 capability gap. Existing `interviewer_contract_test.lg`
already exercises sequential answers, callbacks, recording, accelerator grammar,
ready console input and human routing; its corpus entry is stale.

QueueInterviewer currently snapshots the head and removes it in separate atomic
operations. Parallel human gates share the interviewer, so two asks can return
the same answer and consume two entries. Exhaustion may also throw on an empty
tail. Prove the race mechanically before changing production.

## Repair contract

- Each ask atomically claims at most one queued answer; concurrent callers never
  duplicate/omit supplied answers or throw solely because another ask drained it.
- Preserve complete answer maps and scalar normalization, FIFO claim order, and
  existing empty-queue default/skipped behavior. Do not impose scheduling order
  on parallel branches or recording completion order.
- Keep the documented factory API unchanged. Use a narrow per-instance boolean
  CAS lock, released in finally, around dequeue only. No user callback, prompt,
  recording delivery or input waiting belongs inside that critical section.
- Preserve the existing one-argument `->QueueInterviewer` constructor with a
  small compatibility wrapper allocating the new lock; verify it explicitly.
  If the runtime cannot support this cleanly, revise scope before changing it.
- Occupancy is determined by the queue sequence, not head truthiness. Consume
  scalar `false`/`nil` under the existing scalar-answer normalization contract,
  so neither can trap later queued answers. Add explicit evidence for both.
- Native swap-vals!/collection CAS currently fail verified runtime contracts
  (`let-go-atom-update-gaps.md`); retain a restoration breadcrumb, not runtime edits.

## Evidence

1. Bounded deterministic overlap at the mutation boundary proves the current
   duplicate/exhaustion failure. Gates and workers are always released/joined.
2. Concurrent asks with enough and insufficient answers, defaults/skips, complete
   map preservation and no duplicate/lost answers after the fix.
3. Real parallel workflow using one queue wrapped in RecordingInterviewer;
   correlate each recorded pair with its branch outcome/checkpoint without
   assuming which branch wins a particular answer.
4. Complete the existing §4.6 handler matrix with no-outgoing-edge failure and
   completely unmatched-answer first-choice fallback. Reuse existing tests rather
   than claiming their previous coverage is new implementation.
5. Focused/bundle, impacted engine/interviewer/handler tests and frozen full suite;
   paired scope/spec/quality and three-tier audit before public checkpoint.

ATTR-HUM-01 can close only with this evidence and corrected corpus references.
No console timeout, terminal events, full iteration or native-AOT claim is implied.

---

## Queue Contract Reference

# Shared queue interviewers

`make-queue-interviewer` accepts an ordered collection of answers. Answer maps
are returned intact; scalar entries (including `false` and `nil`) are consumed
and normalized to `:value`/`:text` maps. Exhausted queues use the question's
`:default`, or return `:skipped`. The default-on-exhaustion policy is an existing
project extension to StrongDM's queue pseudocode.

Concurrent calls through the **same QueueInterviewer instance** claim each answer
once. FIFO means claim order, not a predetermined assignment to parallel branches.
RecordingInterviewer preserves question/answer pairs; concurrent recording order
is completion/append order, not guaranteed invocation order.

The existing one-argument `->QueueInterviewer` constructor remains available for
an answer atom. Its lock belongs to the interviewer instance: multiple instances
wrapping the same atom, or direct external mutations of that atom, are not
coordinated. Share the interviewer itself with parallel consumers.

A narrow boolean-CAS lock currently guards dequeue because local let-go's native
atomic-update alternatives have the defects tracked in
[let-go #824](https://github.com/nooga/let-go/issues/824). No input waiting,
callback or recording happens inside the critical section. Restore a native
atomic dequeue only after the upstream contracts and these regressions pass.

This does not implement ConsoleInterviewer deadlines; those remain tracked by
ATTR-HUM-02 and let-go #822.

---
