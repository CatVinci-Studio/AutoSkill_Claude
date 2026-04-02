# 🧠 auto-optimize-skills

> A Claude Code plugin that **silently watches** how you work, then helps you build better skills — automatically.

No interruptions. No manual tracking. Just use Claude normally, and let auto-optimize-skills learn from you.

![Version](https://img.shields.io/badge/version-1.0.0-blue)
![Platform](https://img.shields.io/badge/platform-Claude%20Code-blueviolet)
![Shell](https://img.shields.io/badge/language-bash-green)
![License](https://img.shields.io/badge/license-MIT-lightgrey)

---

## 📖 Table of Contents

- [✨ What It Does](#-what-it-does)
- [📦 Install](#-install)
- [🔄 How It Works](#-how-it-works)
- [⚡ Commands](#-commands)
  - [/optimize-skill](#optimize-skill)
  - [/new-skill](#new-skill)
- [⚙️ Configuration](#️-configuration)
- [🗂️ File Structure](#️-file-structure)
- [⚠️ Known Limitations](#️-known-limitations)
- [🤝 Contributing](#-contributing)

---

## ✨ What It Does

- 🔍 **Observes** every skill you invoke, without getting in your way
- 📦 **Accumulates** usage data across sessions
- 🔔 **Notifies** you when there's enough data to act on
- ⚡ **Optimizes** existing skills based on real behavior signals
- 🪄 **Creates** new skills from conversations or repeated workflows
- 💾 **Backs up** every skill before modifying it

---

## 📦 Install

```
/plugin marketplace add CatVinci-Studio/AutoSkill_Claude
/plugin install auto-optimize-skills@auto-optimize-skills
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
/plugin uninstall auto-optimize-skills@auto-optimize-skills
```

<details>
<summary>Alternative: uninstall via script</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/CatVinci-Studio/AutoSkill_Claude/main/uninstall.sh | bash
```

</details>

> Data and backups are kept after uninstall. Delete manually if no longer needed:
> ```bash
> rm -rf ~/.local/share/auto-optimize-skills
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

All observations persist in `~/.local/share/auto-optimize-skills/queue.json`:

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

### 🔔 Notification

When the queue hits the configured threshold, you'll see this at session start:

```
auto-optimize-skills: 5 skill(s) ready to optimize, 2 new pattern(s) detected.
Run /optimize-skill or /new-skill when ready.
```

You decide when to act. No interruptions.

---

## ⚡ Commands

This plugin provides two skill commands:

### `/optimize-skill`

Improve existing skills based on real usage signals.

Run it when you want to tune skills you've been using. Claude will:

1. 📋 Load the list of skills pending optimization from the queue
2. 📖 Read relevant session transcripts for each skill
3. 🔍 Identify what needs improving (see signals below)
4. 🖊️ Show you the proposed changes before writing anything
5. 💾 Back up the original, then write the improved version

```
【🔧 Skills ready to optimize】
  · arxiv        — found in 4 sessions
  · research-lit — found in 2 sessions

Which skills should I optimize? [all / select / skip]
```

**🎯 What gets improved:**

| 📡 Signal | 🛠️ What changes |
|---|---|
| You typed something related but skill didn't auto-trigger | `description` trigger phrases |
| You corrected Claude after skill ran | Step instructions |
| Skill used a tool not in `allowed-tools` | `allowed-tools` list |
| You invoked the same skill multiple times in one session | Output completeness |

---

### `/new-skill`

Create a new skill from three possible sources:

**1. 💬 From this conversation** — capture the workflow you just did with Claude into a reusable skill.

**2. 📊 From a detected pattern** — if you've repeated the same workflow 2+ times across sessions without a matching skill, Claude surfaces it as a candidate.

**3. ✏️ Describe it yourself** — tell Claude what the skill should do and it drafts one for you.

In all cases, Claude shows you a draft first and waits for your confirmation before writing anything.

```
【✨ Draft skill】

name:          export-to-zotero
description:   "Find academic papers and export to Zotero. Use when asked to find
                papers, export citations, or run /export-to-zotero."
allowed-tools: Bash, WebSearch, Read

Steps:
1. ...

Write this? [yes / edit / cancel]
```

For each new skill pattern, Claude will:

1. 📝 Draft a new `SKILL.md` based on the observed workflow
2. 🤝 Show you the draft and wait for your confirmation
3. ✅ Write the new skill only after you approve
4. 🔁 Automatically add it to the optimize queue for future improvement

---

## ⚙️ Configuration

Edit `~/.claude/plugins/auto-optimize-skills/config.json`:

```json
{
  "notify_after_skill_uses": 5,
  "notify_after_new_patterns": 2,
  "backup_dir": "~/.claude/skills-backup",
  "data_dir": "~/.local/share/auto-optimize-skills"
}
```

| Field | Default | Description |
|---|---|---|
| `notify_after_skill_uses` | `5` | Notify when N skills are in the optimize queue |
| `notify_after_new_patterns` | `2` | Notify when N repeated patterns are detected |

---

## 🗂️ File Structure

```
~/.claude/plugins/auto-optimize-skills/    ← plugin directory
├── .claude-plugin/
│   └── plugin.json
├── config.json                            ← thresholds and paths
├── hooks/
│   ├── hooks.json                         ← registers all 3 hooks
│   └── scripts/
│       ├── on_skill_use.sh                ← PostToolUse: record skill name
│       ├── on_session_end.sh              ← SessionEnd: scan transcript
│       └── on_session_start.sh            ← SessionStart: notify if ready
└── skills/
    ├── optimize-skill/
    │   └── SKILL.md                       ← /optimize-skill
    └── new-skill/
        └── SKILL.md                       ← /new-skill

~/.local/share/auto-optimize-skills/       ← runtime data
├── queue.json                             ← pending optimizations & patterns
├── history.json                           ← log of past optimizations
├── transcripts.log                        ← paths of analyzed transcripts
└── user_patterns.json                     ← prompt frequency tracker

~/.claude/skills-backup/                   ← pre-modification backups
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
