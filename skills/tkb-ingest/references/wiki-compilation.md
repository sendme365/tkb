# Wiki 编译流程

所有来源类型（网页、Git、视频、小红书）在完成数据采集后，都执行此文件中的步骤（第四步至第六步）。

## 第四步：去重检查

1. 读取 `wiki/_index.md` 的内容
2. 检查是否已存在相同 URL 或高度相似标题的条目
   - 网页来源：匹配 `source_url`
   - Git 来源：匹配 `source_url`（remote origin）；若为 `local-only`，匹配仓库路径
   - 视频来源：匹配 `source_url`（完整 URL）或 `video_id`（防止 youtu.be/youtube.com 同一视频重复入库）
3. 如果重复：
   - 告知用户已存在，问是否覆盖或跳过
   - 如果跳过：
     - 网页：删除 triage 中的文件
     - Git：删除 `raw/git/<目录名>/` 目录
     - 视频：删除 `raw/video/<platform>/<目录名>/` 目录
4. 如果不重复，继续

## 第五步：移动到 raw（仅网页来源）

仅在来源类型为网页时执行。Git 来源已在第三步（Git）直接写入 raw，视频来源已在第三步（视频）直接写入 raw，跳过此步骤。

如来源类型为小红书，源目录在 `triage/xiaohongshu/` 下：

```bash
mv "triage/xiaohongshu/<目录名>" "raw/web/<目录名>"
```

如来源类型为普通网页，使用：

```bash
mv "triage/web/<目录名>" "raw/web/<目录名>"
```

## 第六步：全量编译

这是核心步骤，一次性生成三层产出。

### 6a-pre. 图文联读（仅小红书来源）/ 转录读取（仅视频来源）

**小红书来源**：在开始编译前，使用 Read 工具依次读取 `raw/web/<目录名>/images/` 下所有文件：

1. 读取 `index.md` 获取文字正文
2. 用 Read 工具读取每张图片（`img-01.jpg`、`img-02.jpg`... 及 `screenshot.png`）
3. Claude 综合图文内容进行分析，后续 6b/6c/6d 步骤中，核心观点和关键细节应**同时融合文字和图片中的信息**

**视频来源（YouTube/Bilibili）**：在开始编译前，读取 `$FINAL_DIR/subtitles/transcript.txt`，将完整转录内容用于 6b/6c/6d 中的核心观点提取和分析。

普通网页来源跳过此步骤。

### 6a. 读取已有知识库状态

1. 读取 `wiki/_index.md` 获取已有条目和标签
2. 使用 `obsidian-cli` 搜索 `wiki/concepts/` 中是否有相关概念
3. 使用 `obsidian-cli` 搜索 `wiki/analysis/` 中是否有相关分析

### 6b. Index 层

追加到 `wiki/_index.md` 的"最近入库"部分：

**网页来源格式：**
```markdown
### <标题>
- **来源：** [web](<原始URL>)
- **日期：** <YYYY-MM-DD>
- **标签：** #tag1 #tag2 #tag3
- **来源分区：** <SOURCE_TAG>
- **摘要：** <一段话概括核心要点，50-100字>
- **相关概念：** [[concept-A]] [[concept-B]]
- **Raw：** [[raw/web/<目录名>/index.md]]
```

**Git 仓库来源格式：**
```markdown
### <REPO_NAME>
- **来源：** [git](<REMOTE_URL>)　**提交 (Commit)：** `<COMMIT>`
- **日期：** <COMMIT_DATE>
- **标签：** #tag1 #tag2 #tag3
- **来源分区：** <SOURCE_TAG>
- **摘要：** <从 README 自动提取项目描述，50-100字>
- **相关概念：** [[concept-A]] [[concept-B]]
- **Raw：** [[raw/git/<目录名>/index.md]]
```

**视频来源格式：**
```markdown
### <VIDEO_TITLE>
- **来源：** [<platform>](<URL>)　**频道：** <CHANNEL>
- **日期：** <VIDEO_DATE>　**时长：** <DURATION>
- **标签：** #tag1 #tag2 #tag3
- **来源分区：** <SOURCE_TAG>
- **摘要：** <从转录内容提取核心要点，50-100字>
- **相关概念：** [[concept-A]] [[concept-B]]
- **Raw：** [[raw/video/<platform>/<目录名>/index.md]]
```

