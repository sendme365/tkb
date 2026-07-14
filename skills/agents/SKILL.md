---
name: tkbagents
manual_only: true
description: >
  TKB 知识库文章入库（粘贴模式）。将用户粘贴到 inbox.md 的英文文章翻译为中文，
  生成双语存档和讲义式笔记，并编译进知识库（Index + Concept + Analysis）。
  触发词："入库粘贴", "处理inbox"。
  输入：[work|ttt]。内容来自 ~/SAPDevelop/Work/agent-summary/inbox.md。
  ⚠️ 此 skill 仅限用户手动触发，禁止被其他 skill 或 agent 自动调用。
---

# TKB Agents — 粘贴入库 (Paste Ingest)

将用户粘贴到 `inbox.md` 的英文文章翻译成中文，生成双语存档，并以讲义式笔记格式编译进 TKB 知识库。

## 仓库位置

```
TKB_ROOT  = $HOME/Library/Mobile\ Documents/iCloud\~md\~obsidian/Documents/TKB
INBOX     = ~/SAPDevelop/Work/agent-summary/inbox.md
```

## 第零步：解析来源标签

1. 检查参数是否为来源标签（接受：`work`、`ttt`、`#work`、`#ttt`）
2. 规范化为 `SOURCE_TAG`（值为 `#work` 或 `#ttt`）
3. 如果未提供，显示交互提示：
   ```
   未指定来源标签。请选择：
     1. work — 工作相关
     2. ttt  — 个人学习
   ```
   等待用户输入 `1` 或 `2`，不可跳过

## 第一步：读取并验证 inbox

1. 使用 Read 工具读取 `INBOX`（即 `~/SAPDevelop/Work/agent-summary/inbox.md`）
2. 如果文件不存在、内容为空，或仅包含以下哨兵占位符注释则终止，提示"请先将文章内容粘贴到 inbox.md，再运行 /tkbagents"：
   ```
   <!-- agents inbox — paste article content below this line, then run /tkbagents [work|ttt] -->
   ```
3. 提取可选标题提示：如果第一行为 `<!-- title: ... -->`，将 `...` 作为 `ARTICLE_TITLE_EN`
4. 否则从内容中推断标题：优先取第一个 H1（`# Title`），其次取第一个非空行
5. 将原文存为 `RAW_CONTENT`

## 第二步：翻译为中文

对 `RAW_CONTENT` 执行全文翻译，规则：

- 生成流畅、自然的中文，不生硬直译
- 专业术语首次出现时保留英文并附中文解释：`控制平面迁移 (Live Control Plane Migration)`
- 代码块、命令名称、专有名词原样保留
- 章节标题译为双语行内格式：`## 核心概念 (Core Concepts)`
- 生成 `ARTICLE_TITLE_ZH`（中文标题）

## 第三步：生成 slug 和目录路径

```bash
TODAY=$(date +%Y-%m-%d)
TITLE_SLUG=$(echo "$ARTICLE_TITLE_EN" \
  | tr '[:upper:]' '[:lower:]' \
  | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null \
  | sed 's/[^a-z0-9]/-/g' \
  | sed 's/-\+/-/g' \
  | sed 's/^-//;s/-$//' \
  | cut -c1-50)
ENTRY_SLUG="${TODAY}-${TITLE_SLUG}"
RAW_DIR="${TKB_ROOT}/raw/web/${ENTRY_SLUG}"
```

- 如果 `RAW_DIR` 已存在，依次尝试 `${ENTRY_SLUG}-2`、`${ENTRY_SLUG}-3`，直到找到未使用的目录名
- 若标题全为中文（iconv 无法转写），slug 降级为 `paste-${TODAY}-1`（碰撞时递增）

## 第四步：写入双语存档

使用 Bash 工具创建目录：

```bash
mkdir -p "${RAW_DIR}"
```

使用 Write 工具将以下内容写入 `${RAW_DIR}/index.md`：

