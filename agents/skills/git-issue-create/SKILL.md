---
name: issue-create
description: Turn a user-reported problem into a high-resolution, intent-only issue document that a separate implementation session can implement from without degradation
---

# Issue Create

Use this skill when the user brings a problem or feature idea and implementation will happen later, possibly in a separate session. The deliverable is one issue document. No code changes in this phase.

## Core principle: the issue is intent, not a spec

Keep in the issue:

- The problem and why it matters
- Verified facts from investigation: commands, actual outputs, code paths read
- Expected behavior as stated by the user
- Change locations derived from code investigation
- Security or safety considerations when relevant

Leave out of the issue:

- Implementation design (which functions to add, how to structure code) — that is the implementation session's job
- Unverified assumptions
- Conversation-local context another reader cannot decode

Quality bar: a fresh session with only this document and the repo produces the correct change with minimal tokens and no degradation. Later, a reviewer compares the code diff against this document to confirm the intent was honored.

The document must be human-readable, not just agent-readable. Anything that only makes sense with conversation history is a defect.

## Workflow

1. **Hear the problem.**
   - Let the user state the problem and goal. Do not start writing yet.
2. **Investigate and record facts.**
   - Reproduce with the smallest command that shows the problem. Record the exact command and its actual output.
   - Check nearby options that look like fixes but are not (e.g. a flag that applies to a different layer). Verify and record why each fails to solve it.
   - Verify at least one direction that does work, with the same rigor. This anchors the fix without designing it.
3. **Elicit expected behavior from the user.**
   - Ask what the expected behavior should be: configuration shape, defaults, how missing/false/true/conflicting values behave.
   - The user decides; the agent does not invent.
4. **Determine change scope from the code.**
   - If exist `.serena/memories/` and `ARCHITECTURE.md`, Read `.serena/memories/` and `ARCHITECTURE.md` first, then the actual code. If don't some file, please read actual code.
   - List the exact files that will change, and state why analogous changes are NOT needed when a shared helper already covers them (negative scope).
5. **Write the document**
   - following the structure below.

## Document structure

Save as `docs.local/YYYY-MM-DD_issue-<slug>.md`.

- **Summary** — the problem in a few sentences: symptom, environment, root-cause direction. Facts only.
- **Reproduction** — exact commands with actual outputs: the failure, the near-miss option that does not work (and why), and the working direction. Note whether the reproduction requires or transmits any secrets.
- **Proposed configuration** (name per content, e.g. "Proposed behavior") — the expected behavior elicited from the user, with a concrete example. Spell out behavior for every value state: missing, `false`, `true`, and conflicting combinations.
- **Implementation scope** — exact files to change, derived from code investigation. Include negative scope.
- **Security consideration** — when the change touches trust, auth, or verification, state the safer alternative it enables.

## Quality checklist

- [ ] Every claim in Summary/Reproduction was verified in this session
- [ ] Expected behavior came from the user, not inferred
- [ ] A separate session could implement from this document alone
- [ ] A reviewer can diff the code against this document and judge intent
- [ ] Nothing depends on conversation history or agent-internal shorthand
- [ ] All commands and outputs are verbatim and reproducible
