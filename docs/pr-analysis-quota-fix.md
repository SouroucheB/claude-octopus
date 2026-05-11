# PR Analysis — Gemini quota fast-fail & develop fixes

**Date :** 2026-05-03
**Session :** debug quota detection + fix gemini-exec.sh

---

## Contexte

`/octo:develop` mettait ~4min à échouer quand Gemini était en quota exhausted, bloquant toute la chaîne d'orchestration. Trois bugs distincts ont été identifiés et corrigés.

---

## PRs déjà ouvertes

### PR #338 — `fix/gemini-quota-fast-fail`
Contenu committé :
- `spawn.sh` — watcher quota fast-fail dans `spawn_agent` (+ fix `grep -cE` CodeRabbit)
- `agent-sync.sh` — même watcher ajouté dans `run_agent_sync` (commit `176cee3`)
- `dispatch.sh` — retrait du flag `--full-auto` déprécié (Codex v0.128.0)
- `workflows.sh` — fallback Codex dans `tangle_develop` si Gemini échoue

**Problème :** le watcher était fondamentalement cassé. Il surveillait `$temp_err` qui restait
vide pendant ~4min car `gemini-exec.sh` bufferisait la stderr de Gemini en interne et ne la
transmettait à sa propre stderr qu'à l'exit du process (après les 10 retries internes).

### PR #339 — `fix/octo-develop-infinite-loop`
- `octo-develop.md` — interdit à Claude d'implémenter en parallèle pendant `orchestrate.sh`

---

## Root cause analysis — la chaîne complète du bug

```
run_agent_sync("gemini", ...)
  └─ printf prompt | run_with_timeout ... >"$temp_out" 2>"$temp_err"
       └─ gemini-exec.sh gemini-2.5-pro -p "" ...
            └─ gemini -m gemini-2.5-pro ...
                 ├─ stdout → $stdout_file   (interne gemini-exec.sh)
                 └─ stderr → $err_file      (interne gemini-exec.sh)
                      "Attempt 1 failed: You have exhausted your capacity..."
                      "Attempt 2 failed: ..."   (× 10, ~4min total)
            └─ [exit 1 après 10 retries]
            └─ printf '%s' "$last_err" >&2   ← seulement ICI que la stderr sort
                 → $temp_err de run_agent_sync ← le watcher voit enfin quelque chose
```

Le watcher (toutes les 2s, max 300s) regardait `$temp_err` vide pendant 4min puis détectait
au dernier moment — juste avant que `run_with_timeout` expire de toute façon.

**La cause racine n'est pas dans le watcher, elle est dans `gemini-exec.sh`.**

---

## Les 4 changements apportés aujourd'hui

### Fix 1 — `scripts/helpers/gemini-exec.sh` ← ROOT CAUSE
**Problème :** stderr de Gemini capturée dans `$err_file` interne, transmise seulement à l'exit.
**Fix :** `tail -f "$err_file" >&2 &` — stream en temps réel, kill après exit de gemini.
**Impact :** détection en ~2s dès "Attempt 1 failed" au lieu de ~4min.
**Sans ce fix :** les watchers de PR #338 ne voient rien pendant 4min.

```bash
# Avant :
gemini -m "$model" ... 2>"$err_file"
# ... gemini retente 10× en interne (~4min) ...
printf '%s' "$last_err" >&2   # seulement à l'exit

# Après :
: > "$err_file"
tail -f "$err_file" >&2 &     # stream temps réel
_tail_pid=$!
gemini -m "$model" ... 2>"$err_file"
kill "$_tail_pid" 2>/dev/null; wait "$_tail_pid" 2>/dev/null || true
# stderr déjà streamée — pas de reprint à l'exit
```

**Suppression des reprints dupliqués :**
- Chemin succès (exit 0) : `cat "$err_file" >&2` → retiré (déjà streamé)
- Chemin échec : `printf '%s' "$last_err" >&2` (×2) → retirés (déjà streamés)

---

### Fix 2 — `scripts/lib/agent-sync.sh` — Watcher amélioré

**Problème 1 — mauvais ciblage SIGKILL :**
`pkill -TERM -P "$_sync_pid"` puis `pkill -KILL -P "$_sync_pid"` ciblait les enfants directs
du PID bash. Problème : Node.js intercepte SIGTERM, et la hiérarchie
`gtimeout → bash → gemini-exec.sh → gemini (node)` faisait que `-P` ne trouvait pas le bon process.

**Fix :** `pkill -u "$(id -u)" -KILL -f "gemini-cli/bundle/gemini.js"` — SIGKILL direct sur
le process node gemini-cli par son chemin, sans parcourir la hiérarchie.

**Problème 2 — patterns incomplets :**
`"exhausted your capacity"` ne couvrait pas les variantes `RetryableQuotaError` et le format
`"Attempt N failed: ... exhausted"` vu dans les error logs.

