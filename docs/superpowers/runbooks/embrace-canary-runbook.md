# Embrace Canary Runbook

Procedure pour creer et lancer un canary Embrace reel minimal, isole de tout
repo produit. Le but est de valider l'orchestration Embrace sans lancer un audit
lourd et sans toucher a CoproOS.

## Quand utiliser ce runbook

Utiliser ce runbook apres des fixes Embrace valides par le harness tokenless.
Le canary reel sert a verifier les contrats live que le harness ne peut pas
prouver completement, par exemple:

- absence de fuite de contexte historique non pertinent;
- wording coherent des providers en quota/lockout;
- presence des artifacts Probe, Grasp, gate demande, Tangle, Ink/report;
- mutation limitee a un fichier de canary.

Ne pas utiliser ce runbook pour un run CoproOS lourd.

## Preconditions

- Plugin actif: `/Users/sourouche/.claude-octopus/install/embrace-stability-stack`
- Worktree plugin propre ou avec uniquement des changements intentionnels.
- Harness tokenless complet vert avant le canary.
- Accord explicite pour un run provider reel.
- Ne pas lancer depuis `/Users/sourouche/Documents/CoproOS`.

Verifier:

```bash
cd /Users/sourouche/.claude-octopus/install/embrace-stability-stack
git status --short --branch
/Users/sourouche/.claude-octopus/local/embrace-harness/run
```

## 1. Choisir un identifiant de canary

Utiliser le commit ou le tag sous test. Exemple:

```bash
CANARY_ID="eeedf6f"
CANARY_DIR="/private/tmp/octo-embrace-canary-${CANARY_ID}"
PLUGIN="/Users/sourouche/.claude-octopus/install/embrace-stability-stack"
RUN_SCRIPT="/private/tmp/run-octo-embrace-canary-${CANARY_ID}.sh"
RUN_LOG="/private/tmp/octo-embrace-canary-${CANARY_ID}.log"
```

## 2. Creer le repo canary temporaire

```bash
mkdir -p "$CANARY_DIR"
cd "$CANARY_DIR"

git init
git config user.email embrace-canary@example.invalid
git config user.name "Embrace Canary"

printf 'baseline\n' > canary.txt
cat > task.md <<EOF
Canary Octo pur ${CANARY_ID}.

Objectif:
- Lire task.md.
- Modifier uniquement canary.txt.
- Ajouter exactement une ligne:
  embrace-canary-${CANARY_ID}

Contraintes:
- Ne toucher a aucun autre fichier tracked.
- Produire les artifacts Embrace attendus: Probe, Grasp, gate define-develop, Tangle validation, Ink delivery ou failed report explicite.
- Verifier que les anciennes observations canary project-wide ne polluent pas le contexte.
- Verifier que Gemini quota/lockout est reporte comme failed de facon coherente, pas failed/degraded mixte.
EOF

git add canary.txt task.md
git commit -m "canary baseline"
git status --short --branch
```

Etat attendu: `git status --short --branch` ne montre aucune modification.

## 3. Creer le script de run

Creer un script pour que le lancement soit reproductible et loggable.

```bash
cat > "$RUN_SCRIPT" <<EOF
#!/usr/bin/env bash
set -euo pipefail

CANARY_DIR="${CANARY_DIR}"
PLUGIN="${PLUGIN}"

cd "\$CANARY_DIR"

OCTOPUS_ALLOW_REAL_EMBRACE=1 \\
OCTOPUS_EMBRACE_REQUIRE_ALLOW_REAL=1 \\
OCTOPUS_SKIP_COST_PROMPT=true \\
AUTONOMY_MODE=autonomous \\
ON_FAIL_ACTION=abort \\
OCTOPUS_DEBATE_GATES=define \\
OCTOPUS_EMBRACE_DEBATE_GATES=define \\
EMBRACE_DEBATE_GATES=define \\
"\$PLUGIN/scripts/orchestrate.sh" embrace \\
"Canary Octo pur ${CANARY_ID}. Lis task.md. Modifie uniquement canary.txt pour ajouter la ligne exacte embrace-canary-${CANARY_ID}. Ne touche a aucun autre fichier tracked. Valide surtout: pas de leakage anciennes observations canary project-wide, Gemini status coherent failed, gate define-develop, tangle-validation, delivery ou failed report explicite."
EOF

chmod +x "$RUN_SCRIPT"
bash -n "$RUN_SCRIPT"
```

