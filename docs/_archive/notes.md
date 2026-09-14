# Notes

Bruce shared this large chatgpt log with me:
https://chatgpt.com/s/t_7a9cda3e74708191b1ce5ace1d9ad091

This is a copy of a shared ChatGPT chat. It won't be added to memory.

Report conversation

I think you need to make the team’s judgment durable and operational, not just formalize how you prompt agents.

You are doing several jobs at once: developing a substantial product, stewarding domain semantics, supporting integrations, interpreting external formats, and deciding where the company should go next. With only a couple of people, the difficulty is keeping those activities coherent without making either of you the mandatory interpreter of every request and every change.

I would aim for this:

An incoming request can become a well-scoped, verifiable change without reconstructing the domain from your heads—and without letting an agent silently redefine correctness, support, or commitments.

That is a broader objective than “agent-assisted development.” DORA’s research provides a useful warning here: gains in individual coding productivity can be absorbed by downstream testing, review, and deployment bottlenecks. Its recommendation is to improve the surrounding organizational system, not merely increase code production.

For your team, I would build the operating model around the following.

1. Establish what you own—and what ownership obliges you to provide

“Own our domain” needs an explicit agreement with the company. Otherwise, you risk becoming responsible for everything that goes wrong while having ambiguous authority over the decisions that caused it.

I would write a short team charter, agreed with the relevant leadership and consuming teams. A starting point might be:

We steward catalog interpretation, configuration semantics, and the reusable capabilities through which company products consume them. We maintain the contracts, evidence, and evolution policy for those capabilities. Product teams own their product experiences and application-specific decisions. We provide a supported contribution and extension path rather than requiring all implementation to happen within our team.

The important part is the allocation of decisions.

Decision	Proposed authority
Meaning of shared catalog concepts and guarantees	Your team, with affected consumers consulted
Application-specific behavior that does not change shared semantics	Consuming team
Internal implementation within approved contracts	Delegated to engineers and agents
Changes to shared contracts, compatibility, or support promises	Named human domain owner
Company priorities, investment, and accepted business tradeoffs	Appropriate management sponsor, informed by your analysis
Exceptions to agreed engineering policy	Explicitly designated approver—not whoever happens to be handling the request

This should not require a committee. For a two-person team, it could be a named lead and backup, with a known escalation route.

Authority and service obligations should be reciprocal. In exchange for stewardship, you publish clear capabilities, respond predictably, explain decisions, accept contributions, and provide migration paths. Other teams should not need to understand all your internals or obtain personal permission for routine integrations.

For management requests, distinguish changing priorities from changing truth. Management can decide that a capability matters more than another. That does not make an unsupported format construct supported, or an unverified configuration valid. Those consequences need to remain visible.

Your position should be: “Here are the available choices, costs, and risks; here is our recommendation”—not either “management decides every technical detail” or “we disregard requests we dislike.”

2. Capture knowledge according to what kind of knowledge it is

I would not begin by asking agents to “document everything.” I would begin by identifying the distinctions and decisions that repeatedly require your intervention.

For your domain, useful candidates include the difference between an authored choice, a default, an inferred value, and an override; between an available option and a satisfiable configuration; between missing data and a deliberate exclusion; and between a source-format construct and your internal interpretation of it.

The crucial distinction is that not everything written down has the same authority.

Kind of knowledge	What its record should contain
Domain meaning	Definition, examples, counterexamples, relationships, responsible owner
Observed fact	Source, relevant version or date, scope, uncertainty
Accepted decision	Decision, rationale, alternatives rejected, consequences, supersession
Invariant	Exact requirement, scope, enforcement mechanism, verification evidence
Commitment	Consumer, promised behavior, delivery or support terms, accountable human
Limitation or hypothesis	What is unknown or unsupported, consequences, evidence needed to resolve it

An agent must not promote an observed quirk into a universal rule, a proposed design into an accepted decision, or a roadmap idea into a delivery commitment.

