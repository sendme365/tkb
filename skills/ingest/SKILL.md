---
name: ingest
description: >
  TKB 知识库资料入库。将外部资料采集到知识库中，并打上来源标签（#work 或 #ttt）。
  触发词："入库", "添加到知识库", "收录"。
  输入：[<来源标签>] <URL或文件路径>。来源标签可选，未指定时交互提示（必选）。
---

# TKB Ingest

将外部资料采集到 TKB 知识库，并自动完成全量编译（Index + Detail + Analysis）。

## 仓库位置

TKB 知识库根目录：`$HOME/Library/Mobile\ Documents/iCloud\~md\~obsidian/Documents/TKB/`

## 来源标签

TKB 使用标签区分内容来源：
- **#work** — 工作知识库
- **#ttt** — 个人知识库

## 流程

用户输入 `[<来源标签>] <URL或文件路径>` 后，按以下步骤执行：

### 第零步：解析来源标签

1. 检查第一个参数是否为来源标签（接受以下格式：`work`、`ttt`、`#work`、`#ttt`）
2. 如果第一个参数是来源标签，将其规范化为 `#work` 或 `#ttt`，剩余参数为 URL 或文件路径
3. 如果第一个参数不是来源标签（即直接是 URL 或路径），显示交互提示：
   ```
   未指定来源标签。请选择：
     1. work — 工作相关
     2. ttt  — 个人学习
   ```
   等待用户输入 `1` 或 `2`，不可跳过
4. 将最终来源标签设为变量 `SOURCE_TAG`（值为 `#work` 或 `#ttt`）

### 第一步：判断来源类型

根据输入判断类型：
- 包含 `xiaohongshu.com` 或 `xhslink.com` → **小红书笔记**，调用 `xiaohongshu` skill，传入 `SOURCE_TAG` 和 `URL`；skill 完成后继续第四步
- 包含 `youtube.com` 或 `youtu.be` → **YouTube 视频**，读取并执行 `references/pipeline-video.md`
- 包含 `bilibili.com` 或 `b23.tv` → **Bilibili 视频**，读取并执行 `references/pipeline-video.md`
- 以 `http://` 或 `https://` 开头 → **网页**，进入第二步（网页流程）
- 以 `/` 开头且本地路径存在 `.git/` 子目录 → **本地 Git 仓库**，读取并执行 `references/pipeline-git.md`
- 以 `/` 开头但无 `.git/` → 单文件（Phase 2，提示用户）
- 其他 → 报错：`无法识别的输入格式，请提供 URL 或本地 git 仓库路径`

如果判断为本地 Git 仓库，运行以下命令确认 `.git/` 目录存在；如果结果为 "not a git repo" 则按"以 `/` 开头但无 `.git/`"分支处理：
```bash
test -d "<用户输入路径>/.git" && echo "valid git repo" || echo "not a git repo"
```

### 第二步：采集内容（仅网页来源）

对于网页 URL：
1. 使用 `defuddle` skill 或 `mcp__web_reader__webReader` 工具抓取网页内容，转为清洁 markdown
2. 如果 defuddle 失败，回退到 `mcp__web_reader__webReader`
3. 从 markdown 中提取所有图片 URL（匹配 `![...](...)` 模式）
4. 对每个图片 URL：
   a. 使用 `curl -sL -o <本地路径>` 下载
   b. 如果下载失败（curl 返回非 0 或文件为空），使用 `agent-browser` skill 截图网页作为备用
5. 将 markdown 中的图片 URL 替换为本地相对路径 `./images/<filename>`

> **其他来源类型**：视频流程见 `references/pipeline-video.md`，Git 流程见 `references/pipeline-git.md`。这两个流程完成后直接跳至 `references/wiki-compilation.md` 第四步。

### 第三步：写入 triage（仅网页来源）

1. 生成目录名：`<YYYY-MM-DD>-<slug>`（slug 从标题生成，小写+连字符，取前 50 字符）
2. 写入 `triage/web/<目录名>/index.md`
3. 图片写入 `triage/web/<目录名>/images/`

### 第四步至第六步：去重、移动、全量编译

**所有来源类型**（网页、小红书、视频、Git）在完成上方的数据采集后，读取并执行 `references/wiki-compilation.md`，其中包含：
- 第四步：去重检查
- 第五步：移动到 raw（仅网页来源）
- 第六步：全量编译（Index 层 + Detail 层 + Analysis 层 + 反向链接）

### 第七步：更新索引元数据

更新 `wiki/_index.md` 的 frontmatter 中 `updated` 和 `total_entries` 字段。

### 第七点五步：追加入库日志

