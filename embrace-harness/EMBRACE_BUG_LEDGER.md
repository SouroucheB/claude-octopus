# Embrace Bug Ledger

Local-only tracking for Embrace stabilization. This file is not an upstream PR artifact.

## Source Of Truth

- Active plugin: `/Users/sourouche/.claude-octopus/install/embrace-stability-stack`
- Local harness: `/Users/sourouche/.claude-octopus/local/embrace-harness`
- Latest full harness pass: `runs/20260527-223623` — 39/39 passing
- Evidence mined from: CoproOS `.claude/embrace-report-20260520.md`, active plugin commit log, historical Octo worktrees, local harness artifacts, and existing `~/.claude-octopus/results/**` / `runs/**` artifacts.
- Latest upstream merge validation: `b119cf7` (`Merge upstream/main into embrace-stability-stack`) with syntax checks, targeted Embrace/Tangle/Ink/Probe tests, Codex compat 98/98, and local harness 34/34.
- Latest real canary validation: `1779883055` on `eeedf6f` completed end-to-end in 745s with Probe, Grasp, requested Define gate, Tangle validation, Ink delivery, canonical final Gemini `failed` status, and only `canary.txt` modified among tracked files.
- Latest real full validation: `1779917379` on `0988399` completed end-to-end in 1095s with Probe, Grasp, both requested debate gates, Tangle validation, Ink delivery, canonical final Gemini `failed` status, and tracked diff limited to `validation.txt`. It validated E79/E80 in reality: no injected `Relevant High-Importance Observations` block for old full-run observation `D-1779900159-33689`, no raw `skill-tdd` / TDD skill block in current-run artifacts, and Codex stderr prompt echoes were replaced with `[codex user prompt omitted from stderr transcript]`. Notes: a read-only sandbox write block occurred in Probe, where read-only enforcement is expected; the `WARNING: worker codex-2 timed out...` text was a hypothetical Probe risk pattern, not a Tangle timeout (`Provider timeouts: 0/1`, `Evidence-backed timeouts: 0/0`).

## Exhaustiveness Policy

This ledger is the current local source of truth, but it is not treated as permanently exhaustive. Any newly observed Embrace failure must be added here before or during the fix. The rule is: no Embrace fix without either a ledger entry or an explicit decision that it is out of scope.

## Backlog / Soon

- [LATER] Add Embrace-internal context packing / prompt compression after the next real full run. Current upstream RTK integration optimizes Claude Code Bash/tool output via `rtk hook claude`, while Embrace provider prompts are mainly protected by generic `enforce_context_budget()` summarize/truncate behavior. Before implementing, use a real full Embrace run to identify the actual burn points, then add a structured packer that deduplicates and bounds observations, artifacts, stderr/logs, reports, and phase context with an audit trail of kept/omitted blocks.

## Recovered Evidence From Artifact Mining

