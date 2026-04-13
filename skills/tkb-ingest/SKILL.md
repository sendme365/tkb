---
name: tkb-ingest
description: >
  TKB 知识库资料入库。将外部资料采集到知识库中，并打上来源标签（#work 或 #ttt）。
  触发词："tkb ingest", "入库", "添加到知识库", "收录", "tkb-ingest"。
  输入：[<来源标签>] <URL或文件路径>。来源标签可选，未指定时交互提示（必选）。
---

# TKB Ingest

将外部资料采集到 TKB 知识库，并自动完成全量编译（Index + Detail + Analysis）。

## 仓库位置

TKB 知识库根目录：`/Users/I333878/Library/Mobile Documents/com~apple~CloudDocs/TKB/TKB/`

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
- 包含 `youtube.com` 或 `youtu.be` → YouTube 视频（Phase 2）
- 包含 `bilibili.com` 或 `b23.tv` → Bilibili 视频（Phase 2）
- 以 `http://` 或 `https://` 开头 → **网页**，进入第二步（网页流程）
- 以 `/` 开头且本地路径存在 `.git/` 子目录 → **本地 Git 仓库**，进入 Git 流程（第二步 Git 分支）
- 以 `/` 开头但无 `.git/` → 单文件（Phase 2，提示用户）
- 其他 → 报错：`无法识别的输入格式，请提供 URL 或本地 git 仓库路径`

如果判断为本地 Git 仓库，运行以下命令确认 `.git/` 目录存在；如果结果为 "not a git repo" 则按"以 `/` 开头但无 `.git/`"分支处理：
```bash
test -d "<用户输入路径>/.git" && echo "valid git repo" || echo "not a git repo"
```

### 第二步：采集内容

对于网页 URL：
1. 使用 `defuddle` skill 或 `mcp__web_reader__webReader` 工具抓取网页内容，转为清洁 markdown
2. 如果 defuddle 失败，回退到 `mcp__web_reader__webReader`
3. 从 markdown 中提取所有图片 URL（匹配 `![...](...)` 模式）
4. 对每个图片 URL：
   a. 使用 `curl -sL -o <本地路径>` 下载
   b. 如果下载失败（curl 返回非 0 或文件为空），使用 `agent-browser` skill 截图网页作为备用
5. 将 markdown 中的图片 URL 替换为本地相对路径 `./images/<filename>`

### 第二步（Git）：采集 Git 仓库内容

仅在来源类型为本地 Git 仓库时执行。

#### 2g-a. 提取仓库元数据

运行以下 bash 命令提取元数据（通过 Bash 工具执行）：

```bash
# 仓库名
REPO_NAME=$(basename "<用户输入路径>")

# 远程 origin URL（如有）
REMOTE_URL=$(git -C "<用户输入路径>" remote get-url origin 2>/dev/null || echo "local-only")

# 当前分支
BRANCH=$(git -C "<用户输入路径>" rev-parse --abbrev-ref HEAD)

# 最新 commit hash（短）
COMMIT=$(git -C "<用户输入路径>" rev-parse --short HEAD)

# commit 日期
COMMIT_DATE=$(git -C "<用户输入路径>" log -1 --format="%ci" | cut -d' ' -f1)
```

#### 2g-b. 收集文档文件

按优先级依次收集，将内容存入变量供 2g-c 使用：

1. **README**：查找 `README.md`、`README.rst`、`README.txt`（取第一个存在的）
   ```bash
   find "<用户输入路径>" -maxdepth 2 -iname "README*" | head -5
   ```

2. **文档目录下所有 .md 文件**：
   ```bash
   find "<用户输入路径>/docs" -name "*.md" 2>/dev/null
   find "<用户输入路径>/doc" -name "*.md" 2>/dev/null
   ```

3. **根目录其余 .md 文件**（排除 README）：
   ```bash
   find "<用户输入路径>" -maxdepth 1 -name "*.md" ! -iname "README*"
   ```

4. **代码注释提取**（每种语言最多 200 行，避免内容过大）：
   ```bash
   # Python docstrings + # comments
   grep -rn --include="*.py" -E '""".*"""|#\s.+' "<用户输入路径>/src" 2>/dev/null | head -200

   # JS/TS // comments and /** */ blocks
   grep -rn --include="*.ts" --include="*.js" -E '//\s.+|/\*\*' "<用户输入路径>/src" 2>/dev/null | head -200
   ```
   如果没有 `src/` 目录，将搜索路径替换为仓库根目录。

5. **目录树结构**：
   ```bash
   find "<用户输入路径>" -not -path '*/.git/*' -not -path '*/node_modules/*' -not -path '*/__pycache__/*' | head -100
   ```

#### 2g-c. 组装 raw content

将 2g-a 和 2g-b 收集的内容合并，使用 Write 工具写入文件（见第三步 Git）。组装格式如下：

```markdown
---
title: "<REPO_NAME>"
source_url: "<REMOTE_URL>"
source_type: "git"
branch: "<BRANCH>"
commit_hash: "<COMMIT>"
date: <COMMIT_DATE>
type: git
---

# <REPO_NAME>

**仓库路径 (Repository Path)：** `<用户输入路径>`
**远程地址 (Remote URL)：** <REMOTE_URL>
**分支 (Branch)：** <BRANCH>　**最新提交 (Latest Commit)：** <COMMIT>

## 目录结构 (Directory Structure)

```
<find 输出的目录树>
```

## README

<README.md 完整内容>

## 文档 (Documentation)

<docs/**/*.md 内容，每个文件前加 ### <文件名> 标题>

## 代码注释摘录 (Code Comments)

<提取的注释，按文件分组，每组前加 ### <文件路径> 标题>
```