```markdown
---
title: "<ARTICLE_TITLE_EN>"
title_zh: "<ARTICLE_TITLE_ZH>"
source_type: "paste"
source_tag: "<SOURCE_TAG>"
date: <YYYY-MM-DD>
type: web
lang_original: "en"
lang_translated: "zh"
---

# <ARTICLE_TITLE_EN>
# <ARTICLE_TITLE_ZH>

**来源 (Source)：** 粘贴输入（Pasted Input）
**日期 (Date)：** <YYYY-MM-DD>
**来源分区 (Source Tag)：** <SOURCE_TAG>

---

## <Section Heading EN> | <节标题中文>

<原文英文段落 1>

---

<中文翻译段落 1>

---

<原文英文段落 2>

---

<中文翻译段落 2>

---
```

**双语格式规则：** 每个原文段落紧跟其中文翻译，用 `---` 分隔。章节标题双语行内展示：`## Core Concepts | 核心概念`。不使用"全文英文 + 全文中文"的分区块格式。

## 第五步：去重检查

1. 读取 `${TKB_ROOT}/wiki/_index.md`
2. 检查是否存在 `Raw: [[raw/web/${ENTRY_SLUG}/...]]` 或高度相似的标题（模糊匹配 `ARTICLE_TITLE_EN` 和 `ARTICLE_TITLE_ZH`）
3. 如果重复：
   - 告知用户已存在，问是否覆盖或跳过
   - 如果跳过：删除 `RAW_DIR`，终止流程

## 第六步：生成讲义寄存器并编译 wiki

### 6a. 生成三种讲义寄存器

在执行编译前，先基于翻译内容生成三种寄存器，供后续步骤使用：

**Register A — 康奈尔式结构摘要（用于 Index 层摘要字段）**

```
**核心主题 (Core Theme)：** <一句话概括文章核心>
**关键术语 (Key Terms)：** **Term1 (中文1)**, **Term2 (中文2)**, ...
**要点列表 (Key Points)：**
- <要点 1>
- <要点 2>
- <要点 3>
**实践意义 (Practical Takeaway)：** <一句话实践启示>
```

**Register B — 叙述式理解总结（用于 Concept 层"核心观点"正文）**

- 流畅中文段落，每段 300-1000 字
- 第一人称视角："这篇文章让我理解了..."、"作者的核心论点是..."
- 像个人读书笔记，而非干燥摘要
- 每个核心概念一段

**Register C — 问答式复习（用于 Analysis 层）**

- 5-8 对问答
- 问题测试理解深度，而非死记硬背
- 格式：
  ```
  **Q: <关于概念的理解性问题>**
  A: <证明理解的答案>
  ```

### 6b. 共用编译流程

读取并执行 `$INGEST_REFS/wiki-compilation.md`（`INGEST_REFS="$HOME/.claude/plugins/marketplaces/tkb/skills/ingest/references"`），其中包含完整的三层编译步骤（Index 层、Concept 层、Analysis 层、反向链接更新）。

执行时的特殊适配：
- 来源类型为 `paste`，Index 层摘要字段填入 **Register A** 内容
- Concept 层"核心观点"正文填入 **Register B** 内容
- 跳过 `6a-pre`（图文联读/转录读取，仅适用于小红书和视频来源）
- Index 层来源格式使用 `[paste] 粘贴输入`，标题格式为 `<ARTICLE_TITLE_EN> | <ARTICLE_TITLE_ZH>`

### 6c. Paste 专有追加

读取并执行 `references/paste-extras.md`，在共用编译生成的 concept 和 analysis 文件上追加 paste 模式专有内容：
- Concept：追加"关键术语 (Key Terms)"双语表（来自 Register A 中的术语列表）
- Analysis：追加"复习问答 (Review Q&A)"（来自 Register C）

## 第七步：更新索引元数据

更新 `${TKB_ROOT}/wiki/_index.md` frontmatter 中的 `updated` 和 `total_entries` 字段。

## 第八步：重置 inbox

使用 Write 工具将以下哨兵内容写入 `INBOX`：

```markdown
<!-- agents inbox — paste article content below this line, then run /tkbagents [work|ttt] -->
```

## 第九步：追加入库日志

使用 Read 工具读取 `${TKB_ROOT}/output/ingest-log.md`，然后用 Edit 工具在文件顶部的 `---` 分隔线之后、已有条目之前插入新记录：