标签提取规则：
- 从文章内容中自动提取 3-5 个核心标签
- 优先使用已有标签（检查 `wiki/_index.md` 中已出现的标签）
- 新标签使用 Obsidian 嵌套格式：`#大类/子类`（如 `#AI/LLM`）
- 标签使用中文或英文，保持一致

相关概念判断规则：
- 如果已存在高度相关的 concept（主题重合度 > 70%），关联已有 concept
- 如果是全新主题，标记为新 concept（将在 6c 创建）

### 6c. Detail 层

使用 `obsidian-cli` 创建或更新 concept 文件。

**原则：新建 concept 数量 = 用户提供的链接数量。**
- 用户提供 1 个链接 → 新建 1 个 concept；提供 N 个链接 → 新建 N 个 concept（一一对应）
- 禁止从单篇原文中拆分出多个 concept；背景知识、子概念、相关组件一律写入该原文对应的 concept 文件内
- 已有 concept 的更新不受此限制

**判断新概念 vs 已有概念：**
在写入前，先用 Bash 检查是否已有同名 concept 文件（含子目录）：
```bash
SCRIPTS="$HOME/.claude/plugins/marketplaces/tkb/scripts"
bash "$SCRIPTS/find_wiki.sh" concept '<概念名>'
```
- exit 0（找到）→ **更新已有概念**（使用输出的实际路径，无论在哪个子目录）
- exit 2（未找到）→ **新概念**，写入根目录 `wiki/concepts/<概念名>.md`

**如果是新概念：**
创建 `wiki/concepts/<概念名>.md`：

```markdown
---
title: <概念名>
tags: [<tag1>, <tag2>]
related: "[[<相关concept>]]"
sources: "[[raw/<web 或 git>/<目录名>/index.md]]"
created: <YYYY-MM-DD>
updated: <YYYY-MM-DD>
type: concept
source_tag: "<SOURCE_TAG>"
folder: <子目录名（若在根目录则留空）>
---

# <概念名>

## 核心观点

<从原文提取 5-8 个核心论点，每条用 1-2 句话描述，要覆盖文章的主要主张，不要只挑最显眼的几条>

## 背景与动机

<为什么这个主题 / 问题重要？作者的出发点是什么？解决了什么现有痛点或填补了什么空白？>

## 关键细节

<原文中的重要细节、数据、案例、论证过程——展开叙述，不要只罗列要点。每个细节都要有足够上下文让读者无需回看原文就能理解>

## 局限性 / 反驳观点

<原文中提到的局限、边界条件、未解决的问题，或从其他角度看该观点的潜在弱点。若原文未涉及，可补充合理的批判性思考>

## 行动项 / 收获

<读完后可以采取的具体行动，或改变了什么认知框架——要具体到可操作，不要泛泛而谈>

## 来源

- [[raw/<web 或 git>/<目录名>/index.md|<标题>]]

<SOURCE_TAG>
```

**如果更新已有概念：**
1. 读取已有的 concept 文件
2. 在"核心观点"、"背景与动机"和"关键细节"部分追加新内容（不删除已有内容）
3. 若文件缺少"背景与动机"或"局限性 / 反驳观点" section，补充创建
4. 在"来源"部分追加新的 raw 链接
5. 更新 `updated` 日期
6. 如果引入了新标签，追加到 `tags` 列表
7. 使用 `obsidian-markdown` skill 确保格式正确

注意：`sources` 路径根据来源类型选择对应子目录：
- 网页：`sources: "[[raw/web/<目录名>/index.md]]"`
- Git：`sources: "[[raw/git/<目录名>/index.md]]"`
- 视频：`sources: "[[raw/video/<platform>/<目录名>/index.md]]"`

### 6d. Analysis 层

**判断新建 vs 已有：**
在写入前，先用 Bash 检查是否已有同名 analysis 文件（含子目录）：
```bash
SCRIPTS="$HOME/.claude/plugins/marketplaces/tkb/scripts"
bash "$SCRIPTS/find_wiki.sh" analysis '<概念名>'
```
- exit 0（找到）→ 追加新洞察到该文件（使用输出的实际路径）
- exit 2（未找到）→ 创建到根目录 `wiki/analysis/<概念名>.md`