**Fix patterns :**
```bash
# Avant :
grep -cE "QUOTA_EXHAUSTED|TerminalQuotaError|exhausted your capacity" "$temp_err"

# Après :
grep -qE "QUOTA_EXHAUSTED|TerminalQuotaError|exhausted your capacity|RetryableQuotaError|Attempt [0-9]+ failed.*exhausted" "$temp_err" "$temp_out"
```

**Ajout `temp_out` (belt-and-suspenders) :**
Stdout de `gemini-exec.sh` redirigé vers `$temp_out` (fichier), lu avec `cat` après.
Watcher surveille les deux fichiers — couvre le cas où des messages iraient sur stdout.

---

### Fix 3 — `scripts/lib/spawn.sh` — Watcher amélioré

Mêmes améliorations que agent-sync.sh (sans le SIGKILL qui était déjà correct dans spawn.sh) :
- `> "$temp_output"` init avant le watcher (fichier existant garantit grep sans erreur)
- Patterns étendus : `RetryableQuotaError|Attempt [0-9]+ failed.*exhausted`
- `grep -cE ... >/dev/null` → `grep -qE` (sémantique correcte pour test booléen)
- Surveillance de `"$temp_errors" "$temp_output"` (deux fichiers)

---

### Fix 4 — `scripts/lib/workflows.sh` — File reference resolution

**Problème :** `/octo:develop .claude/session-plan.md` transmettait la string
`.claude/session-plan.md` à Gemini/Codex. Les agents recevaient un chemin, pas un plan.

**Fix :** dans `tangle_develop()`, avant la construction du `decompose_prompt` :
```bash
local resolved_prompt="$prompt"
local file_ref
file_ref=$(echo "$prompt" | grep -oE '[^[:space:]]+\.md' | head -1)
if [[ -n "$file_ref" && -f "$file_ref" ]]; then
    local file_content
    file_content=$(<"$file_ref")
    resolved_prompt="Implement the code changes described in the following plan. Do NOT modify the plan file itself (${file_ref}).

--- PLAN: ${file_ref} ---
${file_content}
--- END PLAN ---"
    log INFO "Resolved file reference: ${file_ref} — injecting content into decompose prompt"
fi
```

`resolved_prompt` est utilisé dans `decompose_prompt` ET dans le fallback direct Codex.

---

## Résultats des tests

| Test | Avant | Après |
|---|---|---|
| Simulation watcher isolé | — | 2s |
| gemini-exec.sh stream temps réel | 4min+ | 2s |
| Test E2E (watcher + gemini-exec.sh + mock) | — | 3s |

---

## Structure des PRs — décision finale (débat 4 modèles, 2026-05-03)

Débat cross-critique : 🟡 Gemini · 🔴 Codex · 🟠 Sonnet · 🐙 Opus
Synthèse complète : `~/.claude-octopus/debates/pr-structure-quota-fix/synthesis.md`

### PR A — `fix/gemini-exec-realtime-stderr` ← `upstream/main`
**Fichier :** `scripts/helpers/gemini-exec.sh`
Standalone, 4/4 unanimes. Mentionner dans la description : "sans ce fix, les watchers de PR #338 regardaient des fichiers vides".

### PR B — `fix/quota-watcher-improvements` ← `upstream/main`
**Fichiers :** `scripts/lib/agent-sync.sh` + `scripts/lib/spawn.sh`
**Décision : nouvelle branche (3/4).** Dissident : Gemini (cohésion atomique).
Argument gagnant : le watcher de PR #338 ne fonctionnait pas (fichiers vides ~4min) — ce n'est
pas une amélioration progressive, c'est la correction d'un mécanisme cassé. De plus, PR A mergera
avant PR #338, forçant un rebase de toute façon — autant créer PR B proprement maintenant.
Cherry-pick des commits spawn.sh + agent-sync.sh depuis `fix/gemini-quota-fast-fail`.

### PR C — `fix/develop-md-file-resolution` ← `upstream/main`
**Fichier :** `scripts/lib/workflows.sh` (file-ref resolution uniquement)
**Décision : base upstream/main (4/4 unanimes).**
Baser sur PR #338 crée une dépendance sur code non-mergé → cascade de force-push sur GitHub,
base branch qui ne se met pas à jour → diffs fantômes pour les reviewers. Conflit manuel sur
workflows.sh (lignes différentes) préférable à dépendance implicite.

### Sort de PR #338
Rebaser après merge de PR A + PR B. Retirer les changements agent-sync.sh et spawn.sh (couverts
par PR B). Garder dispatch.sh + fallback Codex workflows.sh si pas encore mergés ailleurs.

### Ordre de merge recommandé
```
PR A → PR B → PR C → PR #338 (rebasée, scope réduit)
```