Extract knowledge while doing real work

Whenever either of you says, “Actually, that cannot work because…”, the workflow should capture the missing knowledge.

The useful output is usually small: a precise statement, a minimal example or counterexample, its rationale, and a test or explicit review condition where possible. Capture the general rule separately from any vendor-specific workaround.

For example:

This vendor omits field X when condition Y holds. That does not mean X has its usual default; it means its value must be derived through Z.

That could become a source observation, a narrowly scoped adapter rule, a fixture, and a diagnostic. It should not become a mysterious conditional that the next agent “simplifies.”

I would also preserve explanations of why apparently reasonable alternatives are wrong. Those are particularly valuable when the alternative is attractive enough to be proposed repeatedly.

Give knowledge a discoverable home, not one enormous instruction file

Use a small entry document that points to authoritative domain material, architecture, workflows, and executable checks. OpenAI’s published agent-heavy engineering case study describes replacing an oversized AGENTS.md with a short map into structured, versioned repository knowledge, backed by mechanical checks. That is a useful pattern here, without needing to copy its entire development process.

Keep implementation-adjacent knowledge close to the code. Keep confidential strategy, commercial relationships, and restricted catalog material behind appropriate access controls. Discoverability does not require indiscriminate access.

Most importantly, a discrepancy between code and an accepted contract is something to investigate. A documentation-maintenance agent must not “fix stale documentation” by rewriting the contract to match a bug.

3. Make the important promises executable—and make their limits explicit

You need more than tests. You need a connection between what you claim, what you intend, and what you have actually verified.

I would introduce a small registry of important contracts and constraints. Not a grand new language: structured records with stable identifiers and links to ordinary code, tests, fixtures, and decisions.

An illustrative candidate might look like this:

id: CAT-SEM-017
status: proposed
owner: catalog-domain

statement: >
  A configuration affected by an uninterpreted source constraint
  must not be reported as fully validated.

applies_to:
  - import
  - configuration-validation

checks:
  - unsupported_constraint_is_reported
  - affected_configuration_is_not_fully_validated

change_requires:
  - semantic-review

The names above are illustrative, not claims about your current implementation.

The YAML itself does not enforce anything. The infrastructure must resolve the check references, establish that they ran, attach the results to the relevant code revision, and apply the appropriate merge or release rule. Merely having a field named checks is not evidence.

For each important promise, I would want to answer:

What does it mean? Where does it apply? What checks it? Against which inputs and version? Who can change it? What remains unverified?

Treat support as a multidimensional claim

For a multi-format catalog system, I would avoid a single undifferentiated “supported” flag.

A claim such as “supports format X” should distinguish parsing, semantic interpretation, configuration evaluation, editing, pricing, export, and preservation of unsupported data. It should also identify relevant versions, profiles, vendor deviations, and operational limits.

Likewise, keep these separate:

Specified: the intended behavior is defined.
Verified: identified checks pass for identified cases and builds.
Supported: the team has made an explicit operational commitment.

A successful test does not automatically create a support obligation. A support obligation does not imply complete coverage. A prototype should not acquire either merely because its README sounds finished.

This gives both people and agents a defensible answer to “Can we use this?” The answer can be precise rather than cautiously vague or accidentally overconfident.

Put domain knowledge into a conformance corpus

I would treat your collection of representative and difficult catalog cases as a first-class product asset.

It should contain ordinary workloads, historical failures, vendor deviations, ambiguous inputs, malformed inputs, and cases that must produce an explicit limitation rather than a plausible result. Each case needs an expected interpretation and a reason—not just an output snapshot.

Use synthetic or appropriately permissioned fixtures where source data cannot be shared. Preserve the relevant semantics when minimizing a real failure.

Every difficult integration should leave behind a better corpus. Otherwise, you pay for the same discovery repeatedly.

4. Enforce quality at several levels, including the enforcement system itself

