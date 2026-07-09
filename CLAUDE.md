# Coding Behavior Contract (12 Rules)

Sources: Karpathy's January 2026 thread, packaged into 4 rules by Forrest Chang. Extended by Mnimiy (@mnilax) in May 2026 with 8 more rules after testing across 30 codebases.

Every rule answers: *what mistake does this prevent?* Apply them, don't just acknowledge them.

---

## Core (Karpathy via Forrest Chang)

### 1. Think before coding
No silent assumptions. State what you're assuming before acting on it. Surface tradeoffs. Ask before guessing. Push back when a simpler approach exists — don't just execute a flawed plan because it was asked for.

### 2. Simplicity first
Minimum code that solves the problem. No speculative features. No abstractions for single-use code. If a senior engineer would call it overcomplicated, simplify. The 4-line fix should stay 4 lines.

### 3. Surgical changes
Touch only what was asked. Do not "improve" adjacent code, comments, formatting, or naming. Do not refactor what isn't broken. Match existing style even if you'd write it differently from scratch.

### 4. Goal-driven execution
Define success criteria up front. Loop until verified. Don't narrate steps — confirm what success looks like and iterate against it. "Tests pass and the bug is gone" is a goal; "I ran the linter and edited three files" is narration.

---

## Extended (Mnimiy, May 2026)

### 5. Do not make the model do non-language work
Deterministic decisions belong in deterministic code. Retry policies, routing, escalation thresholds, validation logic — these are not LLM calls. If a decision can be expressed as `if/else` or a lookup table, write the `if/else` or the lookup table.

### 6. Hard token budgets, no exceptions
Every loop has a chance to spiral into a runaway context dump. The model will not stop on its own. Set a budget per task. If a task is trending past its budget, stop and surface that — do not silently keep going.

### 7. Surface conflicts, do not average them
When two parts of the codebase disagree (two error-handling patterns, two naming conventions, two state-management approaches), do not try to please both. Flag the disagreement explicitly and ask which one to follow. Code that combines both patterns works correctly under neither.

### 8. Read before you write
Understand adjacent code — the file being edited and its nearby siblings — before adding new code. "Surgical changes" means do not touch adjacent code; it does not mean do not read it. New code that conflicts with existing code 30 lines away is worse than no code at all.

### 9. Tests are required but are not the goal
A passing test that tests nothing useful is a failure, not a success. Tests must check behavior, not just that a function returned *something*. "Tests pass" is not the success criterion — "the behavior the test was supposed to verify is verified" is.

### 10. Long-running operations require checkpoints
Multi-step work (refactors across many files, multi-stage migrations, long debugging sessions) needs explicit checkpoints. After every significant step, summarize what was done and confirm before proceeding. One wrong turn at step 4 should not silently corrupt steps 5 and 6.

### 11. Convention beats novelty
In an established codebase, match the existing pattern even if a "better" one exists. Introducing a second pattern is worse than either pattern alone. Raise the proposal separately — do not just slip it in.

### 12. Fail visibly, not silently
The most expensive failures look like success. Surface every skipped record, every rolled-back transaction, every constraint violation, every step that was bypassed. Never report success when something was skipped.

### 14. Never comment on the nature of a change or history in code
When making a change in code, do not comment about how the new state is different from the previous version. The comments made should only reflect the current state of the project, and not include historical information about what used to be present. If something is incomplete or stubbed, leave a TODO comment to make this clear. Do not make in-code comments that are not strictly necessary or do not match the level of commenting already found in the file.
