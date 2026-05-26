# Embrace Restart Packet — 2026-05-27

This file is the restart source of truth for continuing Octo Embrace stabilization after a machine reboot or a new Codex session.

## Mission

Keep stabilizing Octo Embrace without losing the value of the prior debugging work. Do not jump to upstream PRs or a heavy CoproOS Embrace yet. The priority is to turn remaining real-run residuals into deterministic tokenless harness coverage, then validate with one more small real canary.

## Saved Branches

Primary code branch in the user fork:

- repo: `/Users/sourouche/.claude-octopus/install/embrace-stability-stack`
- branch: `install/embrace-stability-stack`
- remote: `origin git@github.com:SouroucheB/claude-octopus.git`
- latest pushed commit: `1264ba1 docs: record embrace validation next steps`
- previous merge checkpoint: `b119cf7 Merge upstream/main into embrace-stability-stack`
- status at save time: worktree clean, branch ahead of `upstream/main`

Harness backup branch in the same fork:

- remote branch: `origin/backup/embrace-harness`
- commit: `b016ed9 backup: embrace harness ledger and scenarios`
- contains: ledger, harness runner, lib, scenarios
- intentionally excludes: `runs/` artifacts, provider transcripts, heavy logs

## Local Source Paths

- Active Octo checkout: `/Users/sourouche/.claude-octopus/install/embrace-stability-stack`
- Active plugin symlink target: `/Users/sourouche/.claude-octopus/plugin` -> `install/embrace-stability-stack`
- Local harness: `/Users/sourouche/.claude-octopus/local/embrace-harness`
- Ledger: `/Users/sourouche/.claude-octopus/local/embrace-harness/EMBRACE_BUG_LEDGER.md`
- Latest real canary repo: `/private/tmp/octo-embrace-canary-b119cf7` (may not survive reboot)
- Latest real canary log: `/private/tmp/octo-embrace-canary-b119cf7.log` (may not survive reboot)

## Proven Signals

Tokenless/local validation:

- Local harness: `34/34` passing
- Latest harness run: `runs/20260526-175346`
- Codex compatibility: `98/98` passing
- Targeted Embrace/Tangle/Ink/Probe tests passed after upstream merge

Real-provider validation:

- Real canary run id: `1779828291`
- Code commit under test: `b119cf7`
- Exit code: `0`
- Duration: `534s`
- Artifacts produced: Probe, Grasp, requested Define gate, Tangle validation, Ink delivery, Embrace report
- Tracked diff: only `canary.txt`
- Exact requested mutation: appended `embrace-canary-b119cf7`
- Gemini quota/degraded path did not block delivery
- Ink file-only scorecard dimensions were `not applicable`

Current interpretation:

- Embrace is repaired on the known critical orchestration contracts and validated by a minimal real canary.
- Embrace is not yet certified for a heavy CoproOS run.

## Remaining Residuals

Two non-blocking residuals from real canary `1779828291` must be handled carefully:

1. Context leakage: previous high-importance canary observations still leaked into new Probe/Grasp/Tangle context.
2. Provider status wording: Gemini appeared as both `failed` and `degraded` across artifacts.

These did not break the canary. Do not rush a live-path fix without a deterministic failing scenario.

## Next Work Order

Do this next:

1. Inspect the ledger entries around `1779828291` and the existing scenarios `280-observation-scope.sh`, `290-context-hygiene.sh`, and provider-status scenarios.
2. Add or extend tokenless harness scenarios to reproduce the two residuals.
3. Confirm the new scenarios fail against current behavior if possible.
4. Apply the smallest fix only after the reproduction exists.
5. Run targeted tests plus the full local harness.
6. Only then prepare a second real validation: isolated read-only/audit canary, not heavy CoproOS.

Do not do this yet:

- Do not open upstream PRs.
- Do not run a heavy CoproOS Embrace.
- Do not mutate CoproOS product worktree.
- Do not fix context/status residuals directly without a harness scenario.
- Do not push `runs/` logs or raw provider transcripts.

## Commands To Verify After Restart

```bash
cd /Users/sourouche/.claude-octopus/install/embrace-stability-stack
git status --short --branch
git log --oneline -5 --decorate
git ls-remote --heads origin install/embrace-stability-stack backup/embrace-harness
```

Expected:

- current branch: `install/embrace-stability-stack`
- latest local commit: `1264ba1`
- no worktree changes unless new work was started
- remote branch `origin/install/embrace-stability-stack` exists
- remote branch `origin/backup/embrace-harness` exists

Run local validation before any real-provider run:

```bash
/Users/sourouche/.claude-octopus/local/embrace-harness/run
```

Expected: `34 total, 34 passed, 0 failed` unless new scenarios have been added intentionally.

## Candidate Files For Next Fix

Likely relevant files in the Octo checkout:

- `scripts/lib/workflows.sh`
- `scripts/lib/heuristics.sh`
- `scripts/lib/error-tracking.sh`
- `scripts/lib/testing.sh`
- `scripts/lib/embrace.sh`
- `scripts/orchestrate.sh`
- local harness scenarios under `/Users/sourouche/.claude-octopus/local/embrace-harness/scenarios/`
- ledger `/Users/sourouche/.claude-octopus/local/embrace-harness/EMBRACE_BUG_LEDGER.md`

## Exact Prompt For The Next Codex Session

Paste this to resume naturally:

```text
On reprend Octo Embrace stabilization après reboot. Source de vérité: /Users/sourouche/.claude-octopus/install/embrace-stability-stack/docs/superpowers/plans/2026-05-27-embrace-restart-packet.md. Lis ce fichier puis vérifie git status/log et le ledger local /Users/sourouche/.claude-octopus/local/embrace-harness/EMBRACE_BUG_LEDGER.md. Ne touche pas à CoproOS. Ne lance aucun vrai Embrace/provider run. Objectif: qualifier les deux résidus du canary réel 1779828291 (context leakage des anciennes observations, wording Gemini failed/degraded) avec des scénarios tokenless dans le harness, test rouge d'abord, fix minimal ensuite, puis harness complet.
```

## User Intent Snapshot

The user is frustrated by prior quota burn and wants a definitive, structured path to fix Embrace. The current confidence level improved substantially only after the real canary `1779828291` passed. The user explicitly does not want upstream PR work yet. The next session should preserve momentum and avoid broad or speculative changes.