“Maintain high code quality” is too broad to delegate reliably. I would split it into checks with different purposes.

Structural constraints cover dependency direction, public API boundaries, platform requirements, approved dependencies, and where application-specific policy may live. In Rust, use the type system where a distinction is genuinely structural, and compile the target and feature combinations you promise. Tools such as cargo-deny can enforce dependency policies concerning advisories, licenses, banned dependencies, and allowed sources; they do not substitute for domain checks.

Semantic constraints cover the meaning of the system. For example, where your contracts require it, an incremental result should agree with full recomputation; an explanation should account for the relevant inputs and decisions; a transaction that fails should not leave a partial mutation; and unsupported source semantics should not disappear silently.

Operational constraints cover bounded resource use, cancellation, diagnostics, recovery, compatibility, and performance on representative workloads. Performance evidence should identify the workload, environment, and measurement procedure.

Maintainability constraints cover concerns that are harder to reduce to pass/fail: unnecessary abstraction, duplicate concepts, confusing APIs, and a feature whose long-term support cost exceeds its value. Give reviewers examples and decision criteria rather than pretending a file-length limit can measure architectural quality.

For critical semantics, I would combine ordinary tests with targeted property checks, comparisons against independently justified references, and deliberate mutations that establish whether the tests detect meaningful errors. A second implementation is useful evidence only to the extent that it does not reproduce the same mistaken assumption.

The agent must not be able to redefine success

This is one of the most important rules.

An implementation agent may propose changes to contracts, expected outputs, thresholds, or CI. But those changes must not silently authorize the implementation that needs them.

I would treat changes to policy, conformance expectations, release permissions, and verification infrastructure as a distinct risk class. Use trusted verification configuration and human approval where necessary, and tie evidence to the actual candidate being merged or released.

GitHub provides mechanisms for required reviews, required status checks, stale-approval handling, and selecting the expected application that supplies a status check. Those mechanisms need deliberate configuration; a green check from any writable source is not the same assurance as a result from your trusted verifier.

For existing violations, establish a visible baseline and prevent unapproved expansion rather than making the whole repository permanently red. Exceptions should have a narrow scope, rationale, owner, compensating measure, and expiry or review condition. Agents may request an exception; they should not approve their own.

And do not promise that this guarantees correctness. It makes specified failures harder to introduce and assumptions easier to inspect. Unknown failure modes remain something the team must actively look for.

5. Delegate bounded work, not vaguely defined agent roles

I would resist creating a miniature organization of named agents with elaborate reporting relationships. Start with a small set of workflows that have clear inputs, outputs, and authority.

The unit of delegation should be a work package containing the intended outcome, relevant sources and revisions, permitted scope, applicable contracts, non-goals, acceptance evidence, resource limits, and stop conditions.

A request like “improve the importer” is not a useful package. “Add interpretation for this construct, preserve these existing semantics, report these unsupported cases, and demonstrate the result against these fixtures” is.

A normal change could proceed through:

Understand the request → identify affected contracts and consumers → propose an approach → implement → verify → obtain required approval → release and update evidence.

Small changes should collapse these steps into a lightweight flow. Consequential changes deserve explicit intermediate artifacts.

Separate creating an answer from establishing that it is right

Have the evaluator begin from the requirement, relevant contracts, and independent evidence—not merely the implementer’s explanation of why its patch is correct.

Anthropic’s agent-harness work reports problems with agents positively evaluating their own work and describes separating generation from evaluation using explicit criteria. That supports using distinct evaluation passes, but it is not proof that agreement between two agents guarantees correctness.

For your highest-risk work, the question should be: “What evidence would reveal that both agents are wrong?”

That might be a historical regression, a reference result approved by a domain expert, a consumer-owned acceptance case, or an invariant checked over generated inputs.

Scale autonomy by risk and demonstrated reliability

I would initially distinguish three broad classes:

Work class	Suggested delegation
Bounded, reversible, non-semantic work with strong checks	Eligible for substantial automation, including narrowly authorized merge paths
Implementation changes within established contracts	Agent implementation and verification; human review according to risk and track record
Changes to meaning, compatibility, pricing policy, security boundaries, or commitments	Explicit human decision before the change becomes authoritative

“Documentation-only” should not automatically mean low risk. Changing a support promise can matter more than changing an internal function.

Autonomy should attach to a task class and permission scope, not to a general belief that a particular agent is trustworthy. Widen it when evidence supports that, and reduce it when failures show a gap.

Enforce permissions outside the prompt

Approved data handling, tool access, network access, credentials, and publication rights need technical controls. For example, an agent researching external catalog material should not automatically have access to production secrets or the authority to publish company commitments.

Filesystem and network isolation are distinct from tool permissions. Current Claude Code documentation explicitly notes that its Bash sandbox applies to Bash and child processes, rather than every tool, which illustrates why the whole access path must be considered.

Treat external documents, repository content, and imported data as untrusted inputs—not sources of operational authority.

Finally, maintain a small evaluation suite for the workflows themselves: representative past tasks, tricky constraints, and expected escalations. Re-run it when changing models, instructions, tools, or permissions. Measure whether the work is correct and appropriately bounded, not whether the agent produced a persuasive report.

6. Make responsiveness predictable without surrendering your roadmap

You need one visible place where demands and ideas become decisions. That does not mean forcing everyone into a large form. Requests can arrive through conversation; an agent can turn them into draft records.

Each meaningful request should capture the actual outcome sought, affected consumer, timing and why it matters, relevant capabilities, unresolved questions, next action, and accountable human.

Then distinguish response from commitment.

A useful response might establish that the capability already exists, identify an integration route, propose a bounded investigation, explain a limitation, accept work, or decline it with a reason. An acknowledgment alone does not count; neither must every useful response contain a delivery date.

Agents can prepare these responses from authoritative material. Creating or changing promises requires delegated authority, not merely the ability to send a message.

Protect initiative explicitly

Your own ideas need a place alongside requests—not below an endlessly expanding queue.

I would maintain a small, explicit allocation among current commitments, reliability and knowledge work, and strategic exploration. The exact allocation should be negotiated, but strategic work should not depend on all other work being finished.

An urgent management request should therefore produce a visible tradeoff:

We can prioritize this. It displaces this other commitment, or requires narrower scope or additional capacity.

That is a coherent management response, not resistance.

Limit work in progress according to your ability to verify and integrate changes. Ten agents producing ten patches is not useful if both humans are overwhelmed by unresolved semantic decisions. Parallelize work where the contracts and ownership boundaries make it genuinely separable.

Make status evidence-based

A short recurring brief should answer: what became usable, what is committed next, what is at risk, and what decision is needed.

Agents can assemble it from the work ledger and release evidence. They should not infer “delivered” from a merged PR when a consumer has not received the capability.

For each integration, agree on the boundary, consumer owner, relevant versions, acceptance cases, diagnostic route, and upgrade responsibilities. Let consumers contribute acceptance cases. Your claim that an integration works should not depend exclusively on tests written from your side of the boundary.

7. Treat the competitive and cooperative landscape as decision support

You should not have to keep the whole landscape in your heads. But I would also avoid building a large, speculative competitor wiki that nobody trusts.

Maintain a compact record for each strategically relevant alternative, adjacent team, supplier, or potential collaborator. Record what problem it solves, where it overlaps, where it complements you, the evidence for its capabilities, when that evidence was checked, and the decision it might change.

Keep observations separate from conclusions:

“Their current implementation demonstrated X on workload Y” is an observation.

“We should use it rather than maintain our own component” is a decision that needs additional reasoning.

An agent can gather evidence and propose changes to your assessment. It should not turn marketing claims into verified capability, or repeatedly summarize an old assessment until it appears current.

