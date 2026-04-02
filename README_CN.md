# 🧠 auto-optimize-skills

> 一个 Claude Code 插件，**静默观察**你的工作方式，自动帮你打造更好的 skill。

无需打断工作流，无需手动记录。正常使用 Claude，让 auto-optimize-skills 在背后学习。

![Version](https://img.shields.io/badge/版本-1.0.0-blue)
![Platform](https://img.shields.io/badge/平台-Claude%20Code-blueviolet)
![Shell](https://img.shields.io/badge/语言-bash-green)
![License](https://img.shields.io/badge/协议-MIT-lightgrey)

---

## 📖 目录

- [✨ 功能特性](#-功能特性)
- [📦 安装](#-安装)
- [🔄 工作原理](#-工作原理)
- [⚡ 命令](#-命令)
  - [/optimize-skill](#optimize-skill)
  - [/new-skill](#new-skill)
- [⚙️ 配置](#️-配置)
- [🗂️ 文件结构](#️-文件结构)
- [⚠️ 已知限制](#️-已知限制)
- [🤝 参与贡献](#-参与贡献)

---

## ✨ 功能特性

- 🔍 **静默观察** 你调用的每一个 skill，完全不影响正常使用
- 📦 **跨 session 积累** 使用数据，持久化存储
- 🔔 **达到阈值时提醒** 你，不会主动打断
- ⚡ **基于真实行为信号优化** 现有 skill
- 🪄 **从当前对话或重复工作流中自动创建** 新 skill
- 💾 **修改前自动备份**，随时可恢复

---

## 📦 安装

```
/plugin marketplace add CatVinci-Studio/AutoSkill_Claude
/plugin install auto-optimize-skills@auto-optimize-skills
```

安装完成后重启 Claude Code 即可生效。

<details>
<summary>备选：通过脚本安装（需要 <code>git</code>、<code>jq</code>）</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/CatVinci-Studio/AutoSkill_Claude/main/install.sh | bash
```

</details>

## 🗑️ 卸载

```
/plugin uninstall auto-optimize-skills@auto-optimize-skills
```

<details>
<summary>备选：通过脚本卸载</summary>

```bash
curl -fsSL https://raw.githubusercontent.com/CatVinci-Studio/AutoSkill_Claude/main/uninstall.sh | bash
```

</details>

> 卸载后数据和备份会保留，如不需要可手动删除：
> ```bash
> rm -rf ~/.local/share/auto-optimize-skills
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

所有观测数据持久化存储在 `~/.local/share/auto-optimize-skills/queue.json`：

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

### 🔔 提醒通知

队列达到配置的阈值后，下次打开 Claude Code 时会看到：

```
auto-optimize-skills: 5 个 skill 待优化，2 个新模式已检测到。
准备好后运行 /optimize-skill 或 /new-skill。
```

**你决定什么时候处理，不会被打断。**

---

## ⚡ 命令

本插件提供两个 skill 命令：

### `/optimize-skill`

基于真实使用信号优化现有 skill。

当你想调整已经在用的 skill 时运行。Claude 会：

1. 📋 从队列中加载待优化的 skill 列表
2. 📖 为每个 skill 读取相关的 session 对话记录
3. 🔍 识别可以改进的地方（见下方信号说明）
4. 🖊️ 向你展示改动内容，**写入前等待确认**
5. 💾 备份原文件，再写入改进版本

```
【🔧 待优化 skill】
  · arxiv        — 出现在 4 个 session 中
  · research-lit — 出现在 2 个 session 中

如何处理？[全部 / 逐个选择 / 跳过]
```

**🎯 会改进什么：**

| 📡 信号来源 | 🛠️ 改进方向 |
|---|---|
| 你输入了相关内容但 skill 没有自动触发 | `description` 触发词 |
| skill 执行后你进行了补充或纠正 | 步骤指令 |
| skill 实际用了未声明的工具 | `allowed-tools` 列表 |
| 同一个 skill 在一个 session 内被多次调用 | 输出完整性 |

---

### `/new-skill`

从三种来源创建新 skill：

**1. 💬 从当前对话** — 把你刚才和 Claude 做的工作流捕捉成一个可复用的 skill。

**2. 📊 从检测到的模式** — 如果你跨多个 session 重复了同一个工作流（2次+）但没有对应 skill，Claude 会把它作为候选呈现给你。

**3. ✏️ 自己描述** — 告诉 Claude 这个 skill 要做什么，Claude 帮你起草。

三种方式都会先展示草稿，**确认后才写入**。

```
【✨ 草稿 skill】

name:          export-to-zotero
description:   "找论文并导出到 Zotero。当你说找论文、导出引用、
                或运行 /export-to-zotero 时触发。"
allowed-tools: Bash, WebSearch, Read

步骤：
1. ...

写入？[yes / edit / cancel]
```

对于每个新 skill，Claude 会：

1. 📝 根据观测到的工作流起草 `SKILL.md`
2. 🤝 展示草稿，等待你确认
3. ✅ 确认后才写入
4. 🔁 自动加入优化队列，后续可通过 `/optimize-skill` 继续改进

---

## ⚙️ 配置

编辑 `~/.claude/plugins/auto-optimize-skills/config.json`：

```json
{
  "notify_after_skill_uses": 5,
  "notify_after_new_patterns": 2,
  "backup_dir": "~/.claude/skills-backup",
  "data_dir": "~/.local/share/auto-optimize-skills"
}
```

| 字段 | 默认值 | 说明 |
|---|---|---|
| `notify_after_skill_uses` | `5` | 队列中有 N 个 skill 时提醒 |
| `notify_after_new_patterns` | `2` | 检测到 N 个重复模式时提醒 |

---

## 🗂️ 文件结构

```
~/.claude/plugins/auto-optimize-skills/    ← 插件目录
├── .claude-plugin/
│   └── plugin.json
├── config.json                            ← 阈值和路径配置
├── hooks/
│   ├── hooks.json                         ← 注册三个 hook
│   └── scripts/
│       ├── on_skill_use.sh                ← PostToolUse：记录 skill 名称
│       ├── on_session_end.sh              ← SessionEnd：扫描对话记录
│       └── on_session_start.sh            ← SessionStart：检查并提醒
└── skills/
    ├── optimize-skill/
    │   └── SKILL.md                       ← /optimize-skill
    └── new-skill/
        └── SKILL.md                       ← /new-skill

~/.local/share/auto-optimize-skills/       ← 运行时数据
├── queue.json                             ← 待优化队列和模式
├── history.json                           ← 历史优化记录
├── transcripts.log                        ← 已分析的对话记录路径
└── user_patterns.json                     ← 用户 prompt 频次统计

~/.claude/skills-backup/                   ← 修改前的备份
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
