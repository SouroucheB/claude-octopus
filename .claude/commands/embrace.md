---
command: embrace
description: "Full Double Diamond workflow - Research → Define → Develop → Deliver"
aliases:
  - full-cycle
  - complete-workflow
---

# Embrace - Complete Double Diamond Workflow

**Your first output line MUST be:** `🐙 Octopus Embrace`

## Non-Negotiable Runner Contract

When the user invokes `/octo:embrace`, you MUST delegate the workflow to the unified Embrace runner:

```bash
cd "${HOME}/.claude-octopus/plugin" && OCTOPUS_EMBRACE_DEBATE_GATES="${DEBATE_GATES}" AUTONOMY_MODE="${AUTONOMY_MODE}" ON_FAIL_ACTION=abort bash scripts/orchestrate.sh embrace "<user's prompt>"
```

You are PROHIBITED from driving Embrace phase by phase from this markdown command. Do not manually run the individual Discover, Define, Develop, Deliver, or debate-gate subcommands as a substitute for the unified runner. Do not implement code directly if the runner fails. If the runner exits non-zero, STOP and report the failed phase, exit status, and artifact path shown by the runner.

The runner owns:
- phase ordering
- requested debate gates
- required artifact checks
- fail-fast behavior
- fallbacks for degraded providers
- delivery synthesis

## Step 1: Ask Clarifying Questions

```javascript
AskUserQuestion({
  questions: [
    {
      question: "What's the scope of this project?",
      header: "Scope",
      multiSelect: false,
      options: [
        {label: "Small feature", description: "Single component or small addition"},
        {label: "Medium feature", description: "Multiple components or moderate complexity"},
        {label: "Large feature", description: "System-wide changes or new subsystem"},
        {label: "Full system", description: "Complete application or major architecture"}
      ]
    },
    {
      question: "What areas require the most attention?",
      header: "Focus Areas",
      multiSelect: true,
      options: [
        {label: "Architecture design", description: "System structure and design patterns"},
        {label: "Security", description: "Authentication, authorization, data protection"},
        {label: "Performance", description: "Speed, scalability, optimization"},
        {label: "User experience", description: "UI/UX and usability"}
      ]
    },
    {
      question: "What's your preferred level of autonomy?",
      header: "Autonomy",
      multiSelect: false,
      options: [
        {label: "Supervised (default)", description: "Review and approve after each phase"},
        {label: "Semi-autonomous", description: "Only intervene if quality gates fail"},
        {label: "Autonomous", description: "Run all 4 phases automatically"},
        {label: "Manual", description: "I'll guide each step explicitly"}
      ]
    },
    {
      question: "Should critical decisions be stress-tested with a Multi-LLM debate?",
      header: "Multi-LLM Debate Gates",
      multiSelect: false,
      options: [
        {label: "Yes — debate at Define→Develop gate", description: "Recommended for Large/Full scope"},
        {label: "Yes — debate at both gates", description: "Maximum rigor, uses external API credits"},
        {label: "No — skip debates", description: "Standard workflow without debate checkpoints"},
        {label: "Only if disagreement detected", description: "Auto-trigger when providers diverge"}
      ]
    }
  ]
})
```

Normalize the answers before running the command:
- `AUTONOMY_MODE=supervised`, `semi-autonomous`, `autonomous`, or `manual`
- `DEBATE_GATES=define` for "Yes — debate at Define→Develop gate"
- `DEBATE_GATES=both` for "Yes — debate at both gates"
- `DEBATE_GATES=none` for "No — skip debates"
- `DEBATE_GATES=auto` for "Only if disagreement detected"

If `CLAUDE_CODE_REMOTE=true` or `OCTOPUS_REMOTE_SESSION=true`, do not block on clarifying questions. Infer scope and focus from the prompt, use `AUTONOMY_MODE=autonomous`, and use `DEBATE_GATES=auto` unless the user's prompt says otherwise.

## Step 2: Display Provider Banner

Run this check before the banner:

```bash
echo "PROVIDER_CHECK_START"
printf "codex:%s\n" "$(command -v codex >/dev/null 2>&1 && echo available || echo missing)"
printf "gemini:%s\n" "$(command -v gemini >/dev/null 2>&1 && echo available || echo missing)"
printf "perplexity:%s\n" "$([ -n "${PERPLEXITY_API_KEY:-}" ] && echo available || echo missing)"
printf "opencode:%s\n" "$(command -v opencode >/dev/null 2>&1 && echo available || echo missing)"
printf "copilot:%s\n" "$(command -v copilot >/dev/null 2>&1 && echo available || echo missing)"
printf "qwen:%s\n" "$(command -v qwen >/dev/null 2>&1 && echo available || echo missing)"
printf "ollama:%s\n" "$(command -v ollama >/dev/null 2>&1 && curl -sf http://localhost:11434/api/tags >/dev/null 2>&1 && echo available || echo missing)"
printf "openrouter:%s\n" "$([ -n "${OPENROUTER_API_KEY:-}" ] && echo available || echo missing)"
echo "PROVIDER_CHECK_END"
```

Display a concise banner with the actual provider status, selected scope/focus, autonomy, and debate-gate mode.

## Step 3: Run The Unified Workflow

Run exactly one Embrace workflow command:

```bash
cd "${HOME}/.claude-octopus/plugin" && OCTOPUS_EMBRACE_DEBATE_GATES="${DEBATE_GATES}" AUTONOMY_MODE="${AUTONOMY_MODE}" ON_FAIL_ACTION=abort bash scripts/orchestrate.sh embrace "<user's prompt>"
```

If the command succeeds, summarize the phase outputs and artifact paths printed by the runner.

If the command fails, do not continue locally. Report:
- failed phase
- runner reason
- artifact path, if printed
- next safe action: inspect, retry with adjusted provider settings, or stop

## Step 4: Ask What To Do Next

After a successful run, ask:

```javascript
AskUserQuestion({
  questions: [{
    question: "The embrace workflow has completed. What next?",
    header: "Next Steps",
    multiSelect: false,
    options: [
      {label: "Review phase outputs", description: "Walk through each phase's findings"},
      {label: "Refine implementation", description: "Make adjustments based on results"},
      {label: "Run another iteration", description: "Re-run with updated context"},
      {label: "Export results", description: "Save a summary document"}
    ]
  }]
})
```
