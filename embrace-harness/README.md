# Local Embrace Harness

Tokenless local test harness for `/octo:embrace`.

This is not an upstream deliverable. It exists to make Embrace fixes fast,
repeatable, and cheap before opening any PR.

## Run

```bash
~/.claude-octopus/local/embrace-harness/run
```

By default the harness targets:

```bash
~/.claude-octopus/plugin
```

To test another checkout:

```bash
OCTO_PLUGIN_ROOT=/path/to/claude-octopus ~/.claude-octopus/local/embrace-harness/run
```

To run one scenario:

```bash
~/.claude-octopus/local/embrace-harness/run tangle-failed-stops-deliver
```

## Real Embrace Guard

For debugging, do not run provider-backed Embrace directly. Use the harness.

If a debug script must call `orchestrate.sh embrace`, set:

```bash
OCTOPUS_EMBRACE_REQUIRE_ALLOW_REAL=1
```

With that guard active, the runner exits before provider bootstrap unless the
operator deliberately sets:

```bash
OCTOPUS_ALLOW_REAL_EMBRACE=1
```

`OCTOPUS_EMBRACE_VALIDATION_ONLY=1` provides the same refusal behavior.

## What It Guarantees

- No real Codex, Gemini, or Claude provider is called.
- Each run uses an isolated temporary HOME and workspace.
- Artifacts are written under `runs/<timestamp>/`.
- Scenarios assert orchestration contracts, not LLM quality.

## Scenarios

- `success-artifacts`: full run must write phase and gate artifacts.
- `tangle-failed-stops-deliver`: failed Tangle must preserve validation and block Deliver.
- `requested-gate-required`: requested gate without artifact must fail before Develop.
- `gemini-quota-fallback`: Gemini quota exhaustion must degrade through fallback artifacts.
- `codex-stderr-usable`: Codex exit 0 with useful stderr must be degraded usable output.
- `embrace-command-uses-unified-runner`: `/octo:embrace` must delegate to the unified runner.
- `codex-gate-exit2-fallback`: Codex gate exit 2 must be traced while other providers can satisfy the gate.
- `smoke-enabled-completes`: provider smoke tests must complete non-interactively.
- `gemini-trust-failure-classified`: Gemini trusted-directory failures must be classified as `GEMINI_TRUST_REQUIRED`.
- `single-provider-consensus-label`: partial consensus must not be mislabeled as manual-review failure or provider degradation.
- `compact-fallback-bounds`: fallback artifacts must stay compact and must not attach raw dumps.
- `final-report-artifact-inventory`: successful Embrace reports must derive phase status from captured artifacts and provider ledger.
- `failed-report-artifact-inventory`: failed Embrace reports must preserve failure reason, provider status, and partial artifacts without claiming delivery.
- `stale-artifact-scoping`: phase/gate checks and final reports must ignore stale artifacts from previous task groups.
- `codex-true-empty-output`: Codex exit 0 with no stdout and no recoverable stderr must fail distinctly and block Deliver.
- `claude-provider-failure`: Claude review failure must be visible in provider accounting and must not produce a false-positive delivery.
- `low-deliver-score-stops`: low Deliver scorecard dimensions must stop before writing `delivery-*.md`.
- `agent-status-terminal-wins`: stale `running` records must not override terminal provider statuses or output files.
- `shell-syntax-guard`: Embrace-critical shell files must pass `bash -n` and avoid Bash 4-only case expansion.
- `tangle-worker-evidence`: Tangle validation must catch missing worktree changes, missing explicit file coverage, and weak subtask instructions.
- `tangle-empty-decomposition`: empty/unparseable decomposition must use direct Tangle fallback with original constraints.
- `tangle-deadline-timeout`: stalled Tangle workers must honor the deadline/done-marker timeout path.
- `probe-synthesis-fallback`: Probe synthesis provider failure must produce compact fallback output.
- `ink-synthesis-fallback`: Ink synthesis provider failure must produce compact fallback delivery.
- `codex-compat-guard`: Codex command syntax and generated skill compatibility checks must stay green.
- `gemini-status-canonical`: Gemini quota/lockout skips in requested gates must use canonical `failed` wording.
- `consensus-quality-status-boundary`: partial consensus quality must stay distinct from provider status wording.
- `real-run-guard`: guarded validation/debug invocations must abort before provider bootstrap unless real Embrace is explicitly authorized.

If a scenario fails, fix the runner or provider classification. Do not run a real
Embrace to debug the contract.