Compete on complete outcomes

I would evaluate alternatives against the same representative tasks and constraints as your own system.

That includes semantic correctness, supported workload breadth, integration effort, diagnostics, operational limits, evolution policy, support burden, and the human effort required to get a dependable result. Not just feature counts or an impressive demonstration.

Be willing to conclude that another team or supplier does a particular part better. Stewardship does not require implementing everything yourself. Sometimes the strongest position is to own the shared semantics and integration contract while cooperating on implementation.

Within the company, I would define “dominate” as being the default choice because you reliably make other teams successful, not making alternatives politically impossible.

That suggests investing in runnable integration examples, clear limitations, useful diagnostics, predictable responses, and an accessible contribution process as seriously as you invest in advanced catalog capabilities.

The defensible asset I would build is accumulated, validated domain knowledge that can be applied quickly—not knowledge that remains inaccessible in two people’s heads.

8. Measure whether this is actually reducing dependence on you

The measures should expose whether agents are creating leverage or merely creating more material to supervise.

I would use a small scorecard:

Question	Useful measure
Are other teams getting useful answers?	Time to first substantive response; unresolved request age
Are we delivering dependable outcomes?	Accepted request to verified consumer outcome
Are agents reducing human effort?	Human intervention time per accepted change, including rework
Are constraints holding?	Escaped semantic regressions, compatibility failures, policy violations
Is integration becoming easier?	Time and assistance needed for a consumer’s first successful workflow
Is knowledge becoming durable?	Repeated explanations required; recurring bugs; tasks completed correctly from recorded context

For a team your size, inspect the actual cases as well as the numbers. A single severe semantic failure matters more than a flattering average across dozens of trivial changes.

I would also perform a periodic cold-start test: give a fresh agent—or the other human—a representative task using only the recorded materials. Can they identify the relevant constraints, find the right evidence, recognize uncertainty, and produce an acceptable result?

That is a direct test of whether the operating model works without the expert acting as an undocumented dependency.

9. Start with one complete workflow, not a platform-building detour

I would introduce this through real work in three passes.

First, establish the minimum authoritative structure. Write the short charter, create the shared work ledger, identify the most frequently repeated domain rules, and publish an honest capability-and-limitations view. Assign owners and distinguish accepted material from proposals.

Second, take one consequential incoming request through the complete flow. Capture its domain assumptions, approve the necessary contract, add representative and adverse cases, delegate a bounded implementation, verify it independently, and produce a consumer-facing result. Fix the missing links you encounter rather than designing every possible workflow in advance.

Third, automate the repeated parts and expand autonomy. Generate context packages, enforce contract references and required checks, assemble evidence, maintain the capability view, and draft status updates. Expand to additional task classes only after the first workflow demonstrates that it saves human effort without hiding mistakes.

I would avoid starting with a custom knowledge graph, a large agent orchestration framework, a comprehensive policy language, or hundreds of pages of aspirational standards. Structured files, ordinary code, a fixture corpus, your existing issue system, and a few trustworthy checks are enough to establish the model.

The architectural ambition can still be substantial. The initial machinery should be modest.

The central change is this: your team should remain accountable for meaning, promises, and evolution, while making more of the work between those decisions independently executable and verifiable.

A bug should improve the corpus. A difficult explanation should improve the domain model. An integration should improve the shared contract. A review correction should improve either the checks or the recorded guidance. A management discussion should clarify a priority or commitment.

That is how the advantage compounds. You stop being merely the people who know how the catalog system works and become the team that maintains the company’s most reliable account of how it works—and the machinery that keeps that account true.

Sources
https://www.zenml.io/llmops-database/long-running-agent-harness-for-multi-context-software-development?utm_source=chatgpt.com

This link seems potentially interesting: https://arxiv.org/pdf/2604.21003


We should see if we can convert it to the nlspec format or the rfc-llm spec.