## 4. Donner a Claude la commande de lancement

Envoyer uniquement cette commande a Claude pour le run reel:

```bash
bash /private/tmp/run-octo-embrace-canary-eeedf6f.sh 2>&1 | tee /private/tmp/octo-embrace-canary-eeedf6f.log
```

Adapter `eeedf6f` si `CANARY_ID` est different.

Important: cette commande ouvre volontairement les providers reels via
`OCTOPUS_ALLOW_REAL_EMBRACE=1`. Elle peut consommer du quota.

## 5. Verifier le resultat primaire

Depuis le repo canary:

```bash
cd "$CANARY_DIR"
git status --short
git diff -- canary.txt task.md
tail -80 "$RUN_LOG"
```

Succes attendu:

- `git status --short` montre uniquement `M canary.txt` parmi les fichiers tracked.
- `task.md` n'a pas de diff.
- `canary.txt` contient exactement une ligne ajoutee:
  `embrace-canary-${CANARY_ID}`.
- Le run termine avec exit code 0, ou produit un failed report explicite si une
  phase echoue.

## 6. Localiser les artifacts Embrace

Le log affiche normalement le `Results:` dir et le chemin du report. Si besoin:

```bash
find ~/.claude-octopus/results -name "*${CANARY_ID}*" -print | sort
find ~/.claude-octopus/results -name "embrace-report-*.md" -print | tail -20
```

Artifacts attendus:

- `probe-synthesis-*.md`
- `grasp-consensus-*.md`
- `embrace-gate-define-develop-*.md`
- `tangle-validation-*.md`
- `delivery-*.md` ou `embrace-report-*.md` avec `Final Status: FAILED`

## 7. Verifier les deux residus cibles

### Context leakage

Chercher les anciennes observations canary `project-wide` dans les artifacts du
run courant:

```bash
RESULTS_DIR="<copier le Results dir depuis le log>"
rg -n "Relevant High-Importance|D-177939|D-177940|project-wide|previous canary|ancienne" "$RESULTS_DIR"
```

Attendu:

- pas d'anciennes observations canary `project-wide` injectees;
- les observations file-scope pertinentes peuvent rester acceptables.

### Wording Gemini failed/degraded

```bash
rg -n "gemini=.*degraded|Gemini \\(degraded\\)|gemini: degraded|gemini=.*failed|gemini: failed|Provider Statuses" "$RESULTS_DIR"
```

Attendu:

- quota/lockout Gemini reporte en `failed`;
- pas de melange `failed` dans le report final et `degraded` dans le gate pour
  le meme skip quota/lockout.

## 8. Capturer la conclusion

Ajouter au ledger local si un nouveau residu est observe:

`/Users/sourouche/.claude-octopus/local/embrace-harness/EMBRACE_BUG_LEDGER.md`

Regle: pas de fix Embrace sans entree ledger ou decision explicite out-of-scope.

Si le canary est bon, noter:

- run id;
- commit plugin teste;
- exit code;
- duree;
- artifacts presents;
- diff tracked exact;
- verdict sur context leakage;
- verdict sur Gemini status wording.

## 9. Nettoyage optionnel

Garder le log `/private/tmp/octo-embrace-canary-${CANARY_ID}.log` tant que
l'analyse n'est pas terminee. Ne pas committer les artifacts `runs/`, logs bruts
provider, ou transcripts lourds.

Le repo canary temporaire peut etre supprime apres archivage de la conclusion:

```bash
rm -rf "$CANARY_DIR" "$RUN_SCRIPT" "$RUN_LOG"
```

