---
name: auto-optimize-skills
description: "Analyze session transcripts and improve existing skills or create new ones based on usage patterns. Use when asked to optimize skills, auto-improve skills, create skills from usage patterns, or run /auto-optimize-skills."
allowed-tools: Read, Write, Edit, Bash(*), Glob, Grep, Agent
---

# Auto-Optimize Skills

Orchestrate skill optimization and new skill creation. Analysis is delegated to the `skill-analyzer` sub-agent — this skill handles user interaction, file writing, and queue management.

## Step 1 — Load all available data

### 1a. Read historical queue (past sessions)
```bash
cat ~/.local/share/auto-skill/queue.json
```

### 1b. Read current session data (mid-session support)

The `.stop_flag` is written in real-time by the PostToolUse hook each time a skill is invoked in the current session. Read it even if the session hasn't ended yet:

```bash
cat ~/.local/share/auto-skill/.stop_flag 2>/dev/null || true
```

### 1c. Merge both sources

Combine `queue.json`.to_optimize with skill names from `.stop_flag`. Deduplicate.

### 1d. Read config
```bash
cat ~/.claude/plugins/auto-skill/config.json
```

---

## Step 2 — Present options to user

Display the merged list:

```
【Optimize existing skills】
  · <skill-name>
  · ...

【Suggested new skills】
  · "<pattern>" — seen N times
  · ...

How to proceed? [all / select / skip]
```

If both sources are empty: "No skill usage recorded yet. Use some skills first, then run /auto-optimize-skills."

Wait for user choice before continuing.

---

## Step 3 — Analyze selected skills (via sub-agent)

For each skill the user selected to optimize:

### 3a. Read the current skill file
```bash
cat ~/.claude/skills/<skill-name>/SKILL.md
```

### 3b. Get recent transcript paths
```bash
tail -10 ~/.local/share/auto-skill/transcripts.log
```

### 3c. Delegate analysis to skill-analyzer agent

Use the Agent tool to invoke the `skill-analyzer` agent. Pass it:
- The skill name
- The transcript paths (most recent 3)
- The full current SKILL.md content

The agent will return a structured improvement report with specific proposed changes.

### 3d. Show report to user

Present the agent's findings and proposed changes. Ask for confirmation before writing.

---

## Step 4 — Apply approved changes

### 4a. Backup original
```bash
ts=$(date +%Y%m%d_%H%M%S)
mkdir -p ~/.claude/skills-backup/$ts/<skill-name>
cp ~/.claude/skills/<skill-name>/SKILL.md \
   ~/.claude/skills-backup/$ts/<skill-name>/SKILL.md
```

### 4b. Write improved skill

Apply only the changes approved by the user. Do NOT restructure or speculate beyond what the agent reported.

Write the updated content to `~/.claude/skills/<skill-name>/SKILL.md`.

---

## Step 5 — Create new skills (from patterns)

For each pattern the user selected to create a skill from:

### 5a. Read relevant transcripts

From `transcripts.log`, find sessions containing the pattern. Extract:
- The user prompt that started the workflow
- The tool call sequence that followed
- The final output

### 5b. Draft and confirm with user

Propose:
- **name**: kebab-case
- **description**: trigger phrases from what the user actually typed
- **allowed-tools**: tools observed in the workflow
- **Steps**: derived from the tool call sequence

Show draft, wait for user confirmation or edits.

### 5c. Write new skill
```bash
mkdir -p ~/.claude/skills/<new-name>
# Write ~/.claude/skills/<new-name>/SKILL.md
```

---

## Step 6 — Update queue and history

Remove processed skills from queue:
```bash
jq 'del(.to_optimize[] | select(. == "SKILL_NAME"))' \
  ~/.local/share/auto-skill/queue.json > /tmp/as_queue.tmp \
  && mv /tmp/as_queue.tmp ~/.local/share/auto-skill/queue.json
```

Remove processed patterns from queue:
```bash
jq 'del(.to_create[] | select(.pattern == "PATTERN_KEY"))' \
  ~/.local/share/auto-skill/queue.json > /tmp/as_queue.tmp \
  && mv /tmp/as_queue.tmp ~/.local/share/auto-skill/queue.json
```

Append to history:
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson optimized '["SKILL_A"]' \
   --argjson created '["NEW_SKILL"]' \
   --arg backup "~/.claude/skills-backup/TIMESTAMP" \
   '. += [{"timestamp":$ts,"optimized":$optimized,"created":$created,"backup":$backup}]' \
   ~/.local/share/auto-skill/history.json > /tmp/as_history.tmp \
   && mv /tmp/as_history.tmp ~/.local/share/auto-skill/history.json
```

Report final summary: skills optimized, skills created, backup location.
