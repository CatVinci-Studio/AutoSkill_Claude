# auto-skill

A Claude Code plugin that silently observes your sessions, captures which skills you use and what patterns you repeat, then helps you optimize existing skills or create new ones — on your schedule.

## Install

```bash
curl -fsSL https://raw.githubusercontent.com/CatVinci-Studio/auto-skill/main/install.sh | bash
```

Restart Claude Code after installation.

## Uninstall

```bash
curl -fsSL https://raw.githubusercontent.com/CatVinci-Studio/auto-skill/main/uninstall.sh | bash
```

Data and backups are kept after uninstall. Delete manually if no longer needed:
```bash
rm -rf ~/.local/share/auto-skill
rm -rf ~/.claude/skills-backup
```

---

## How It Works

### Three hooks run automatically

| Hook | When | What it does |
|---|---|---|
| `PostToolUse` (Skill) | Every time a skill is invoked | Records the skill name silently |
| `SessionEnd` | When you close Claude Code | Scans the full transcript, updates the queue |
| `SessionStart` | When you open Claude Code | Checks the queue, notifies you if threshold is met |

### The queue

All observations are stored in `~/.local/share/auto-skill/queue.json`:

```json
{
  "to_optimize": ["arxiv", "research-lit"],
  "to_create": [
    { "pattern": "find papers then summarize and export to Zotero", "frequency": 3 }
  ]
}
```

- **`to_optimize`**: skills that were invoked — candidates for improvement
- **`to_create`**: user prompts that appeared 2+ times without triggering any skill — candidates for new skills

### Notification

When the queue reaches the configured threshold, you see this at session start:

```
autoSkill: 5 skill(s) ready to optimize, 2 new pattern(s) detected.
Run /auto-optimize-skills when ready.
```

You decide when to act on it.

### Optimization

Run `/auto-optimize-skills` at any point — mid-session or after closing and reopening. Claude will:

1. Read **both** the historical queue (past sessions) and the current session's live data (`.stop_flag`)
2. Show you the merged list of skills and patterns
3. Let you choose: all / select individually / skip
3. For each skill to **optimize**:
   - Read past transcripts to find how you actually triggered it
   - Look for correction behavior after the skill ran
   - Look for tool calls that weren't in `allowed-tools`
   - Back up the original, then write an improved version
4. For each pattern to **create as a new skill**:
   - Show you a draft (name, description, steps) based on the observed workflow
   - Wait for your confirmation before writing
5. Clear processed items from the queue

---

## What Gets Improved

| Signal from transcript | What gets improved |
|---|---|
| You typed something related but skill didn't auto-trigger | `description` trigger phrases |
| You corrected Claude after skill ran | Step instructions |
| Skill used a tool not in its `allowed-tools` | `allowed-tools` list |
| You invoked the same skill multiple times in a session | Output completeness |
| You repeated the same workflow 2+ times with no skill | New skill created |

---

## Configuration

Edit `~/.claude/plugins/auto-skill/config.json`:

```json
{
  "notify_after_skill_uses": 5,
  "notify_after_new_patterns": 2,
  "backup_dir": "~/.claude/skills-backup",
  "data_dir": "~/.local/share/auto-skill"
}
```

| Field | Default | Description |
|---|---|---|
| `notify_after_skill_uses` | `5` | Notify when this many skills are in the optimize queue |
| `notify_after_new_patterns` | `2` | Notify when this many repeated patterns are detected |

---

## File Structure

```
~/.claude/plugins/auto-skill/         ← plugin installation directory
├── .claude-plugin/plugin.json
├── config.json
├── hooks/
│   ├── hooks.json                    ← registers PostToolUse, SessionEnd, SessionStart
│   └── scripts/
│       ├── on_skill_use.sh           ← PostToolUse: record skill name
│       ├── on_session_end.sh         ← SessionEnd: full transcript scan
│       └── on_session_start.sh       ← SessionStart: threshold check + notify
└── skills/
    └── auto-optimize-skills/
        └── SKILL.md                  ← /auto-optimize-skills skill

~/.local/share/auto-skill/            ← runtime data
├── queue.json                        ← pending optimizations and patterns
├── history.json                      ← log of past optimizations
├── transcripts.log                   ← paths of analyzed transcripts
└── user_patterns.json                ← prompt frequency tracker

~/.claude/skills-backup/              ← backups before any modification
└── {timestamp}/
    └── {skill-name}/
        └── SKILL.md
```

---

## Requirements

- Claude Code
- `git`
- `jq`

---

## Known Limitations

- **Pattern detection** uses the first 100 characters of a user prompt as a deduplication key. Semantically similar but differently worded prompts won't be grouped.
- **Transcript format**: parsed as JSONL using `jq`. If the format changes, a `grep`-based fallback activates automatically.
- The plugin observes skills invoked via the `Skill` tool. Skills triggered implicitly (Claude matching the description without a `/command`) may not always be captured by the hook, but will be caught during transcript scanning at `SessionEnd`.
