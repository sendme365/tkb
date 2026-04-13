---
name: tkb-remove
description: >
  TKB 知识库删除。从知识库中完整移除一条资料及其所有关联的 wiki 产出（概念文件、分析文件、索引条目）。
  触发词："tkb remove", "删除知识", "移除知识", "tkb-remove"。
  输入：<raw路径或标题关键词>。无需 scope 参数。
---

# TKB Remove

从 TKB 知识库中删除一条资料及其所有关联产出。

## 仓库位置

TKB 知识库根目录：`/Users/I333878/Library/Mobile Documents/com~apple~CloudDocs/TKB/TKB/`

## 流程

### 第一步：定位目标

用户可以通过以下方式指定要删除的内容：
1. 直接提供 raw 路径片段（如 `2026-04-11-article`，不需要包含 `raw/web/` 或 `raw/git/` 前缀）
2. 提供标题关键词

根据用户提供的信息：
1. 如果是路径片段，在 `raw/web/` 和 `raw/git/` 下分别查找对应目录（先 web 后 git）
2. 如果是关键词，读取 `wiki/_index.md` 搜索匹配的条目，从条目的 `**Raw：**` 字段提取路径
3. 如果找不到匹配项，告知用户

### 第二步：确认删除

**向用户确认：** 展示将要删除的内容列表，要求用户明确确认。

### 第三步：清理 `wiki/_index.md`

1. 读取 `wiki/_index.md`
2. 删除对应的 Index 条目（`### <标题>` 到下一个 `###` 之间的内容）
3. 更新 frontmatter 中的 `total_entries`（减 1）和 `updated` 日期

### 第四步：处理关联的 Concepts

1. 从 raw 文件的 content 或 Index 条目中确定关联的 concept 文件
2. 搜索 `wiki/concepts/` 中引用了该 raw 文件的 concept
3. 对每个关联的 concept：
   a. 读取 concept 文件的 `sources` 字段
   b. 如果该 concept 只引用了这一条 raw → **删除整个 concept 文件**
   c. 如果该 concept 引用了多条 raw → 从 concept 中移除这条 raw 的贡献内容：
      - 从 `sources` 列表中移除
      - 从正文中移除该条 raw 贡献的观点和细节
      - 更新 `updated` 日期
      - 如果 `sources` 为空，删除整个 concept 文件

### 第五步：处理关联的 Analysis

1. 搜索 `wiki/analysis/` 中引用了该 raw 文件的 analysis
2. 对每个关联的 analysis：
   a. 在文件中标注"来源已移除：`<raw路径>`"
   b. 不自动删除 analysis（分析可能仍有独立价值）

### 第六步：删除 raw 目录

提示用户手动运行删除命令（Claude 无法执行 `rm -rf`）：

```bash
# 网页来源
rm -rf "/Users/I333878/Library/Mobile Documents/com~apple~CloudDocs/TKB/TKB/raw/web/<目录名>"

# Git 来源
rm -rf "/Users/I333878/Library/Mobile Documents/com~apple~CloudDocs/TKB/TKB/raw/git/<目录名>"
```

### 第七步：报告结果

向用户报告：
- 删除的 raw 目录（提示手动执行）
- 删除的 Index 条目
- 删除或更新的 Concept 文件
- 标注了的 Analysis 文件
- 建议用户手动检查的内容（如被标注的 analysis 是否还有价值）