- CoproOS Embrace run `79fd57f7-4de2-4619-bb92-fb4a1e6d13d6` produced Probe/Grasp/Tangle/Deliver artifacts but no `embrace-gate-*.md` artifacts, even though gates were requested.
- CoproOS report `.claude/embrace-report-20260520.md` said no probe synthesis was generated, but `probe-synthesis-1779231795.md` exists. Final reporting can contradict the artifact set.
- Several `grasp-consensus-*.md` and `delivery-*.md` artifacts start with `[Auto-consensus failed - manual review required]` even when a single provider produced usable output. This is a partial-consensus condition, not necessarily a failed consensus.
- Multiple Gemini artifacts fail with the trusted-directory/headless error: "Gemini CLI is not running in a trusted directory" and exit code 55.
- Multiple Gemini artifacts fail with quota errors / 429 / `TerminalQuotaError`; these failures can recur across phases.
- Historical Probe fallback artifacts still contain `[Auto-synthesis failed - raw findings below]`; some are thousands of lines, and one delivery artifact reached 175,916 lines.
- Recurring Codex `FAILED (Empty output)` appears in Tangle/Delivery artifacts. E05 covers useful stderr, but true empty-output cases still need explicit fallback/reporting.
- Real canary run `1779392842` showed a direct/unsafe Tangle fallback can complete the file edit but return before `tangle-validation-*.md`, causing Embrace to stop at Tangle with no validation artifact.
- Real canary run `1779392842` showed absolute `Files: /private/tmp/.../canary.txt` scopes were treated as missing write scopes, forcing unnecessary direct fallback.
- Real canary run `1779395773` showed `grasp_define` can mutate the worktree during Define: the consensus artifact says `Updated canary.txt...` before Tangle started.
- Real canary run `1779395773` showed Tangle validation can report `FAILED` despite 100% successful workers when the target change already exists before the Tangle snapshot.
- Real canary run `1779401482` completed end-to-end with both requested gate artifacts, Tangle validation, Ink delivery, and an exact one-file diff (`canary.txt` only; `README.md` unchanged).
- Real canary run `1779401482` showed inline root-file scopes such as `Files: canary.txt` were not recognized as explicit write scopes, forcing unnecessary direct fallback.
- Real canary run `1779401482` still surfaced non-blocking orchestration defects: `sed: RE error: illegal byte sequence` during Ink, `Autonomy: semi-autonomous` despite an autonomous env request, and old high-importance observations leaking into an unrelated canary task.
- Real `/octo:embrace` CoproOS audit run `1779436036/1779436681` stayed source-read-only but still injected unrelated `Earned Project Skills` and `Provider History` into probe prompts, including a previous canary workflow skill.
- Real `/octo:embrace` CoproOS audit run `1779436036` still spent minutes on a recurring Gemini rate-limit path (`429` / rate-limit wording) before falling back; the live quota watcher recognized only older quota strings.
- Real canary run `1779444676` spent about 4m40 in Gemini smoke after a 429/rate-limit before entering degraded mode; the portable timeout fallback only sent TERM and did not hard-kill TERM-resistant CLIs.
- Real canary run `1779444676` stopped after supervised Probe, but Codex modified `canary.txt` during the Discover phase despite prompt-level read-only policy. Prompt RBAC alone is insufficient for CLI providers.
- Real canary run `1779613311` detected Gemini quota/rate-limit during provider smoke, but Probe still launched two real Gemini research tasks; both burned the full 600s retry loop before later phases skipped Gemini.
- Real canary run `1779617272` showed Probe/Tangle parallel `spawn_agent` paths still inherit the global 600s timeout, even though sync agents already have dynamic provider caps; canary-small Codex/Sonnet calls burned full 600s windows.
- Real canary run `1779617272` showed Probe progress can remain at 0/N until provider PIDs exit even after terminal `## Status:` result artifacts exist, making ETA misleading and extending waits to timeout boundaries.
- Local conformance replay showed the portable `run_with_timeout` fallback can hold a downstream `tee` pipeline open until timeout because the monitor process inherits stdout.
- Real canary run `1779617272` showed an anti-sycophancy reviewer timeout can still be displayed as "passed", hiding that the high-pass validation was not actually challenged.
- Real canary run `1779623567` showed Probe semantic caching still tries to write under `/.cache/probe-results` when `CACHE_DIR` is initialized before `WORKSPACE_DIR`, causing read-only filesystem noise after Probe synthesis.
- Real canary run `1779623567` showed the Define→Develop gate artifact can contain a blocking `REVISE` / "NE PAS ENTRER EN DEVELOP" verdict while Embrace still proceeds into Tangle.
- Real canary run `1779623567` showed Tangle write-scope validation ignores multi-line subtask scope clauses like `Files: canary.txt only.`, forcing unnecessary unsafe direct fallback.
- Real canary run `1779627358` showed the new debate-gate enforcement can fail closed on a self-referential blocker: the gate asks for the current-run `embrace-gate-define-develop-*.md` before the runner has written the gate artifact it is producing.
- Real canary rerun `1779630870` showed Probe cache hit handling still reconstructed the cached file with raw `${CACHE_DIR}/${cache_key}.md`, producing `/<hash>.md` when `CACHE_DIR` was unset. The runner then claimed "Synthesis retrieved from cache" even though no synthesis file existed.
- Real canary run `1779639565` showed the required `canary.txt` implementation succeeded, but Tangle failed at 25% because three `[REASONING]` Gemini subtasks were quota-skipped and counted as implementation failures.
- Real canary run `1779642266` showed E56 fixed Tangle scoring in reality, then Ink failed because the pre-delivery reviewer penalized future `delivery` absence and forced non-applicable Accessibility into a numeric low score.
- Real canary run `1779645088` showed E57 fixed explicit `N/A` parsing, but Ink still failed because the reviewer returned numeric low scores (`5/10`) for non-applicable file-only dimensions; applicability must be inferred deterministically from changed paths, not trusted to the LLM.
- Real canary run `1779647077` showed the Define→Develop debate gate can synthesize an explicit `PROCEED_WITH_RISKS` verdict, then still fail closed because the parser scans non-blocking risk prose for words like `bloqué` instead of honoring the explicit verdict first.
- Real canary run `1779657621` on commit `369d367` completed end-to-end with requested Define gate, Tangle validation, Ink delivery, deterministic non-UI score masking (`sec=NA rel=7 perf=NA acc=NA`), and only `canary.txt` modified in the tracked worktree.
- Real canary run `1779688607` on commit `553d57b` completed end-to-end with requested Define gate, explicit Codex gate timeout (`codex=timeout`, `claude=ok`, `gemini=failed`), Tangle validation, Ink delivery, deterministic non-UI score masking (`security/performance/accessibility=N/A`, `reliability=8/10`), and only `canary.txt` modified in the tracked worktree.
- Real canary run `1779714610` on commit `efc4b34` reached Ink with only `canary.txt` modified and deterministic masking set Security/Performance/Accessibility to `N/A`, but still failed because a subjective `Reliability 5/10` score was considered applicable to a non-runtime text-only diff.
- Real canary run `1779717723` on commit `b878e80` completed end-to-end with requested Define gate, Gemini quota lockout skipped in later phases, Tangle validation, Ink delivery, all scorecard dimensions `N/A` for the file-only diff, and only `canary.txt` modified in the tracked worktree.
- Real non-canary Octo audit run `1779718662` after commit `b878e80` hit Claude session limit in Probe and exposed a Probe synthesis bug: `codex-probe-1779718662-0.md` contained a useful scoped audit report, but the synthesis excluded it because the report quoted `octo_provider_rejection_pattern` source text (`context limit`, etc.) and because the provider status was degraded.
- Real non-canary Octo audit run `1779734552` after commit `e104223` reached Define→Develop, then failed with `Embrace debate gate 'define-develop' produced no provider output` even though `agents.jsonl` recorded Codex gate `tokens_out=566` before `Codex tool stdin closed`. Gate provider output from non-zero exits was discarded before artifact materialization.
- Real non-canary Octo audit run `1779752442` after commit `260975c` reached Tangle with Probe, Grasp, and requested Define→Develop gate artifacts present, then failed Tangle despite `Success Rate: 100%` and `Decision Branch: proceed` because `validate_tangle_results` treated read-only audit evidence files (`scripts/lib/workflows.sh`, `scripts/lib/heuristics.sh`, `scripts/lib/error-tracking.sh`) as missing explicit file coverage. This also consumed heavy Claude quota through a full real Embrace path before exposing the bug.
- After repeated non-canary real-audit attempts consumed high Claude quota before exposing late orchestration bugs, Embrace debugging needed an explicit real-run guard so validation-only/debug invocations fail before provider bootstrap unless `OCTOPUS_ALLOW_REAL_EMBRACE=1` is deliberately set.
- Post-run process inspection after `1779688607` found no `tail -f octo-gemini-stderr.*` process started on May 25, 2026; remaining orphaned tails are historical pre-fix processes from May 18-24.
- Real non-canary Octo audit run `1779689993` on commit `553d57b` did not inject a top-level `Relevant High-Importance Observations` block, stayed tracked-worktree clean, and wrote an explicit failed report after stopping at the requested Define→Develop gate.
- Real non-canary Octo audit run `1779689993` exposed new residual issues: provider smoke/preflight did not run before Probe, two Gemini Probe threads spent ~272s before quota failure, Codex timed out in Probe then failed Define with `Codex tool stdin closed`, and both Codex/Claude gate providers timed out at the fixed 90s gate cap, producing no gate artifact.
- Real Octo audit run `1779661218` on commit `369d367` exposed a realistic gate-path hang: the Define→Develop gate reached `claude --print --model sonnet` and remained stuck until operator kill; the gate artifact materialized only after interruption and the runner had no clean failed-run report.
- Real Octo audit run `1779661218` advanced past Probe/Discover with only 2/6 provider threads completed; Codex probe entries remained in `Waiting` state and Gemini failed, yet Grasp/Define proceeded from the partial synthesis without clear terminal accounting.
- Real Octo audit run `1779661218` still injected unrelated previous canary observations into a real Octo audit prompt, despite E41/E42 coverage. The leakage path appears to be high-importance `scope=project-wide` observations.
- Real Octo audit run `1779661218` produced degraded Define material that confused the workflow context, including statements that the runner had not been invoked even though the text was generated inside an Embrace run.
- Historical process inspection during the `1779661218` investigation showed many orphaned `tail -f octo-gemini-stderr.*` processes from prior runs; provider stderr watchers may be leaking after failed or timed-out providers.
- Real canary run `1779828291` on merge commit `b119cf7` completed end-to-end with exit 0, all requested artifacts present, deterministic file-only Ink scores as `not applicable`, Gemini quota skip respected in Deliver, and tracked diff limited to `canary.txt`. Residual issues observed: prior canary high-importance observations still leaked into Probe/Grasp/Tangle context, and Gemini status wording appeared as both `failed` and `degraded` in different artifacts.
- Real canary run `1779883055` on commit `eeedf6f` completed end-to-end with exit 0, all requested artifacts present, tracked diff limited to `canary.txt`, and final report / gate / agent ledger consistently showing Gemini as `failed` because provider quota was exhausted earlier in the run. The run validated the E73/E74 fixes on the primary contract.
- Real canary run `1779883055` also exposed a non-blocking validation-language residual: Tangle reasoning artifacts still interpreted old Grasp fallback wording as a Gemini failed/degraded status mix, even though the canonical provider status fields were `gemini=failed`. Consensus quality must be distinguished from provider-status degradation in future checks.
- Real full validation run `1779899695` on commit `3f8a6ea` stopped cleanly at Tangle with an explicit failed report and artifact inventory. The primary tracked diff was correct (`validation.txt` only, adding `embrace-full-3f8a6ea`), and canonical provider status remained `gemini=failed`.
- Real full validation run `1779899695` exposed a new Tangle safety residual: the decomposition assigned runner-owned `.claude-octopus/` artifacts/state to the implementation worker (`Files: validation.txt, .claude-octopus/`). Codex then wrote local state/develop-deliver/ink-looking artifacts that contradicted the runner's actual captured phase state, while the runner final report correctly ignored those forged local claims and failed at Tangle.
- Real full validation run `1779899695` also showed the Codex implementation worker could time out after producing useful transcript evidence and the exact worktree diff. The timeout was scored as 0/1 implementation success even though Tangle detected `Worktree Change Evidence: validation.txt`; this is related but secondary to the unsafe runner-owned artifact write scope.
- Real full validation run `1779911084` on commit `3d5b720` completed end-to-end with exit 0, both requested gates, Tangle validation, Ink delivery, and an exact tracked diff (`validation.txt` only, adding `embrace-full-3d5b720`; `task.md` unchanged). Gemini remained canonical `failed - Provider quota exhausted earlier in this run`, and no worker timeout occurred.
- Real full validation run `1779911084` exposed that high-importance `scope=project-wide` observations from an earlier full validation still propagate across later full validations: observation `D-1779900159-33689` from `3f8a6ea` appeared in Grasp, Define→Develop gate, Tangle worker prompts, Develop→Deliver gate, and Delivery. The gate synthesis chose to proceed because the block was labelled as previous-session context, but this still violates the desired no-cross-run active context contract for validation prompts.
- Real full validation run `1779911084` also showed Codex stderr transcripts can still include `Agent Skill Context --- Skill: skill-tdd ---` despite the Octopus prompt instructing subagents to skip all skills. This did not affect the one-file delivery, but remains a non-blocking prompt-isolation residual.
- Real full validation run `1779917379` on commit `0988399` completed end-to-end with exit 0, both requested gates, Tangle validation, Ink delivery, and an exact tracked diff (`validation.txt` only, adding `embrace-full-0988399`; `task.md` unchanged). It validated the E79/E80 fixes: old full-validation observation `D-1779900159-33689` did not appear as an injected observation block, raw Codex prompt echoes were sanitized, and no actual `--- Skill: skill-tdd ---` / TDD skill body leaked into artifacts. Probe correctly enforced read-only sandboxing when Codex attempted a write during discovery. Tangle itself reported no provider timeout; the `worker codex-2 timed out` line was only a Probe edge-case example.

