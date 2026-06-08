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

Ne pas utiliser la procedure canary ci-dessous pour un run CoproOS lourd.

## Deux modes de run a ne pas confondre

Il y a deux processus distincts.

### Canary / validation orchestration

Pour un canary minimal ou une validation Embrace sans code produit, le repo
temporaire dans `/private/tmp` est attendu. Le but est d'isoler l'orchestration:
un fichier `canary.txt`, un `task.md`, puis un script et un log dans
`/private/tmp`.

### Run produit CoproOS

Pour un vrai Embrace sur CoproOS, ne pas creer la branche ni le checkout produit
dans `/private/tmp`. `/private/tmp` sert uniquement au script de lancement et au
log `tee`.

Il y a deux modes valides.

#### Mode A — checkout CoproOS principal disponible

Utiliser ce mode quand `/Users/sourouche/Documents/CoproOS` n'est pas utilise
pour un autre travail en parallele. La branche de travail existe alors dans le
checkout produit principal:

`/Users/sourouche/Documents/CoproOS`

Process valide le 2026-05-30:

1. Verifier le plugin actif, son commit, et le harness tokenless.
2. Preserver les changements locaux de la branche courante avant le switch
   (`git stash push -m ... -- <fichiers>` ou commit explicite).
3. Dans `/Users/sourouche/Documents/CoproOS`, creer ou switcher une branche
   dediee au run, par exemple `embrace/gmail-threading-debug-rerun-bc5c4d5`.
4. Verifier `git status --short --branch`: branche attendue et worktree propre.
5. Utiliser `/private/tmp` uniquement pour le script de lancement et le log
   `tee`, pas pour la branche ou le worktree produit.
6. Le script de lancement doit refuser si la branche repo, le commit repo, le
   commit plugin, le repo dirty, ou le plugin dirty ne correspondent pas.
7. Apres le run, garder le diff sur cette branche produit. Ne restaurer le stash
   precedent que lors du retour sur la branche precedente.

Exemple de commande finale pour un run produit: le script et le log peuvent
rester dans `/private/tmp`, mais `REPO` doit pointer vers
`/Users/sourouche/Documents/CoproOS`.

#### Mode B — travail parallele sur CoproOS en cours

Utiliser ce mode quand le checkout principal est deja utilise pour une autre
tache. Ne pas lancer Embrace dans `/Users/sourouche/Documents/CoproOS` et ne pas
faire de `git switch` dans ce checkout.

Process valide le 2026-06-08:

1. Creer un clone local durable et dedie, hors `/private/tmp`, par exemple:
   `/Users/sourouche/Documents/CoproOS-embrace-gmail-<plugin>`.
2. Dans ce clone isole, creer une branche dediee au run depuis le commit de base
   attendu, par exemple:
   `embrace/gmail-threading-debug-rerun-<plugin>`.
3. Si un run precedent dans le clone isole a laisse un diff utile, le preserver
   avant de repartir de la base (`git commit -m "wip(embrace): preserve ..."`).
4. Verifier que le clone isole est sur la branche attendue, au commit attendu,
   et clean avant lancement.
5. Verifier que le plugin actif est au commit attendu et clean. Si le plugin a
   recu un fix, le commit doit etre fait avant de preparer le script de run.
6. Le script de lancement dans `/private/tmp` doit pointer `REPO` vers le clone
   isole, pas vers `/Users/sourouche/Documents/CoproOS`.
7. Le prompt du script doit interdire explicitement de toucher au checkout actif:
   `/Users/sourouche/Documents/CoproOS`.
8. Si le clone ne contient pas `node_modules`, utiliser un symlink vers le
   `node_modules` du checkout principal plutot que de lancer une install longue,
   si les versions de fichiers/package sont compatibles.

Exemple de preflight pour le mode B:

```bash
git clone --no-hardlinks /Users/sourouche/Documents/CoproOS /Users/sourouche/Documents/CoproOS-embrace-gmail-<plugin>
cd /Users/sourouche/Documents/CoproOS-embrace-gmail-<plugin>
git switch -c embrace/gmail-threading-debug-rerun-<plugin> <base-commit>
ln -s /Users/sourouche/Documents/CoproOS/node_modules node_modules
git status --short --branch
```

Le script doit inclure des guards equivalent a:

```bash
REPO="/Users/sourouche/Documents/CoproOS-embrace-gmail-<plugin>"
EXPECTED_REPO_BRANCH="embrace/gmail-threading-debug-rerun-<plugin>"
EXPECTED_REPO_COMMIT="<base-commit>"
EXPECTED_PLUGIN_COMMIT="<plugin>"
```

#### Commande finale: toujours une seule ligne

La commande remise a Claude doit tenir sur une seule ligne. Ne jamais couper le
chemin du log `tee` sur deux lignes: cela produit des faux `exit 127` parce que
le shell interprete la seconde ligne comme une nouvelle commande.

Correct:

```bash
bash /private/tmp/run-octo-embrace-coproos-gmail-threading-rerun-<plugin>.sh 2>&1 | tee /private/tmp/octo-embrace-coproos-gmail-threading-rerun-<plugin>.log
```

Incorrect:

```bash
bash /private/tmp/run-octo-embrace-coproos-gmail-threading-rerun-<plugin>.sh 2>&1 | tee /private/tmp/octo-
embrace-coproos-gmail-threading-rerun-<plugin>.log
```

## Preconditions canary

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
- Verifier que Gemini quota/lockout est reporte comme failed de facon coherente dans les champs Provider Statuses / Provider Status Summary.
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
- ne pas interpreter `Consensus Quality: partial` comme un statut provider
  `degraded`; c'est une qualite de consensus, pas l'etat de Gemini.

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
