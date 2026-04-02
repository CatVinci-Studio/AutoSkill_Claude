# 🧠 auto-skill

> 一个 Claude Code 插件，**静默观察**你的工作方式，自动帮你打造更好的 skill。

无需打断工作流，无需手动记录。正常使用 Claude，让 auto-skill 在背后学习。

---

## ✨ 功能特性

- 🔍 **静默观察** 你调用的每一个 skill，完全不影响正常使用
- 📦 **跨 session 积累** 使用数据，持久化存储
- 🔔 **达到阈值时提醒** 你，不会主动打断
- ⚡ **基于真实行为信号优化** 现有 skill
- 🪄 **从重复的手动操作中自动创建** 新 skill
- 💾 **修改前自动备份**，随时可恢复

---

## 📦 安装

```bash
curl -fsSL https://raw.githubusercontent.com/CatVinci-Studio/AutoSkill_Claude/main/install.sh | bash
```

安装完成后重启 Claude Code 即可生效。

**依赖：** `git`、`jq`

## 🗑️ 卸载

```bash
curl -fsSL https://raw.githubusercontent.com/CatVinci-Studio/AutoSkill_Claude/main/uninstall.sh | bash
```

> 卸载后数据和备份会保留，如不需要可手动删除：
> ```bash
> rm -rf ~/.local/share/auto-skill
> rm -rf ~/.claude/skills-backup
> ```

---

## 🔄 工作原理

### 三个 Hook 在后台静默运行

| Hook | 触发时机 | 做什么 |
|---|---|---|
| 🎯 `PostToolUse`（Skill） | 每次调用 skill 时 | 记录 skill 名称到实时标记文件 |
| 🔚 `SessionEnd` | 关闭 Claude Code 时 | 扫描完整对话记录，更新队列 |
| 🚀 `SessionStart` | 打开 Claude Code 时 | 检查队列，达到阈值时提醒 |

### 队列数据

所有观测数据持久化存储在 `~/.local/share/auto-skill/queue.json`：

```json
{
  "to_optimize": ["arxiv", "research-lit"],
  "to_create": [
    { "pattern": "找论文然后总结导出到 Zotero", "frequency": 3 }
  ]
}
```

- **`to_optimize`** — 被调用过的 skill，待优化候选
- **`to_create`** — 你反复手动输入（2次+）但没有对应 skill 的操作，待新建候选

### 提醒通知

队列达到配置的阈值后，下次打开 Claude Code 时会看到：

```
autoSkill: 5 个 skill 待优化，2 个新模式已检测到。
准备好后运行 /auto-optimize-skills。
```

**你决定什么时候处理，不会被打断。**

---

## ⚡ 使用方式

随时运行 `/auto-optimize-skills`——**session 中途或关闭重开后都可以**。

Claude 会同时读取历史队列（过去的 session）和当前 session 的实时数据，然后展示：

```
【🔧 优化现有 skill】
  · arxiv        — 使用了 4 次
  · research-lit — 使用了 2 次

【✨ 建议新建 skill】
  · "找论文然后总结导出到 Zotero" — 出现 3 次

如何处理？[全部 / 逐个选择 / 跳过]
```

对于每个你选择优化的 skill，Claude 会：

1. 📖 读取相关 session 的对话记录
2. 🔍 识别可以改进的地方（见下方信号说明）
3. 📋 向你展示改动内容，**写入前等待确认**
4. 💾 备份原文件，再写入改进版本

对于每个新 skill 候选，Claude 会：

1. 📝 根据观测到的操作流程起草 `SKILL.md`
2. 🤝 展示草稿，等待你确认
3. ✅ 确认后才写入

---

## 🎯 会改进什么

| 📡 信号来源 | 🛠️ 改进方向 |
|---|---|
| 你输入了相关内容但 skill 没有自动触发 | `description` 触发词 |
| skill 执行后你进行了补充或纠正 | 步骤指令 |
| skill 实际用了未声明的工具 | `allowed-tools` 列表 |
| 同一个 skill 在一个 session 内被多次调用 | 输出完整性 |
| 你重复了某个工作流但没有对应的 skill | 新建 skill |

---

## ⚙️ 配置

编辑 `~/.claude/plugins/auto-skill/config.json`：

```json
{
  "notify_after_skill_uses": 5,
  "notify_after_new_patterns": 2,
  "backup_dir": "~/.claude/skills-backup",
  "data_dir": "~/.local/share/auto-skill"
}
```

| 字段 | 默认值 | 说明 |
|---|---|---|
| `notify_after_skill_uses` | `5` | 队列中有 N 个 skill 时提醒 |
| `notify_after_new_patterns` | `2` | 检测到 N 个重复模式时提醒 |

---

## 🗂️ 文件结构

```
~/.claude/plugins/auto-skill/          ← 插件目录
├── .claude-plugin/
│   └── plugin.json
├── config.json                        ← 阈值和路径配置
├── hooks/
│   ├── hooks.json                     ← 注册三个 hook
│   └── scripts/
│       ├── on_skill_use.sh            ← PostToolUse：记录 skill 名称
│       ├── on_session_end.sh          ← SessionEnd：扫描对话记录
│       └── on_session_start.sh        ← SessionStart：检查并提醒
└── skills/
    └── auto-optimize-skills/
        └── SKILL.md                   ← /auto-optimize-skills

~/.local/share/auto-skill/             ← 运行时数据
├── queue.json                         ← 待优化队列和模式
├── history.json                       ← 历史优化记录
├── transcripts.log                    ← 已分析的对话记录路径
└── user_patterns.json                 ← 用户 prompt 频次统计

~/.claude/skills-backup/               ← 修改前的备份
└── {时间戳}/
    └── {skill 名称}/
        └── SKILL.md
```

---

## ⚠️ 已知限制

- **模式检测** 使用用户 prompt 的前 100 个字符作为去重 key——语义相近但措辞不同的 prompt 不会被合并
- **对话记录解析** 优先使用 `jq` 解析 JSONL 格式，解析失败时自动切换到 `grep` 兜底
- **隐式触发**的 skill（Claude 自行匹配描述，用户未输入 `/command`）不会被 PostToolUse hook 捕捉，但 `SessionEnd` 扫描对话记录时会补捉

---

## 🤝 参与贡献

欢迎提 Issue 和 PR：[CatVinci-Studio/AutoSkill_Claude](https://github.com/CatVinci-Studio/AutoSkill_Claude)

`dev` 分支包含进行中的功能，包括用于深度对话记录分析的专用 `skill-analyzer` 子 agent。
