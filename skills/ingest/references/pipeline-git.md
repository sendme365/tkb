# Git 仓库采集流程

仅在来源类型为本地 Git 仓库时执行此文件中的步骤。完成后返回主流程继续第四步。

## 第二步（Git）：采集 Git 仓库内容

### 2g-a. 提取仓库元数据

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

### 2g-b. 收集文档文件

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

### 2g-c. 组装 raw content

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

## 第三步（Git）：直接写入 raw

仅在来源类型为本地 Git 仓库时执行。跳过 triage，直接写入 raw。

1. 生成目录名：`<COMMIT_DATE>-<repo-slug>`（repo-slug = 仓库名小写 + 连字符，取前 50 字符）
2. 创建目录：`raw/git/<目录名>/`
3. 使用 Write 工具将 2g-c 中组装的 markdown 写入 `raw/git/<目录名>/index.md`

```bash
mkdir -p "$HOME/Library/Mobile\ Documents/iCloud\~md\~obsidian/Documents/TKB/raw/git/<目录名>"
```

注意：不需要 `images/` 子目录，git 仓库内容不含网页图片。

---

**完成后**：返回主流程，继续执行`references/wiki-compilation.md`中的第四步。
