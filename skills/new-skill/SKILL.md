---
name: new-skill
description: "Create a new skill from the current conversation or from detected usage patterns. Use when asked to create a skill from this session, turn this workflow into a skill, generate a skill from conversation, create a skill from patterns, or run /new-skill."
allowed-tools: Read, Write, Bash, Glob, Grep
---

# New Skill

Create a new skill either from the current conversation or from a repeated workflow pattern detected across sessions.

## Step 1 — Determine the source

Check if there are pending patterns in the queue:

```bash
cat ~/.local/share/auto-optimize-skills/queue.json 2>/dev/null || echo '{"to_optimize":[],"to_create":[]}'
```

Also check current session's live data:
```bash
tail -5 ~/.local/share/auto-optimize-skills/transcripts.log 2>/dev/null || true
```

Present the options:

```
How would you like to create a skill?

  [1] From this conversation  — capture the workflow we just did
  [2] From a detected pattern — <N> repeated workflows found across sessions
  [3] Describe it yourself    — tell me what the skill should do

```

If `to_create` in the queue is empty, omit option 2.

Wait for user choice before continuing.

---

## Path A — From this conversation

### A1. Read the current transcript

Find the most recent transcript:
```bash
ls -t ~/.claude/projects/**/*.jsonl 2>/dev/null | head -5
```

If that fails, ask the user to paste the path.

Read the transcript file (JSONL — one JSON object per line).

### A2. Identify the workflow

Scan the conversation for a coherent, repeatable sequence. Look for:
- A clear **goal** the user was trying to achieve
- The **tool call sequence** that accomplished it
- What the user **typed to start** the workflow (the natural trigger)

Ignore debugging detours and one-off actions. Focus on the reusable core.

If multiple distinct workflows exist, list them:
```
I found multiple workflows in this session:

1. "<brief description>" — uses Bash, Read, Write
2. "<brief description>" — uses Grep, Edit

Which one should I turn into a skill? (1 / 2 / both)
```

Wait for user choice.

### A3. Draft the skill → go to Step 2

---

## Path B — From a detected pattern

### B1. Show patterns from queue

Display `to_create` entries from `queue.json`:
```
【Detected patterns】
  · "<pattern description>" — seen N times
  · ...

Which pattern should I turn into a skill? [number / all / skip]
```

Wait for user choice.

### B2. Read relevant transcripts

```bash
tail -20 ~/.local/share/auto-optimize-skills/transcripts.log
```

Find sessions where the pattern appeared. Extract:
- What the user said to start the workflow
- The sequence of tool calls that followed
- What the final output was

### B3. Draft the skill → go to Step 2

---

## Path C — From user description

Ask:
1. **What does this skill do?** (one sentence)
2. **What would trigger it?** (phrases you'd typically type)
3. **Any tools it needs?** (or leave blank to infer)

Optionally check the most recent transcript for matching context:
```bash
tail -5 ~/.local/share/auto-optimize-skills/transcripts.log
```

Draft the skill using the user's answers + any inferred tool sequence.

### Draft the skill → go to Step 2

---

## Step 2 — Confirm the draft

Show the proposed skill to the user:

```
【Draft skill】

name:          <kebab-case-name>
description:   "<one sentence + 2–3 trigger phrases>"
allowed-tools: <tools>

Steps:
1. ...
2. ...

Write this? [yes / edit / cancel]
```

Guidelines:
- **name**: kebab-case, verb-noun (e.g. `export-pdf`, `summarize-pr`)
- **description**: start with what it does, then include natural trigger phrases verbatim
- **allowed-tools**: only tools observed or specified; no speculative additions
- **Steps**: mirror the actual tool call sequence as instructions to Claude

Wait for confirmation. Apply any edits the user requests before writing.

## Step 3 — Write the skill

```bash
mkdir -p ~/.claude/skills/<name>
```

Write `~/.claude/skills/<name>/SKILL.md`:

```markdown
---
name: <name>
description: "<description>"
allowed-tools: <tool1>, <tool2>, ...
---

# <Title>

<steps>
```

Confirm:
```
✓ Written to ~/.claude/skills/<name>/SKILL.md
  Trigger: /<name>
```

## Step 4 — Update queue

If created from a detected pattern (Path B), remove it from `to_create`:

```bash
jq 'del(.to_create[] | select(.pattern == "PATTERN_KEY"))' \
  ~/.local/share/auto-optimize-skills/queue.json > /tmp/as_queue.tmp \
  && mv /tmp/as_queue.tmp ~/.local/share/auto-optimize-skills/queue.json
```

Add the new skill to `to_optimize` so it can be improved after real usage:

```bash
jq --arg s "<name>" '
  if (.to_optimize | index($s)) == null
  then .to_optimize += [$s]
  else . end
' ~/.local/share/auto-optimize-skills/queue.json > /tmp/as_queue.tmp \
  && mv /tmp/as_queue.tmp ~/.local/share/auto-optimize-skills/queue.json
```
