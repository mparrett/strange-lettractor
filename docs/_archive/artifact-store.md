# Artifact Store & Run Metadata

---


## Contract & Scope

# Artifact store and run metadata contract

Baseline: public `803ccb8`, production identical to verified `f9f7b30`.
Verified baseline 644/5970; candidate focused/bundled 3/64, impacted 138/920,
full default 647/6034, all zero failures. CLI build/help pass. Paired spec and
quality reviews approve; paired final component audit is clean. Set-valued data remains
limited by let-go #823, separate from this supported-store/layout component.
Scope derives from StrongDM Attractor §§5.5–5.6 and the user's internal EDN
serialization decision. Preserve external `status.json` and the separate pinned
`workflow/manifest.edn` format.

## Required changes and evidence

1. Write new run metadata (`id`, `goal`, `start_time`) to root `manifest.edn`
   using the existing non-evaluating EDN representation. Do not delete or rewrite
   legacy JSON manifests; there is no existing root-manifest reader to migrate.
   Test through actual public pipeline execution, not only the helper.
2. Complete the artifact store's §5.5 evidence: exactly 100KB stays in memory,
   one byte more is file-backed with a base directory, large data without a base
   directory stays in memory, metadata is complete, and typed retrieval agrees.
   Cover file-backed replacement by a small value and publication failure without
   corrupting prior registration/value. Existing EDN/Unicode/deletion tests remain.
3. In a public pipeline, a custom handler uses the real public store API under
   the supplied run root, returns artifact metadata in its outcome, and leaves
   file-backed EDN output retrievable. Independently inspect run metadata, stage
   `status.json`, checkpoint outcome metadata, and store contents. Verify separate
   fresh/restarted roots do not corrupt earlier artifacts.

## Scope boundary identified by source review

The earlier SCN-ARTIFACT-DISCOVERY promised final-result inventory and restoration
across resume, beyond the upstream store API. Do not silently discard that promise
or pretend these tests satisfy it. Keep discovery/reconstruction as a separately
pending adopted project requirement, with its existing scenario, and mark only
the source-grounded store/run-layout component complete when verified. No new
persistent index, automatic file scanning, or invented recovery protocol here.

## Verification

Permanent regression must fail for missing EDN manifest before the minimal code
change. Add a focused standalone runner; run impacted context/engine/recovery
contracts, full sentinel suite, bundle and CLI build/help. Paired scope/spec/
quality and final component audit gate publication. This does not complete all
artifact discovery, ITER-0006, or the full Attractor objective.

## Implementation

# Artifact storage and run metadata

The public store API is in `attractor.context`: `make-artifact-store`,
`store-artifact!`, `retrieve-artifact`, `has-artifact?`, `list-artifacts`,
`remove-artifact!`, and `clear-artifacts!`.

The backing threshold is 102,400 bytes. Strings use UTF-8 payload size; other
supported values use their serialized EDN size. Values above that threshold use
`artifacts/<id>.edn` when the store has a base directory. Values at the threshold,
or without a base directory, remain in memory. Metadata includes ID, name, size,
storage time, and backing status. Artifact values must round-trip through the
supported non-evaluating EDN reader.

Set values round-trip on the local runtime's data reader (2026-09-08); on a
released let-go without it they would still be rejected, see
[let-go #823](https://github.com/nooga/let-go/issues/823) and
`let-go-set-reader-gap.md`.

New run metadata is written to root `manifest.edn`; this is separate from the
immutable captured workflow's `workflow/manifest.edn`. Existing root JSON
manifests are not removed or migrated. The external stage-status contract still
requires `<node_id>/status.json`. Checkpoints use `checkpoint.edn`.

A handler can create/use a store under the supplied run root and return artifact
metadata in its outcome. Registrations persist in `artifacts/.store/index.edn` (written
atomically on every store/remove/clear): metadata for each artifact, the value
itself for inline artifacts, the file path for file-backed ones. Opening a new
store over the same root reconstructs them, `discover-artifacts` lists them
from run state without a store, and `checkpoint-artifacts` reads the metadata
handlers returned in their outcomes, which survives resume (ATTR-ART-02,
`SCN-ARTIFACT-DISCOVERY`).

The `.store` directory separates registration metadata from payload filenames:
an artifact named `index` can safely use `artifacts/index.edn`. Stores from the
older layout are read from that legacy path when the new index is absent;
their registrations are migrated before a payload can overwrite the old index.
Payloads already overwritten by the old collision cannot be reconstructed from
registration metadata alone.