## Covered By Local Harness

| ID | Incident | Scenario | Status |
|---|---|---|---|
| E01 | Happy path must produce Probe, Grasp, Tangle, Deliver, and both requested gates | `010-success-artifacts.sh` | covered |
| E02 | Tangle failed must stop before Deliver | `020-tangle-failed-stops-deliver.sh` | covered |
| E03 | Requested gate with no usable provider output must stop before next phase | `030-requested-gate-required.sh` | covered |
| E04 | Gemini quota exhaustion must degrade/fallback without killing the whole run when other providers can proceed | `040-gemini-quota-fallback.sh` | covered |
| E05 | Codex stdout empty but useful stderr must be degraded success, not empty-output failure | `050-codex-stderr-usable.sh` | covered |
| E06 | `/octo:embrace` command must delegate to unified `orchestrate.sh embrace` runner | `060-embrace-command-uses-unified-runner.sh` | covered |
| E07 | Codex exit 2 during debate gates must be traced as provider failure while Gemini/Claude can satisfy the gate | `070-codex-gate-exit2-fallback.sh` | covered |
| E08 | Provider smoke test enabled must complete without TTY blockage | `080-smoke-enabled-completes.sh` | covered |
| E20 | Single-provider consensus must not be labeled as "Auto-consensus failed - manual review required" when fallback is acceptable | `100-single-provider-consensus-label.sh` | covered |
| E23 | Gemini headless trusted-directory failure must be classified explicitly instead of generic exit 55 | `090-gemini-trust-failure-classified.sh` | covered |
| E26 | Raw fallback artifacts must remain compact and must not leak legacy raw fallback markers | `110-compact-fallback-bounds.sh` | covered |
| E28 | Gemini quota and trust failures must be distinguished by cause, not only by exit code | `040-gemini-quota-fallback.sh`, `090-gemini-trust-failure-classified.sh` | covered |
| E09 | Final report must not contradict captured phase artifacts | `120-final-report-artifact-inventory.sh`, `130-failed-report-artifact-inventory.sh` | covered |
| E10 | Failed phases must still leave an inspectable run report | `130-failed-report-artifact-inventory.sh` | covered |
| E11 | Delivery/final summary must surface provider failures/degraded states | `120-final-report-artifact-inventory.sh`, `130-failed-report-artifact-inventory.sh` | covered |
| E25 | Provider fallback/status details must be surfaced in the final report | `120-final-report-artifact-inventory.sh`, `130-failed-report-artifact-inventory.sh` | covered |
| E32 | Artifact inventory must be first-class final report input | `120-final-report-artifact-inventory.sh`, `130-failed-report-artifact-inventory.sh` | covered |
| E12 | macOS/Linux/Bash drift must be caught for Embrace-critical touched paths | `190-shell-syntax-guard.sh`, `scripts/test-codex-compat.sh` | covered |
| E13 | Stale artifacts from previous runs must not satisfy current-run phase/gate checks | `140-stale-artifact-scoping.sh` | covered |
| E21 | Gemini quota exhaustion must not keep consuming Gemini calls across later phases/gates | `040-gemini-quota-fallback.sh` | covered |
| E22 | Claude/manual compensation must not hide runner failures | `060-embrace-command-uses-unified-runner.sh` | covered |
| E24 | Gemini quota retry storms must fast-fail and record quota state | `040-gemini-quota-fallback.sh` | covered |
| E27 | Stale `running` records must not override terminal provider statuses | `180-agent-status-terminal-wins.sh`, `tests/unit/test-agent-summary.sh` | covered |
| E29 | True Codex empty-output without recoverable stderr must stop before Deliver | `150-codex-true-empty-output.sh` | covered |
| E30 | Claude provider failures must be visible in provider accounting and block bad delivery | `160-claude-provider-failure.sh` | covered |
| E31 | Low Deliver scorecard dimensions must stop for explicit decision instead of completing | `170-low-deliver-score-stops.sh` | covered |
| E33 | The CoproOS missing-gate run must regress to current-run gate artifact requirements | `030-requested-gate-required.sh`, `140-stale-artifact-scoping.sh` | covered |
| E14 | Tangle worker output without required file changes must fail validation | `200-tangle-worker-evidence.sh` | covered |
| E15 | Empty/unparseable decomposition must fall back to direct Tangle execution | `210-tangle-empty-decomposition.sh` | covered |
| E16 | Stalled Tangle workers must honor deadline/done-marker timeout logic | `220-tangle-deadline-timeout.sh` | covered |
| E17 | Probe synthesis provider failure must write compact fallback, not raw dumps | `230-probe-synthesis-fallback.sh` | covered |
| E18 | Ink/delivery synthesis provider failure must write compact fallback delivery | `240-ink-synthesis-fallback.sh` | covered |
| E19 | Codex non-interactive syntax drift must stay blocked in commands/skills | `250-codex-compat-guard.sh` | covered |
| E34 | Direct/unsafe Tangle fallback must still run `validate_tangle_results` and produce `tangle-validation-*.md` | `210-tangle-empty-decomposition.sh`, `200-tangle-worker-evidence.sh` | covered |
| E35 | Tangle write-scope parser must accept absolute `Files:` paths from real CLI output | `200-tangle-worker-evidence.sh` | covered |
| E36 | Embrace Define and debate gates must be explicitly read-only and must not mutate the worktree | `260-non-develop-readonly.sh` | covered |
| E37 | Tangle validation must accept explicitly verified current worktree evidence and ignore Octopus internal artifact dirs | `200-tangle-worker-evidence.sh` | covered |
| E38 | Tangle write-scope parser must accept inline root-file `Files:` scopes such as `Files: canary.txt` | `200-tangle-worker-evidence.sh` | covered |
| E39 | Explicit autonomous mode must not be overwritten by source-time defaults or final reports | `120-final-report-artifact-inventory.sh`, `270-autonomy-mode-preserved.sh` | covered |
| E40 | Ink context sanitization must be byte-safe and must not emit `sed: RE error: illegal byte sequence` | `240-ink-synthesis-fallback.sh` | covered |
| E41 | High-importance observations must be relevance-filtered so unrelated historical sessions do not pollute canary prompts | `280-observation-scope.sh` | covered |
| E42 | `Earned Project Skills` and `Provider History` must not inject unrelated historical/canary context into Embrace provider prompts | `290-context-hygiene.sh` | covered |
| E43 | Real Gemini `429` / rate-limit wording must trigger live quota fast-fail and provider lockout, not wait for phase timeout | `300-gemini-429-fast-fail.sh`, `tests/unit/test-quota-watcher.sh` | covered |
| E44 | Provider smoke tests must hard-kill TERM-resistant rate-limit loops and classify `429` as `RATE_LIMITED` | `tests/unit/test-timeout-hard-kill.sh`, `tests/unit/test-smoke-rate-limit-fast-fail.sh` | covered |
| E45 | Embrace Probe/Discover must be enforced read-only by provider sandboxing, not only by prompt policy | `310-probe-readonly-no-mutation.sh`, `tests/unit/test-embrace-readonly-phases.sh` | covered |
| E46 | Provider smoke quota/rate-limit detection must lock out Gemini before Probe dispatch, not only after a phase provider failure | `320-smoke-quota-lockout-prevents-probe-gemini.sh`, `tests/unit/test-smoke-rate-limit-fast-fail.sh` | covered |
| E47 | Probe/Tangle parallel `spawn_agent` calls must honor dynamic per-provider timeouts instead of the 600s global default | `330-spawn-dynamic-timeout.sh`, `tests/unit/test-heartbeat-timeout.sh` | covered |
| E48 | Timed-out anti-sycophancy checks must be reported as unavailable/challenged, not as passed | `tests/unit/test-anti-sycophancy-timeout.sh` | covered |
| E49 | Probe progress must treat terminal result artifacts as completed instead of waiting only on provider PIDs | `010-success-artifacts.sh` | covered |
| E50 | Portable timeout fallback must not hold `tee` pipelines open until the timeout after providers already exited | `tests/unit/test-heartbeat-timeout.sh` | covered |
| E51 | Probe semantic cache must resolve under the current workspace, never frozen as `/.cache/probe-results` before `WORKSPACE_DIR` exists | `tests/unit/test-semantic-cache-path.sh` | covered |
| E52 | A requested Embrace debate gate with an explicit blocking verdict (`REVISE`, `STOP`, or equivalent) must write its artifact and stop before the next phase | `tests/unit/test-embrace-fail-fast.sh` | covered |
| E53 | Tangle write-scope parser must accept multi-line `Files:` clauses in decomposed subtasks | `tests/unit/test-tangle-write-scope-safety.sh` | covered |
| E54 | Debate gate enforcement must ignore self-referential blockers about the current gate artifact or future phase artifacts, while preserving real blocking `REVISE`/`STOP` verdicts | `tests/unit/test-embrace-fail-fast.sh` | covered |
| E55 | Probe cache hits must retrieve through the resolved cache path and must fall through to real Probe if the cached file cannot be materialized | `tests/unit/test-semantic-cache-path.sh` | covered |
| E56 | Tangle quality gate must score implementation workers separately from reasoning-only subtasks and must not count provider-lockout reasoning skips as implementation failures | `tests/unit/test-tangle-worktree-evidence.sh`, `tests/unit/test-tangle-write-scope-safety.sh` | covered |
| E57 | Ink pre-delivery review must not penalize the future delivery artifact and must exclude non-applicable dimensions like Accessibility from min-score blocking | `tests/unit/test-cross-model-review.sh`, `tests/unit/test-ink-compact-delivery.sh` | covered |
| E58 | Ink must deterministically mask non-applicable review dimensions from Tangle worktree paths even when the reviewer emits numeric low scores instead of `N/A` | `tests/unit/test-ink-compact-delivery.sh` | covered |
| E59 | Debate gate parser must honor explicit `PROCEED_WITH_RISKS` before scanning non-blocking risk prose for blocking keywords | `tests/unit/test-embrace-fail-fast.sh` | covered |
| E60 | Gate provider calls, especially `claude --print --model sonnet`, must honor a hard timeout and return a clean degraded gate result instead of hanging until operator kill | `tests/unit/test-embrace-fail-fast.sh` | covered |
| E61 | Probe terminal accounting must not proceed silently with providers left in `Waiting`; failed and timed-out agents must be rendered and counted as terminal at phase boundary | `tests/unit/test-agent-summary.sh` | covered |
| E62 | Observation relevance filtering must exclude old canary observations from unrelated real audits even when generic files such as `task.md` match | `tests/unit/test-embrace-observation-scope.sh` | covered |
| E63 | Interrupted or hung Embrace runs must leave an explicit failed report/artifact inventory instead of only partial state | `tests/unit/test-embrace-fail-fast.sh` | covered |
| E64 | Provider stderr watcher processes must be reaped promptly after provider completion, timeout, or abort | `tests/unit/test-gemini-provider.sh` | covered |
| E66 | Provider smoke/quota lockout must run before Probe in direct real-audit plugin worktrees, not only in some canary paths | `tests/unit/test-embrace-fail-fast.sh`, `320-smoke-quota-lockout-prevents-probe-gemini.sh` | covered |
| E67 | Codex non-interactive Define failures such as `Codex tool stdin closed` must remain visible in the Grasp consensus when Claude fallback succeeds | `tests/unit/test-grasp-define-fallbacks.sh`, `tests/unit/test-agent-summary.sh` | covered |
| E68 | Ink must treat non-runtime text/file-only diffs as not applicable for Reliability, so canary/orchestration-only runs are gated by exact Tangle evidence rather than subjective product-runtime scoring | `tests/unit/test-ink-compact-delivery.sh` | covered |
| E69 | Probe synthesis must keep meaningful degraded provider output and must not treat quoted rejection-pattern source code as a real provider rejection | `tests/unit/test-probe-compact-synthesis.sh` | covered |
| E70 | Debate gate providers that return non-zero after producing meaningful output must be counted as degraded participants and must still materialize a gate artifact | `tests/unit/test-embrace-fail-fast.sh` | covered |
| E71 | Tangle validation must distinguish read-only evidence/context files from write-scope files, and must not fail a 100% successful implementation gate solely because audited source files were not modified | `tests/unit/test-tangle-file-coverage.sh` | covered |
| E72 | Embrace debug/validation mode must refuse real provider-backed `/octo:embrace` before provider bootstrap unless explicitly authorized, while allowing the local conformance harness | `tests/unit/test-embrace-real-run-guard.sh`, `340-real-run-guard.sh` | covered |
| E65 | Requested debate gate must remain usable on real audit prompts by defaulting to a debate-scale provider timeout instead of the legacy 90s cap | `tests/unit/test-embrace-fail-fast.sh` | covered |
| E73 | Project-wide canary observations from old validation runs must not be injected into later canary prompts even when generic files such as `canary.txt` or `task.md` match | `280-observation-scope.sh` | covered |
| E74 | Gemini quota/lockout skips in requested Embrace gates must use canonical `failed` wording, not `degraded`, across gate and final report artifacts | `350-gemini-status-canonical.sh` | covered |
| E75 | Codex compatibility guard must not mutate the active plugin checkout while generating/checking portable root skills | `250-codex-compat-guard.sh` | covered |
| E76 | Consensus quality fallback wording must stay distinct from provider status, so partial Grasp consensus cannot be mistaken for Gemini `degraded` when canonical status is `gemini=failed` | `360-consensus-quality-status-boundary.sh`, `tests/unit/test-grasp-define-fallbacks.sh` | covered |
| E77 | Tangle decomposition/write-scope handling must never delegate runner-owned Octopus state, gate, validation, delivery, report, or artifact paths to implementation workers | `370-runner-owned-scope-guard.sh`, `tests/unit/test-tangle-write-scope-safety.sh` | covered |
| E78 | Implementation provider timeouts after useful transcript evidence and verified non-runner-owned worktree changes must warn and continue, while runner-owned artifact-only changes still fail | `380-tangle-timeout-evidence-warning.sh`, `tests/unit/test-tangle-worktree-evidence.sh` | covered |
| E79 | Project-wide Embrace debate-gate telemetry from previous full validations must not be injected into later validation runs as active high-importance observation context | `280-observation-scope.sh`, `tests/unit/test-embrace-observation-scope.sh` | covered |
| E80 | Codex stderr transcripts must not leak echoed prompt skill context such as `skill-tdd`, and Embrace subagents must not receive agent skill context by default | `390-codex-stderr-prompt-echo-sanitized.sh`, `tests/unit/test-agent-summary.sh`, `tests/unit/test-embrace-context-hygiene.sh` | covered |

