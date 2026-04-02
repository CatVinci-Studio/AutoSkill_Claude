---
name: auto-optimize-skills
description: "Analyze session transcripts and improve existing skills or create new ones based on usage patterns. Use when asked to optimize skills, auto-improve skills, create skills from usage patterns, or run /auto-optimize-skills."
allowed-tools: Read, Write, Edit, Bash(*), Glob, Grep
---

# Auto-Optimize Skills

Analyze skill usage data from past sessions and either improve existing skills or create new ones. All modifications are backed up before writing.

## Step 1 — Load all available data

### 1a. Read historical queue (past sessions)
```bash
cat ~/.local/share/auto-skill/queue.json
```

### 1b. Read current session data (mid-session support)

The `.stop_flag` file is written in real-time by the PostToolUse hook each time a skill is invoked in the current session. Read it to capture skills used so far even if the session hasn't ended yet:

```bash
cat ~/.local/share/auto-skill/.stop_flag 2>/dev/null || true
```

### 1c. Merge both sources

Combine `queue.json`.to_optimize with any skill names from `.stop_flag`. Deduplicate. This gives you the full picture whether you're running mid-session or after a session ends.

### 1d. Read config
```bash
cat ~/.claude/plugins/auto-skill/config.json
```

## Step 2 — Present options to user

Display the merged list clearly:

```
【Optimize existing skills】
  · <skill-name>   — found in N sessions
  · ...

【Suggested new skills from patterns】
  · "<pattern description>" — detected N times
  · ...

【Create a new skill from scratch】
  · Describe any workflow you want to automate

How to proceed? [all / select / skip / new]
```

- `all` — process all optimizations and pattern-based creations
- `select` — choose which items to handle
- `skip` — do nothing this time
- `new` — skip optimizations, go straight to creating a new skill from your description

If both queue.json and .stop_flag are empty and the user didn't choose `new`, inform the user: "No skill usage recorded yet. Use some skills first, then run /auto-optimize-skills."

Wait for user choice before continuing.

## Step 3 — For each skill to optimize

### 3a. Read transcript history

Get the list of recent transcripts:
```bash
tail -20 ~/.local/share/auto-skill/transcripts.log
```

Read the most recent 3 transcripts and search for exchanges involving this skill. Look for:
- **Trigger mismatch**: User typed something related but skill wasn't auto-triggered, then ran it manually
- **Correction after skill**: User said "不对", "wrong", "再加上", "also include", or similar within 2 turns of skill completing
- **Tool gaps**: Tool calls that occurred during skill execution but aren't in `allowed-tools`
- **Repeated invocation**: Same skill called more than once in a single session

### 3b. Locate and read the skill file

First check if the skill exists as a local user skill:
```bash
ls ~/.claude/skills/<skill-name>/SKILL.md 2>/dev/null && echo "local" || echo "not found"
```

If not found locally, search plugin/market directories:
```bash
find ~/.claude/plugins -name "SKILL.md" -path "*/<skill-name>/*" 2>/dev/null | head -5
```

**Case A — found locally at `~/.claude/skills/<skill-name>/SKILL.md`:**
Read and proceed normally.

**Case B — found inside a plugin/market directory:**
Inform the user:
> ⚠️ `<skill-name>` is a market/plugin skill (found at `<path>`). Editing it in-place would be overwritten on the next plugin update.
> Fork it to your local skills first?

If user confirms, fork it:
```bash
mkdir -p ~/.claude/skills/<skill-name>
cp <market-path>/SKILL.md ~/.claude/skills/<skill-name>/SKILL.md
echo "Forked to ~/.claude/skills/<skill-name>/SKILL.md"
```
Then proceed with optimization on the forked copy.

**Case C — not found anywhere:**
Inform the user that the skill file cannot be located and skip this skill.

### 3c. Backup original

```bash
ts=$(date +%Y%m%d_%H%M%S)
mkdir -p ~/.claude/skills-backup/$ts/<skill-name>
cp ~/.claude/skills/<skill-name>/SKILL.md \
   ~/.claude/skills-backup/$ts/<skill-name>/SKILL.md
echo "Backed up to ~/.claude/skills-backup/$ts/<skill-name>/SKILL.md"
```

