---
name: tkb-lint
description: >
  TKB 知识库健康检查。扫描 wiki 目录，检测孤立概念、标签不一致、source_tag 缺失等问题。
  触发词："tkb lint", "知识库检查", "知识库健康", "检查知识库"。
  无需参数，扫描全库。也可由 CronCreate 定时触发。
---

# TKB Lint

TKB 知识库健康检查。检测 wiki 中的数据质量问题并生成报告。

## 仓库位置

TKB 知识库根目录：`/Users/I333878/Library/Mobile Documents/com~apple~CloudDocs/TKB/TKB/`

## 检查项

### 1. 孤立 Concept 检测

1. 列出 `wiki/concepts/` 中所有 concept 文件
2. 对每个 concept，检查是否有其他 concept 或 analysis 文件通过 `[[wikilink]]` 引用它
3. 检查 `wiki/_index.md` 的"相关概念"字段是否引用了它
4. 如果一个 concept 没有被任何其他文件引用 → 标记为"孤立概念"
5. 建议：合并到相关概念中或删除

### 2. 标签一致性检查

1. 从 `wiki/_index.md` 中提取所有标签
2. 从 `wiki/concepts/*.md` 的 frontmatter `tags` 字段中提取所有标签
3. 检测可能的不一致：
   - 同义词标签（如 `#AI` vs `#人工智能`，`#LLM` vs `#大语言模型`）
   - 大小写不一致（如 `#python` vs `#Python`）
   - 层级不一致（如 `#AI` vs `#AI/LLM` 同时存在）
4. 建议统一方案

### 3. 来源标签完整性检查

1. 检查所有 `wiki/concepts/*.md` 文件是否有 `source_tag` frontmatter 字段
2. 检查所有 `wiki/analysis/*.md` 文件是否有 `source_tag` frontmatter 字段
3. 验证 `source_tag` 值只能为 `#work` 或 `#ttt`
4. 无 `source_tag` 或值非法的文件 → 标记并建议修复

### 4. Concept 重叠检测

1. 读取所有 concept 文件的标题和核心观点
2. 检测主题高度重叠的 concept 对（通过标题相似度和内容重叠度判断）
3. 如果发现重叠 → 建议合并，列出建议合并的 concept 对

### 5. 索引完整性检查

1. 读取 `wiki/_index.md` 中的所有条目
2. 对每个条目的 `Raw:` 链接，检查对应的 raw 目录是否存在（在 `raw/web/` 或 `raw/git/` 下）
3. 对每个条目的"相关概念"链接，检查对应的 concept 文件是否存在
4. 如果发现断裂链接 → 标记并建议修复

## 报告格式

生成报告到 `output/lint-report-<YYYY-MM-DD>.md`：

```markdown
---
title: TKB 知识库健康报告
date: <YYYY-MM-DD>
type: lint-report
---

# TKB 知识库健康报告

## 概览

- Concept 总数：N
- Index 条目总数：N
- Analysis 总数：N
- 无 source_tag 的 Concept：N
- 无 source_tag 的 Analysis：N
- 发现问题：N

## 孤立概念

- [[wiki/concepts/<名>|<标题>]]：未被其他文件引用，建议合并或删除

## 标签不一致

- `#AI` ↔ `#人工智能`：建议统一为 `#AI`
- ...

## 来源标签缺失

- `wiki/concepts/<名>.md`：缺少 source_tag 字段

## Concept 重叠

- [[concept-A]] 和 [[concept-B]]：主题高度重叠，建议合并

## 断裂链接

- Index 条目"<标题>"引用的 raw 目录不存在：`raw/web/<path>/`
- ...
```

## 注意事项

- 只检测和报告，不自动修改
- 所有建议都需要用户确认后才执行
- 使用 `obsidian-markdown` 确保报告格式正确