## Dedicated Scenario Gaps

Remaining scenario gaps discovered by real non-canary Octo audit `1779689993`. E65, E66, and E67 are now covered locally.

## Still To Encode

No known Embrace residual remains unencoded after E80. The next residual, if any, should come from fresh real-validation evidence rather than speculation.

## Local Branch / Worktree Map

| Branch / Worktree | Purpose | Current Role |
|---|---|---|
| `install/embrace-stability-stack` | Active installed plugin branch | current source of truth |
| `fix/embrace-conformance-runner` | Old marketplace checkout with mixed conformance work | quarantined archive, not active |
| `fix/codex-exec-compat` | Codex CLI/stderr/TUI compatibility | historical source for Codex fixes |
| `fix/embrace-phase-fail-fast` | Stop on missing phase outputs | historical source |
| `fix/embrace-phase-fail-fast-20260519` | Enforce requested debate gates | historical source |
| `fix/probe-compact-synthesis-fallback` | Probe compact fallback | historical source |
| `fix/tangle-empty-decomposition-fallback` | Tangle fallback on empty decomposition | historical source |
| `fix/tangle-explicit-file-coverage` | Keep validation report and check file coverage | historical source |
| `fix/ink-compact-delivery` | Compact delivery context | historical source |
| `fix/tangle-subtask-context` | Guard tangle parallel write scopes | historical source |
| `fix/gemini-quota-fast-fail` | Gemini quota fast-fail/fallback | historical source, older/diverged |
| `fix/tangle-done-marker-completion` | Done-marker wait/deadline | historical source |