创建 `wiki/analysis/<概念名>.md`：

```markdown
---
title: "<概念名>" 深度分析
tags: [<tag1>, <tag2>]
concepts: "[[<concept名>]]"
related_analysis: "[[<相关analysis>]]"
sources: "[[raw/<web 或 git>/<目录名>/index.md]]"
created: <YYYY-MM-DD>
type: analysis
source_tag: "<SOURCE_TAG>"
folder: <子目录名（若在根目录则留空）>
---

# <概念名> 深度分析

## 批判性思考

<对原文观点的批判性评估：优点、局限、潜在问题、适用边界>

## 跨概念关联

<与已有知识库中其他概念的关系：
- [[concept-A]] 的关系：...
- [[concept-B]] 的关系：...
- 可能存在的新关联：...
>

## 知识图谱建议

<基于当前分析，建议后续探索的方向或需要补充的知识>

## 开放问题

<这篇文章引发但未回答的问题>

<SOURCE_TAG>
```

注意：如果已存在同名 analysis 文件，追加新洞察而非覆盖。

注意：`sources` 路径根据来源类型选择对应子目录：
- 网页：`sources: "[[raw/web/<目录名>/index.md]]"`
- Git：`sources: "[[raw/git/<目录名>/index.md]]"`
- 视频：`sources: "[[raw/video/<platform>/<目录名>/index.md]]"`

### 6e. 更新反向链接

**跳过条件：** 如果 6c 中新建/更新的 concept 文件的 `related` 字段为空（即无任何关联 concept），则跳过本步，不执行反向链接操作。

1. 对于 6c/6d 中关联的所有 concept 和 analysis 文件，确保双向链接存在
2. 使用 `obsidian-cli` 搜索并更新

### 6f. 费曼笔记

在 6c 创建/更新 concept 后，使用 Write 工具在以下路径创建费曼笔记：

```
$HOME/Library/Mobile Documents/com~apple~CloudDocs/TKB/TKB/feynman/<YYYY-MM-DD>-<concept-slug>.md
```

其中：
- `<YYYY-MM-DD>` 为今天的日期
- `<concept-slug>` 与 6c 中创建/更新的 concept 文件名相同（不含 `.md` 后缀）

**文件模板：**

```markdown
---
title: "<概念名称> — 费曼笔记"
concept: "[[wiki/concepts/<concept-slug>]]"
source_tag: "<SOURCE_TAG>"
created: <YYYY-MM-DD>
type: feynman
---

## 一句话核心

<用不超过 30 个字直接说明：这是什么 / 做了什么 / 得出什么结论。禁止使用"本文探讨了"等元描述句式开头>

## 核心概念解析

<提取 3-5 个最重要的概念，用白话解释（假设读者对该领域一无所知）。每个概念先用类比（"就像……"），再解释，再说为什么重要。每条 2-4 句话>

## 逻辑架构梳理

<用树状 Markdown 列表（2-3 层）还原原文逻辑结构：
- 问题/背景
  - 现状痛点
  - 现有方案的不足
- 核心主张
  - 论点
  - 支撑依据
- 结论/方案

忠实反映原文结构，不加主观评论>

## 个人行动启发

1. **<行动标题>**：<具体使用场景> → <预期效果>
2. **<行动标题>**：<具体使用场景> → <预期效果>
3. **<行动标题>**：<具体使用场景> → <预期效果>

（2-3 条，禁止"多思考"、"深入学习"等模糊表述）

## 知识漏洞（我还不懂的地方）

<读完后仍未解答的问题，诚实列出知识盲区。若已全部理解，写：暂无，待深入使用后补充>
```

**内容要求：**
- 正文总字数目标：600-1000 字（不含 frontmatter）
- 「一句话核心」不超过 30 字，禁止以"本文探讨了"等元描述句式开头
- 「核心概念解析」每条先类比（"就像……"）再解释再说重要性，每条 2-4 句
- 「逻辑架构梳理」严格用树状列表，2-3 层深，忠实反映原文，不加主观评论
- 「个人行动启发」2-3 条，每条须有加粗标题 + 具体场景 + 预期效果，禁止模糊表述
- 「知识漏洞」诚实列出，若无则写"暂无，待深入使用后补充"
