---
name: tkb-agents
description: >
  TKB 知识库文章入库（粘贴模式）。将用户粘贴到 inbox.md 的英文文章翻译为中文，
  生成双语存档和讲义式笔记，并编译进知识库（Index + Concept + Analysis）。
  触发词："tkb agents", "入库粘贴", "处理inbox", "tkb-agents"。
  输入：[work|ttt]。内容来自 /Users/I333878/SAPDevelop/Work/agent-summary/inbox.md。
---

# TKB Agents — 粘贴入库 (Paste Ingest)

将用户粘贴到 `inbox.md` 的英文文章翻译成中文，生成双语存档，并以讲义式笔记格式编译进 TKB 知识库。

## 仓库位置

```
TKB_ROOT  = /Users/I333878/Library/Mobile Documents/com~apple~CloudDocs/TKB/TKB
INBOX     = /Users/I333878/SAPDevelop/Work/agent-summary/inbox.md
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

1. 使用 Read 工具读取 `INBOX`（即 `/Users/I333878/SAPDevelop/Work/agent-summary/inbox.md`）
2. 如果文件不存在、内容为空，或仅包含以下哨兵占位符注释则终止，提示"请先将文章内容粘贴到 inbox.md，再运行 /tkb-agents"：
   ```
   <!-- tkb-agents inbox — paste article content below this line, then run /tkb-agents [work|ttt] -->
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

## 第六步：生成讲义三层寄存器并编译 wiki

### 6a. 生成三种讲义寄存器

**Register A — 康奈尔式结构摘要（用于 Index 层）**

```
**核心主题 (Core Theme)：** <一句话概括文章核心>
**关键术语 (Key Terms)：** **Term1 (中文1)**, **Term2 (中文2)**, ...
**要点列表 (Key Points)：**
- <要点 1>
- <要点 2>
- <要点 3>
**实践意义 (Practical Takeaway)：** <一句话实践启示>
```

**Register B — 叙述式理解总结（用于 Concept 层正文）**

- 流畅中文段落，每段 300-500 字
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

### 6b. 读取已有知识库状态

1. 读取 `${TKB_ROOT}/wiki/_index.md` 获取已有条目和标签
2. 使用 `obsidian-cli` 搜索 `wiki/concepts/` 中是否有相关概念
3. 使用 `obsidian-cli` 搜索 `wiki/analysis/` 中是否有相关分析

### 6c. Index 层

追加到 `${TKB_ROOT}/wiki/_index.md` 的"最近入库"部分：

```markdown
### <ARTICLE_TITLE_EN> | <ARTICLE_TITLE_ZH>
- **来源：** [paste] 粘贴输入
- **日期：** <YYYY-MM-DD>
- **标签：** #tag1 #tag2 #tag3
- **来源分区：** <SOURCE_TAG>
- **摘要：** <Register A 内容>
- **相关概念：** [[concept-A]] [[concept-B]]
- **Raw：** [[raw/web/<ENTRY_SLUG>/index.md]]
```

标签提取规则：
- 从文章内容中自动提取 3-5 个核心标签
- 优先复用 `wiki/_index.md` 中已出现的标签
- 新标签使用 Obsidian 嵌套格式：`#大类/子类`（如 `#AI/LLM`）

### 6d. Concept 层

使用 `obsidian-cli` 创建或更新 `${TKB_ROOT}/wiki/concepts/<concept-slug>.md`。

**如果是新概念：**

```markdown
---
title: <概念名>
tags: [<tag1>, <tag2>]
related: "[[<相关concept>]]"
sources: "[[raw/web/<ENTRY_SLUG>/index.md]]"
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
type: concept
source_tag: "<SOURCE_TAG>"
---

# <概念名>

## 核心观点 (Core Understanding)

<Register B — 叙述式理解段落>

## 关键术语 (Key Terms)

| English | 中文 | 说明 |
|---------|------|------|
| Term1 | 术语1 | <简短说明> |
| Term2 | 术语2 | <简短说明> |

## 行动项 / 收获 (Takeaways)

<读完文章后可采取的行动或获得的认识>

## 来源 (Sources)

- [[raw/web/<ENTRY_SLUG>/index.md|<ARTICLE_TITLE_EN>]]

<SOURCE_TAG>
```

**如果更新已有概念：**

1. 读取已有 concept 文件
2. 在"核心观点"部分追加新内容（不删除已有内容）
3. 在"关键术语"表追加新术语（去重）
4. 在"来源"部分追加新 raw 链接
5. 更新 `updated` 日期
6. 追加新标签到 `tags` 列表

### 6e. Analysis 层

创建或追加 `${TKB_ROOT}/wiki/analysis/<concept-slug>.md`：

```markdown
---
title: "<概念名>" 深度分析
tags: [<tag1>, <tag2>]
concepts: "[[<concept名>]]"
related_analysis: "[[<相关analysis>]]"
sources: "[[raw/web/<ENTRY_SLUG>/index.md]]"
created: <YYYY-MM-DD>
type: analysis
source_tag: "<SOURCE_TAG>"
---

# <概念名> 深度分析

## 复习问答 (Review Q&A)

<Register C — 问答对>

## 批判性思考 (Critical Analysis)

<对原文观点的批判性评估：优点、局限、适用边界>

## 跨概念关联 (Cross-Concept Links)

<与知识库中其他概念的关系：
- [[concept-A]]：...
- [[concept-B]]：...
>

## 知识图谱建议 (Knowledge Graph Suggestions)

<建议后续探索的方向或需补充的知识>

## 开放问题 (Open Questions)

<文章引发但未回答的问题>

<SOURCE_TAG>
```

如果 analysis 文件已存在，在"复习问答"和"批判性思考"部分追加新内容，不覆盖。

### 6f. 更新反向链接

如果 6d 中 concept 的 `related` 字段非空，确保双向链接存在（使用 `obsidian-cli` 搜索并更新相关文件）。

## 第七步：更新索引元数据

更新 `${TKB_ROOT}/wiki/_index.md` frontmatter 中的 `updated` 和 `total_entries` 字段。

## 第八步：重置 inbox

使用 Write 工具将以下哨兵内容写入 `INBOX`：

```markdown
<!-- tkb-agents inbox — paste article content below this line, then run /tkb-agents [work|ttt] -->
```

## 第九步：报告结果

```
入库完成 (Ingestion Complete)

来源分区：<SOURCE_TAG>
原文标题：<ARTICLE_TITLE_EN>
中文标题：<ARTICLE_TITLE_ZH>
词条目录：raw/web/<ENTRY_SLUG>/

产出文件：
  - 双语存档：raw/web/<ENTRY_SLUG>/index.md
  - 索引条目：wiki/_index.md (条目 #N)
  - 概念文件：wiki/concepts/<concept-slug>.md [新建/更新]
  - 分析文件：wiki/analysis/<concept-slug>.md [新建/更新]

inbox.md 已重置。
```

## 使用 obsidian-markdown

所有写入 Obsidian vault 的 markdown 文件都应遵循 Obsidian 规范：
- 使用 `[[wikilink]]` 语法链接其他笔记
- 使用 YAML frontmatter 定义 properties
- 使用 `> blockquote` 和 callout 做标注
- 图片使用 `![[image.png]]` 或相对路径 `./images/image.png`