## Active Local Commits Of Interest

- `0988399 fix(embrace): isolate codex skill context transcripts`
- `f2eb5ca fix(embrace): filter runner gate observation telemetry`
- `3d5b720 fix(tangle): warn on timeout with verified evidence`
- `a10d172 fix(embrace): strip runner artifacts from tangle worker scope`
- `3f8a6ea fix(embrace): separate consensus quality from provider status`
- `8464b71 fix(embrace): guard real validation runs`
- `4b46520 fix(tangle): ignore read-only evidence in file coverage`
- `260975c fix(embrace): keep degraded gate output`
- `e104223 fix(embrace): keep meaningful degraded probe output`
- `b878e80 fix(embrace): mask reliability for file-only delivery`
- `efc4b34 fix(embrace): preserve grasp fallback reasons`
- `3f8131a fix(embrace): scale debate gate timeouts`
- `7f12c5b fix(embrace): force fresh provider smoke`
- `553d57b fix(embrace): reap gemini stderr watcher`
- `f67065f fix(embrace): report interrupted runs`
- `58947db fix(embrace): filter canary observation leakage`
- `74263ed fix(embrace): account terminal probe agents`
- `0f7c43e fix(embrace): bound debate gate provider calls`
- `c549636 fix(embrace): bound spawn timeouts`
- `68100ed fix(embrace): propagate smoke quota lockouts`
- `1ba976b fix(embrace): enforce readonly probe and hard-kill smoke`
- `e4fb91f fix(embrace): fast-fail gemini rate limits`
- `24f133f fix(embrace): suppress unrelated history context`
- `03816a3 fix(embrace): close remaining canary defects`
- `53cd186 fix(embrace): validate real canary regressions`
- `58cfe3b fix(embrace): close remaining ledger regressions`
- `4b0b4db fix(embrace): write artifact-derived run report`
- `fdc47cb fix(embrace): classify gemini failures clearly`
- `fc62548 fix(embrace): route command through unified runner`
- `f72ed1d fix(embrace): classify useful codex stderr as degraded`
- `945fb6d fix(embrace): enforce requested debate gates`
- `93d9122 fix(tangle): guard parallel write scopes`
