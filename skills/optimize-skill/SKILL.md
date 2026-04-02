---
name: optimize-skill
description: "Analyze session transcripts and improve existing skills based on real usage signals. Use when asked to optimize skills, improve skills, fix skill triggers, update skill tools, or run /optimize-skill."
allowed-tools: Read, Write, Edit, Bash, Glob, Grep
---

# Optimize Skill

Load the list of skills pending optimization, read relevant transcripts, and rewrite each skill based on observed behavior signals.

## Step 1 — Load pending skills

### 1a. Read historical queue
```bash
cat ~/.local/share/auto-optimize-skills/queue.json
```

### 1b. Read current session data
```bash
cat ~/.local/share/auto-optimize-skills/.stop_flag 2>/dev/null || true
```

### 1c. Merge and deduplicate
Combine `queue.json`.to_optimize with any skill names from `.stop_flag`. Deduplicate.

### 1d. Read config
```bash
cat ~/.claude/plugins/auto-optimize-skills/config.json
```

## Step 2 — Present options

Display the merged list:

```
【Skills ready to optimize】
  · <skill-name>   — found in N sessions
  · ...
```

If the list is empty, tell the user: "No skill usage recorded yet. Use some skills first, then run /optimize-skill."

Ask: **Which skills should I optimize? [all / select / skip]**

Wait for user choice before continuing.

## Step 3 — For each selected skill

### 3a. Read transcript history

```bash
tail -20 ~/.local/share/auto-optimize-skills/transcripts.log
```

Read the most recent 3 transcripts and search for exchanges involving this skill. Look for:
- **Trigger mismatch**: user typed something related but skill wasn't auto-triggered, then ran it manually
- **Correction after skill**: user said "不对", "wrong", "再加上", "also include", or similar within 2 turns of skill completing
- **Tool gaps**: tool calls that occurred during skill execution but aren't in `allowed-tools`
- **Repeated invocation**: same skill called more than once in a single session

### 3b. Locate the skill file

First check local user skills:
```bash
ls ~/.claude/skills/<skill-name>/SKILL.md 2>/dev/null && echo "local" || echo "not found"
```

If not found locally, search plugin directories:
```bash
find ~/.claude/plugins -name "SKILL.md" -path "*/<skill-name>/*" 2>/dev/null | head -5
```

**Case A — found locally:** read and proceed.

**Case B — found inside a plugin directory:**
> ⚠️ `<skill-name>` is a plugin skill (found at `<path>`). Editing it in-place would be overwritten on the next plugin update.
> Fork it to your local skills first?

If user confirms, fork:
```bash
mkdir -p ~/.claude/skills/<skill-name>
cp <plugin-path>/SKILL.md ~/.claude/skills/<skill-name>/SKILL.md
```

**Case C — not found:** inform the user and skip.

### 3c. Backup original

```bash
ts=$(date +%Y%m%d_%H%M%S)
mkdir -p ~/.claude/skills-backup/$ts/<skill-name>
cp ~/.claude/skills/<skill-name>/SKILL.md \
   ~/.claude/skills-backup/$ts/<skill-name>/SKILL.md
```

### 3d. Generate improvements

Rewrite only what needs changing — preserve the rest exactly:

- **description**: add trigger phrases that match how the user actually invoked the skill
- **allowed-tools**: add any tools used during execution that weren't declared
- **Instructions**: clarify or expand steps that led to correction behavior
- **Output format**: if the user asked for a different format after skill ran, encode that as the default

Do NOT change the core purpose, restructure everything, or add speculative improvements not evidenced in the transcript.

### 3e. Show diff and confirm

Present the proposed changes before writing:
```
【Changes for <skill-name>】
  description: added trigger "..."
  allowed-tools: added WebSearch
  Step 2: clarified X because user asked for Y after skill ran

Write these changes? [yes / skip / edit]
```

Wait for confirmation, then write the improved skill file.

Report: what changed and why (1–2 lines per change).

## Step 4 — Update queue

Remove processed skills from `queue.json`:

```bash
# Repeat for each processed skill
jq 'del(.to_optimize[] | select(. == "SKILL_NAME"))' \
  ~/.local/share/auto-optimize-skills/queue.json > /tmp/as_queue.tmp \
  && mv /tmp/as_queue.tmp ~/.local/share/auto-optimize-skills/queue.json
```

Append to history log:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson optimized '["SKILL_A","SKILL_B"]' \
   --arg backup "~/.claude/skills-backup/TIMESTAMP" \
   '. += [{"timestamp":$ts,"optimized":$optimized,"backup":$backup}]' \
   ~/.local/share/auto-optimize-skills/history.json > /tmp/as_history.tmp \
   && mv /tmp/as_history.tmp ~/.local/share/auto-optimize-skills/history.json
```

Report final summary: which skills were optimized, where backups are.
