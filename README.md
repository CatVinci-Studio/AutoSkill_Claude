# 🧠 auto-skill

> A Claude Code plugin that **silently watches** how you work, then helps you build better skills — automatically.

No interruptions. No manual tracking. Just use Claude normally, and let auto-skill learn from you.

---

## ✨ What It Does

- 🔍 **Observes** every skill you invoke, without getting in your way
- 📦 **Accumulates** usage data across sessions
- 🔔 **Notifies** you when there's enough data to act on
- ⚡ **Optimizes** existing skills based on real behavior signals
- 🪄 **Creates** new skills from workflows you repeat manually
- 💾 **Backs up** every skill before modifying it

---

## 📦 Install

```
/plugin marketplace add CatVinci-Studio/AutoSkill_Claude
/plugin install auto-skill@auto-skill
```

Restart Claude Code after installation.

<details>
<summary>Alternative: install via script (requires <code>git</code>, <code>jq</code>)</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/CatVinci-Studio/AutoSkill_Claude/main/install.sh | bash
```

</details>

## 🗑️ Uninstall

```
/plugin uninstall auto-skill@auto-skill
```

<details>
<summary>Alternative: uninstall via script</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/CatVinci-Studio/AutoSkill_Claude/main/uninstall.sh | bash
```

</details>

> Data and backups are kept after uninstall. Delete manually if no longer needed:
> ```bash
> rm -rf ~/.local/share/auto-skill
> rm -rf ~/.claude/skills-backup
> ```

---

## 🔄 How It Works

### Three hooks run silently in the background

| Hook | Trigger | Action |
|---|---|---|
| 🎯 `PostToolUse` (Skill) | Every skill invocation | Records skill name to live flag file |
| 🔚 `SessionEnd` | When you close Claude Code | Scans full transcript, updates queue |
| 🚀 `SessionStart` | When you open Claude Code | Checks queue, notifies if threshold met |

### The queue

All observations persist in `~/.local/share/auto-skill/queue.json`:

```json
{
  "to_optimize": ["arxiv", "research-lit"],
  "to_create": [
    { "pattern": "find papers then summarize and export to Zotero", "frequency": 3 }
  ]
}
```

- **`to_optimize`** — skills that were used, candidates for improvement
- **`to_create`** — prompts you typed 2+ times without a matching skill, candidates for new skills

### Notification

When the queue hits the configured threshold, you'll see this at session start:

```
autoSkill: 5 skill(s) ready to optimize, 2 new pattern(s) detected.
Run /auto-optimize-skills when ready.
```

You decide when to act. No interruptions.

---

## ⚡ Usage

Run `/auto-optimize-skills` at any point — **mid-session or after closing and reopening**.

Claude reads both the historical queue (past sessions) and the current session's live data, then shows you:

```
【🔧 Optimize existing skills】
  · arxiv        — used 4 times
  · research-lit — used 2 times

【✨ Suggested new skills】
  · "find papers then summarize and export to Zotero" — seen 3 times

How to proceed? [all / select / skip]
```

For each skill you select, Claude will:

1. 📖 Read the relevant session transcripts
2. 🔍 Identify what could be improved (see signals below)
3. 📋 Show you the proposed changes before writing anything
4. 💾 Back up the original, then write the improved version

For each new skill pattern, Claude will:

1. 📝 Draft a new `SKILL.md` based on the observed workflow
2. 🤝 Show you the draft and wait for your confirmation
3. ✅ Write the new skill only after you approve

---

## 🎯 What Gets Improved

| 📡 Signal | 🛠️ What changes |
|---|---|
| You typed something related but skill didn't auto-trigger | `description` trigger phrases |
| You corrected Claude after skill ran | Step instructions |
| Skill used a tool not in `allowed-tools` | `allowed-tools` list |
| You invoked the same skill multiple times in one session | Output completeness |
| You repeated a workflow 2+ times with no matching skill | New skill created |

---

## ⚙️ Configuration

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
| `notify_after_skill_uses` | `5` | Notify when N skills are in the optimize queue |
| `notify_after_new_patterns` | `2` | Notify when N repeated patterns are detected |

---

## 🗂️ File Structure

```
~/.claude/plugins/auto-skill/          ← plugin directory
├── .claude-plugin/
│   └── plugin.json
├── config.json                        ← thresholds and paths
├── hooks/
│   ├── hooks.json                     ← registers all 3 hooks
│   └── scripts/
│       ├── on_skill_use.sh            ← PostToolUse: record skill name
│       ├── on_session_end.sh          ← SessionEnd: scan transcript
│       └── on_session_start.sh        ← SessionStart: notify if ready
└── skills/
    └── auto-optimize-skills/
        └── SKILL.md                   ← /auto-optimize-skills

~/.local/share/auto-skill/             ← runtime data
├── queue.json                         ← pending optimizations & patterns
├── history.json                       ← log of past optimizations
├── transcripts.log                    ← paths of analyzed transcripts
└── user_patterns.json                 ← prompt frequency tracker

~/.claude/skills-backup/               ← pre-modification backups
└── {timestamp}/
    └── {skill-name}/
        └── SKILL.md
```

---

## ⚠️ Known Limitations

- **Pattern detection** uses the first 100 characters of a user prompt as a deduplication key — semantically similar but differently worded prompts won't be grouped
- **Transcript parsing** uses `jq` on JSONL format with a `grep`-based fallback if parsing fails
- Skills triggered **implicitly** (Claude matching description without a `/command`) may not be captured by the PostToolUse hook, but will be caught during transcript scanning at `SessionEnd`

---

## 🤝 Contributing

Issues and PRs welcome at [CatVinci-Studio/AutoSkill_Claude](https://github.com/CatVinci-Studio/AutoSkill_Claude).

The `dev` branch contains work-in-progress features including a dedicated `skill-analyzer` sub-agent for deeper transcript analysis.