### 3d. Generate improvements

Rewrite only what needs changing — preserve the rest exactly:

- **description**: Add trigger phrases that match how the user actually invoked the skill (what they typed before manually running it)
- **allowed-tools**: Add any tools used during execution that weren't declared
- **Instructions**: Clarify or expand steps that led to correction behavior. Add the specific detail the user had to ask for as follow-up.
- **Output format**: If the user asked for a different format after skill ran, encode that as the default

Do NOT change the core purpose, restructure everything, or add speculative improvements not evidenced in the transcript.

### 3e. Write improved skill

Overwrite the skill file with the improved version:
```bash
# Write to ~/.claude/skills/<skill-name>/SKILL.md
```

Report: what changed and why (1-2 lines per change).

---

## Step 4 — For each pattern to create

### 4a. Read transcript excerpts

From `transcripts.log`, find the sessions where the pattern appeared. Extract:
- What the user said to start the workflow
- The sequence of tool calls that followed
- What the final output was

### 4b. Draft the new skill

Propose to user:
- **name**: kebab-case, descriptive
- **description**: trigger phrases based on what user actually typed
- **allowed-tools**: tools used in the workflow
- **Steps**: derived from the observed tool call sequence

Show the draft and ask user to confirm or edit before writing.

### 4c. Write new skill

After user confirms:
```bash
mkdir -p ~/.claude/skills/<new-name>
# Write ~/.claude/skills/<new-name>/SKILL.md
```

### 4d. Create a new skill from user description

Trigger this step when:
- The user chose `new` in Step 2, OR
- The user explicitly asks to create a new skill during this session

Ask the user the following questions (can be answered all at once):
1. **What does this skill do?** (one-sentence description)
2. **What would trigger it?** (what phrases do you typically type to start this task?)
3. **Any tools it needs?** (e.g. Bash, Read, Write, WebSearch — or leave blank to infer)

Optionally, scan the most recent transcript for relevant context:
```bash
tail -5 ~/.local/share/auto-skill/transcripts.log
```
If a recent transcript shows a workflow matching the user's description, use those tool call sequences to inform the `allowed-tools` and steps.

Draft a new skill and show it to the user for confirmation:
- **name**: kebab-case, descriptive, based on what the user said
- **description**: use the trigger phrases the user provided verbatim
- **allowed-tools**: tools the user specified, plus any inferred from transcript context
- **Steps**: derived from user description + observed tool sequence (if available)

After user confirms (or edits), write the skill:
```bash
mkdir -p ~/.claude/skills/<new-name>
# Write ~/.claude/skills/<new-name>/SKILL.md
```

Report: skill name, file path, and trigger phrases written to description.

---

## Step 5 — Update queue and history

After processing, remove handled items from `queue.json`. Replace `SKILL_A SKILL_B` with the actual skill names you processed, and `PATTERN_KEY` with the pattern strings you created skills for.

Remove optimized skills from queue:
```bash
# Run once per processed skill, substituting the actual skill name
jq 'del(.to_optimize[] | select(. == "SKILL_A"))' \
  ~/.local/share/auto-skill/queue.json > /tmp/as_queue.tmp \
  && mv /tmp/as_queue.tmp ~/.local/share/auto-skill/queue.json
```

Remove created patterns from queue:
```bash
# Run once per created pattern, substituting the actual pattern key
jq 'del(.to_create[] | select(.pattern == "PATTERN_KEY"))' \
  ~/.local/share/auto-skill/queue.json > /tmp/as_queue.tmp \
  && mv /tmp/as_queue.tmp ~/.local/share/auto-skill/queue.json
```

Append to history log (substitute actual values):
```bash
jq --arg ts "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
   --argjson optimized '["SKILL_A","SKILL_B"]' \
   --argjson created '["NEW_SKILL_NAME"]' \
   --arg backup "~/.claude/skills-backup/TIMESTAMP" \
   '. += [{"timestamp":$ts,"optimized":$optimized,"created":$created,"backup":$backup}]' \
   ~/.local/share/auto-skill/history.json > /tmp/as_history.tmp \
   && mv /tmp/as_history.tmp ~/.local/share/auto-skill/history.json
```

Report final summary to user: which skills were optimized, which were created, where backups are.