```markdown
## <YYYY-MM-DD> — agents

| 字段 | 值 |
|------|-----|
| **技能** | `agents` |
| **来源分区** | `<SOURCE_TAG>` |
| **原文标题** | <ARTICLE_TITLE_EN> |
| **中文标题** | <ARTICLE_TITLE_ZH> |
| **词条目录** | `raw/web/<ENTRY_SLUG>/` |

**产出文件：**

- [[raw/web/<ENTRY_SLUG>/index]] — 新建（双语存档）
- [[wiki/_index]] — 更新（条目 #N）
- [[wiki/concepts/<folder>/<concept-slug>]] — 新建/更新（概念）
- [[wiki/analysis/<folder>/<concept-slug>]] — 新建/更新（分析）
- [[feynman/<YYYY-MM-DD>-<concept-slug>]] — 新建（费曼笔记）

---

```

> 注意：产出文件列表必须使用 `[[wikilink]]` 格式（不含 `.md` 后缀），确保在 Obsidian 中可点击跳转。如果 concept/analysis 文件在根目录下（无子目录），省略 `<folder>/`。

## 第九点五步：Gardener 书签追加

**判断是否为 Gardener 相关内容：**

1. 以下任一条件满足即视为 Gardener 相关：
   - 用户输入包含 `--gardener` 参数
   - `ARTICLE_TITLE_EN` 或 `ARTICLE_TITLE_ZH` 中包含以下关键词之一：`Gardener`、`gardenlet`、`shoot cluster`、`seed cluster`、`Garden Project`、`SAP Gardener`
   - `RAW_CONTENT` 中高频出现上述关键词（出现 3 次以上）
2. **如果判定为 Gardener 相关**，追加写入 `${TKB_ROOT}/bookmarks/gardener-bookmarks.md`：
   - **若文件不存在**，先用 Write 工具创建：
     ```markdown
     ---
     type: gardener-bookmarks
     cssclasses:
       - bookmarks-compact
     ---

     # Gardener Bookmarks
     ```
   - **构造新条目**：
     ```markdown
     ## <ARTICLE_TITLE_EN> | <ARTICLE_TITLE_ZH>

     - **来源**：粘贴输入（Pasted Input）
     - **入库文件**：[[raw/web/<ENTRY_SLUG>/index]]
     - **Concept**：[[wiki/concepts/<concept-slug>]] 或 —
     - **Analysis**：[[wiki/analysis/<concept-slug>]] 或 —
     - **费曼笔记**：[[feynman/<YYYY-MM-DD>-<concept-slug>]] 或 —
     - **tags**：#gardener

     ---
     ```
   - 使用 Read 工具读取文件，再用 Edit 工具在 `# Gardener Bookmarks` 标题下方、第一条 `## ` 记录之前插入（逆序，最新在顶）
3. **如果判定为非 Gardener 相关**，跳过此步，不做任何操作

## 第十步：报告结果

```
入库完成 (Ingestion Complete)

来源分区：<SOURCE_TAG>
原文标题：<ARTICLE_TITLE_EN>
中文标题：<ARTICLE_TITLE_ZH>
词条目录：raw/web/<ENTRY_SLUG>/

产出文件：
  [[raw/web/<ENTRY_SLUG>/index]] — 双语存档
  [[wiki/_index]] — 索引（条目 #N）
  [[wiki/concepts/<folder>/<concept-slug>]] — 概念 [新建/更新]
  [[wiki/analysis/<folder>/<concept-slug>]] — 分析 [新建/更新]
  [[feynman/<YYYY-MM-DD>-<concept-slug>]] — 费曼笔记

inbox.md 已重置。
```

## 使用 obsidian-markdown

所有写入 Obsidian vault 的 markdown 文件都应遵循 Obsidian 规范：
- 使用 `[[wikilink]]` 语法链接其他笔记
- 使用 YAML frontmatter 定义 properties
- 使用 `> blockquote` 和 callout 做标注
- 图片使用 `![[image.png]]` 或相对路径 `./images/image.png`
