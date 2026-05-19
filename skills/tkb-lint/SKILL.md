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

1. 用 `find wiki/concepts/ -name "*.md"` 列出所有 concept 文件（含子目录）
2. 对每个 concept，检查是否有其他 concept 或 analysis 文件通过 `[[wikilink]]` 引用它
3. 检查 `wiki/_index.md` 的"相关概念"字段是否引用了它
4. 如果一个 concept 没有被任何其他文件引用 → 标记为"孤立概念"
5. 建议：合并到相关概念中或删除

### 2. 标签一致性检查

1. 从 `wiki/_index.md` 中提取所有标签
2. 用 `find wiki/concepts/ -name "*.md"` 扫描所有 concept 文件（含子目录），提取 frontmatter `tags` 字段中的标签
3. 检测可能的不一致：
   - 同义词标签（如 `#AI` vs `#人工智能`，`#LLM` vs `#大语言模型`）
   - 大小写不一致（如 `#python` vs `#Python`）
   - 层级不一致（如 `#AI` vs `#AI/LLM` 同时存在）
4. 建议统一方案

### 3. 来源标签完整性检查

1. 用 `find wiki/concepts/ -name "*.md"` 扫描所有 concept 文件（含子目录），检查是否有 `source_tag` frontmatter 字段
2. 用 `find wiki/analysis/ -name "*.md"` 扫描所有 analysis 文件（含子目录），检查是否有 `source_tag` frontmatter 字段
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

### 6. folder 字段同步检查

1. 用 `find` 扫描 `wiki/concepts/` 和 `wiki/analysis/` 下所有 `.md` 文件（含子目录）
2. 对每个文件，计算**期望 folder 值**：
   - 文件在子目录（如 `wiki/concepts/gardener/xxx.md`）→ 期望 folder = 相对于 `concepts/` 或 `analysis/` 的子路径（如 `gardener`；二级子目录取完整相对路径如 `gardener/gep`）
   - 文件在根目录（如 `wiki/concepts/xxx.md`）→ 期望 folder = 空（不应有此字段）
3. 读取每个文件 frontmatter 的实际 `folder` 字段值
4. 对比期望值 vs 实际值，收集不一致的文件
5. 边界情况：
   - 文件在根目录且无 `folder` 字段 → ✅ 正常，跳过
   - 文件在根目录但有 `folder` 字段 → 报告为"需清除 folder"
   - 文件在子目录且 `folder` 已正确设置 → ✅ 正常，跳过
6. 若有不一致文件，在报告中展示变更提案，并询问用户是否立即同步：

```
## Folder 字段不同步

以下文件的 `folder` 字段与实际所在目录不一致：

| 文件 | 当前 folder | 期望 folder |
|------|-------------|-------------|
| [[gardener-robot]] | (未设置) | gardener |
| [[agent-skills-vs-mcp]] | gardener | ai |

共 N 个文件需要更新。是否立即同步？(y/n)
```

7. 用户回答 `y` 后，对每个不一致文件：
   - 需要设置 folder → 使用 `obsidian-cli` 的 `property:set` 工具，设置 `folder` 为期望值
   - 需要清除 folder → 使用 `obsidian-cli` 的 `property:set` 工具，将 `folder` 设为空字符串
8. 同步完成后输出"已更新 N 个文件"

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
- folder 字段不同步：N 个文件
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

## Folder 字段不同步

（若无不同步文件则省略此章节）

| 文件 | 当前 folder | 期望 folder |
|------|-------------|-------------|
| [[xxx]] | (未设置) | gardener |
```

## 注意事项

- 只检测和报告，不自动修改
- 所有建议都需要用户确认后才执行
- 使用 `obsidian-markdown` 确保报告格式正确