使用 Read 工具读取 `${TKB_ROOT}/output/ingest-log.md`，然后用 Edit 工具在文件顶部的 `---` 分隔线之后、已有条目之前插入新记录：

```markdown
## <YYYY-MM-DD> — ingest

| 字段 | 值 |
|------|-----|
| **技能** | `ingest` |
| **来源分区** | `<SOURCE_TAG>` |
| **原文标题** | <标题> |
| **来源 URL** | `<URL>` |
| **词条目录** | `raw/<web\|video\|git>/<ENTRY_SLUG>/` |

**产出文件：**

- [[raw/<web\|video\|git>/<ENTRY_SLUG>/index]] — 新建（原始存档）
- [[wiki/_index]] — 更新（条目 #N）
- [[wiki/concepts/<folder>/<concept-slug>]] — 新建/更新（概念）
- [[wiki/analysis/<folder>/<concept-slug>]] — 新建/更新（分析）
- [[feynman/<YYYY-MM-DD>-<concept-slug>]] — 新建（费曼笔记）

---

```

> 注意：产出文件列表必须使用 `[[wikilink]]` 格式（不含 `.md` 后缀），确保在 Obsidian 中可点击跳转。如果 concept/analysis 文件在根目录下（无子目录），省略 `<folder>/`。视频来源路径含平台子目录：`raw/video/<platform>/<ENTRY_SLUG>/index`。

### 第七点七步：写入入库书签

文件路径：`${TKB_ROOT}/bookmarks/ingest-bookmarks.md`

**若文件不存在**，先用 Write 工具创建，内容如下：

```markdown
---
type: ingest-bookmarks
cssclasses:
  - bookmarks-compact
---

# Ingest Bookmarks
```

**构造新条目**（标题用原文标题，空值写「—」）：

```markdown
## <原文标题>

- **来源**：<来源URL>
- **入库文件**：[[raw/<web|video|git>/<ENTRY_SLUG>/index]]
- **Concept**：[[wiki/concepts/<concept-slug>]] 或 —
- **Analysis**：[[wiki/analysis/<concept-slug>]] 或 —
- **费曼笔记**：[[feynman/<YYYY-MM-DD>-<concept-slug>]] 或 —

---
```

使用 Read 工具读取文件，再用 Edit 工具在 `# Ingest Bookmarks` 标题下方、第一条 `## ` 记录之前插入新条目（逆序，最新在顶）。

> 注意：Concept 只取本次**新建**的主概念（第一个新建 concept），反向链接更新的 concept 不写入。视频来源路径含平台子目录：`raw/video/<platform>/<ENTRY_SLUG>/index`。

### 第八步：报告结果

向用户报告（产出文件使用 `[[wikilink]]` 格式）：

**网页来源：**
- 入库文件：`[[raw/web/<目录名>/index]]`
- 来源分区：`<SOURCE_TAG>`
- 创建/更新的 Index 条目
- 创建/更新的 Concept：`[[wiki/concepts/<folder>/<名>]]`
- 创建的 Analysis：`[[wiki/analysis/<folder>/<名>]]`
- 关联的已有概念

**Git 仓库来源：**
- 入库文件：`[[raw/git/<目录名>/index]]`
- 来源分区：`<SOURCE_TAG>`
- 提取内容：README + N 个文档文件 + 代码注释 M 行
- 创建/更新的 Index 条目
- 创建/更新的 Concept：`[[wiki/concepts/<folder>/<名>]]`
- 创建的 Analysis：`[[wiki/analysis/<folder>/<名>]]`
- 关联的已有概念

**视频来源（YouTube/Bilibili）：**
- 入库文件：`[[raw/video/<platform>/<目录名>/index]]`
- 字幕文件：`raw/video/<platform>/<目录名>/subtitles/<lang>.srt`
- 转录文件：`raw/video/<platform>/<目录名>/subtitles/transcript.txt`
- 字幕语言：`<SUB_LANG>`
- 来源分区：`<SOURCE_TAG>`
- 创建/更新的 Index 条目
- 创建/更新的 Concept：`[[wiki/concepts/<folder>/<名>]]`
- 创建的 Analysis：`[[wiki/analysis/<folder>/<名>]]`
- 关联的已有概念

## 使用 obsidian-markdown

所有写入 Obsidian vault 的 markdown 文件都应遵循 Obsidian 规范：
- 使用 `[[wikilink]]` 语法链接其他笔记
- 使用 YAML frontmatter 定义 properties
- 使用 `> blockquote` 和 `callout` 做标注
- 图片使用 `![[image.png]]` 或相对路径 `./images/image.png`