### 第三步：写入 triage

1. 生成目录名：`<YYYY-MM-DD>-<slug>`（slug 从标题生成，小写+连字符，取前 50 字符）
2. 写入 `triage/web/<目录名>/index.md`
3. 图片写入 `triage/web/<目录名>/images/`

### 第三步（Git）：直接写入 raw

仅在来源类型为本地 Git 仓库时执行。跳过 triage，直接写入 raw。

1. 生成目录名：`<COMMIT_DATE>-<repo-slug>`（repo-slug = 仓库名小写 + 连字符，取前 50 字符）
2. 创建目录：`raw/git/<目录名>/`
3. 使用 Write 工具将 2g-c 中组装的 markdown 写入 `raw/git/<目录名>/index.md`

```bash
mkdir -p "/Users/I333878/Library/Mobile Documents/com~apple~CloudDocs/TKB/TKB/raw/git/<目录名>"
```

注意：不需要 `images/` 子目录，git 仓库内容不含网页图片。

### 第四步：去重检查

1. 读取 `wiki/_index.md` 的内容
2. 检查是否已存在相同 URL 或高度相似标题的条目
   - 网页来源：匹配 `source_url`
   - Git 来源：匹配 `source_url`（remote origin）；若为 `local-only`，匹配仓库路径
3. 如果重复：
   - 告知用户已存在，问是否覆盖或跳过
   - 如果跳过：
     - 网页：删除 triage 中的文件
     - Git：删除 `raw/git/<目录名>/` 目录
4. 如果不重复，继续

### 第五步：移动到 raw（仅网页来源）

仅在来源类型为网页时执行。Git 来源已在第三步（Git）直接写入 raw，跳过此步骤。

```bash
mv "triage/web/<目录名>" "raw/web/<目录名>"
```

### 第六步：全量编译

这是核心步骤，一次性生成三层产出。

#### 6a. 读取已有知识库状态

1. 读取 `wiki/_index.md` 获取已有条目和标签
2. 使用 `obsidian-cli` 搜索 `wiki/concepts/` 中是否有相关概念
3. 使用 `obsidian-cli` 搜索 `wiki/analysis/` 中是否有相关分析

#### 6b. Index 层

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

标签提取规则：
- 从文章内容中自动提取 3-5 个核心标签
- 优先使用已有标签（检查 `wiki/_index.md` 中已出现的标签）
- 新标签使用 Obsidian 嵌套格式：`#大类/子类`（如 `#AI/LLM`）
- 标签使用中文或英文，保持一致

相关概念判断规则：
- 如果已存在高度相关的 concept（主题重合度 > 70%），关联已有 concept
- 如果是全新主题，标记为新 concept（将在 6c 创建）

#### 6c. Detail 层

使用 `obsidian-cli` 创建或更新 concept 文件。

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
---

# <概念名>

## 核心观点

<从原文中提取 3-5 个核心观点，每个用简洁的一句话描述>

## 关键细节

<原文中的重要细节、数据、论证，用列表或段落呈现>

## 行动项 / 收获

<读完这篇文章后可以采取的行动或获得的认识>

## 来源

- [[raw/<web 或 git>/<目录名>/index.md|<标题>]]

<SOURCE_TAG>
```

**如果更新已有概念：**
1. 读取已有的 concept 文件
2. 在"核心观点"和"关键细节"部分追加新内容（不删除已有内容）
3. 在"来源"部分追加新的 raw 链接
4. 更新 `updated` 日期
5. 如果引入了新标签，追加到 `tags` 列表
6. 使用 `obsidian-markdown` skill 确保格式正确

注意：`sources` 路径根据来源类型选择 `web/` 或 `git/` 子目录：
- 网页：`sources: "[[raw/web/<目录名>/index.md]]"`
- Git：`sources: "[[raw/git/<目录名>/index.md]]"`

#### 6d. Analysis 层

创建 `wiki/analysis/<概念名>-analysis.md`：

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

注意：`sources` 路径根据来源类型选择 `web/` 或 `git/` 子目录：
- 网页：`sources: "[[raw/web/<目录名>/index.md]]"`
- Git：`sources: "[[raw/git/<目录名>/index.md]]"`

#### 6e. 更新反向链接

1. 对于 6c/6d 中关联的所有 concept 和 analysis 文件，确保双向链接存在
2. 使用 `obsidian-cli` 搜索并更新

### 第七步：更新索引元数据

更新 `wiki/_index.md` 的 frontmatter 中 `updated` 和 `total_entries` 字段。

### 第八步：报告结果

向用户报告：

**网页来源：**
- 入库文件：`raw/web/<目录名>/index.md`
- 来源分区：`<SOURCE_TAG>`
- 创建/更新的 Index 条目
- 创建/更新的 Concept：`wiki/concepts/<名>.md`
- 创建的 Analysis：`wiki/analysis/<名>-analysis.md`
- 关联的已有概念

**Git 仓库来源：**
- 入库文件：`raw/git/<目录名>/index.md`
- 来源分区：`<SOURCE_TAG>`
- 提取内容：README + N 个文档文件 + 代码注释 M 行
- 创建/更新的 Index 条目
- 创建/更新的 Concept：`wiki/concepts/<名>.md`
- 创建的 Analysis：`wiki/analysis/<名>-analysis.md`
- 关联的已有概念

## 使用 obsidian-markdown

所有写入 Obsidian vault 的 markdown 文件都应遵循 Obsidian 规范：
- 使用 `[[wikilink]]` 语法链接其他笔记
- 使用 YAML frontmatter 定义 properties
- 使用 `> blockquote` 和 `callout` 做标注
- 图片使用 `![[image.png]]` 或相对路径 `./images/image.png`
