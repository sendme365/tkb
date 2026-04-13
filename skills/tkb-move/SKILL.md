---
name: tkb-move
description: >
  废弃（Deprecated）。单分区架构下不再需要分区间迁移功能。
  如需修改内容来源标签，直接编辑对应 concept 和 analysis 文件的 source_tag 字段。
---

# TKB Move（已废弃）

> **此 Skill 已废弃。** TKB 已从双分区迁移至单分区架构。

原功能（在 work/ttt 两个分区之间迁移内容）在单分区架构下不再存在。

## 如果需要修改内容的来源标签

直接编辑对应文件：
1. `wiki/concepts/<名>.md` — 修改 frontmatter 中的 `source_tag` 字段（值为 `#work` 或 `#ttt`）
2. `wiki/analysis/<名>-analysis.md` — 同上
3. `wiki/_index.md` — 修改对应条目的 `来源分区` 字段
