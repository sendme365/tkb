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

TKB 知识库根目录：`$HOME/Library/Mobile\ Documents/iCloud\~md\~obsidian/Documents/TKB/`

## 检查步骤

### 第零步：运行扫描脚本

```bash
SCRIPTS="$HOME/.claude/plugins/marketplaces/tkb/scripts"
python3 "$SCRIPTS/scan_wiki.py"
```

将脚本输出读入 context。后续所有检查项**直接基于此输出分析，不再读取任何 wiki 文件**。

脚本输出格式为 `[CHECK_N]` 分节的纯文本摘要，包含：
- `[STATS]`：文件统计
- `[CHECK1_ORPHANED]`：孤立 concept 文件名列表（或 NONE）
- `[CHECK2_TAG_HIERARCHY]`：平级标签与层级变体冲突列表（或 NONE）
- `[CHECK3_SOURCE_TAG]`：缺失或非法 source_tag 的文件列表（或 NONE）
- `[CHECK4_OVERLAP_CANDIDATES]`：共同标签 ≥3 的 concept 对列表（或 NONE）
- `[CHECK5_BROKEN_LINKS]`：_index.md 中断裂的 concept 链接（或 NONE）
- `[CHECK6_FOLDER_SYNC]`：folder 字段与实际目录不一致的文件（或 NONE）

### 检查 1：孤立 Concept（机械结果，直接采用）

从 `[CHECK1_ORPHANED]` 读取结果，写入报告。

### 检查 2：标签一致性（需语义判断）

从 `[CHECK2_TAG_HIERARCHY]` 读取层级冲突列表，对每组冲突：
- 判断平级标签（如 `Gardener`）和层级变体（如 `Gardener/Operations`）是否属于真正的不一致
- 给出统一建议（例如：将平级 `Gardener` 替换为更具体的子标签）
- 同时检测同义词（如 `#AI` vs `#人工智能`）和大小写不一致

### 检查 3：来源标签完整性（机械结果，直接采用）

从 `[CHECK3_SOURCE_TAG]` 读取结果，写入报告。

### 检查 4：Concept 重叠检测（需语义判断）

从 `[CHECK4_OVERLAP_CANDIDATES]` 读取候选对列表，对每对：
- 判断高标签重叠是否代表真正的内容重叠（版本序列、核心 vs 扩展等属于正常重叠）
- 只对真正内容重叠的 concept 对建议合并

### 检查 5：索引完整性（机械结果，直接采用）

从 `[CHECK5_BROKEN_LINKS]` 读取结果，写入报告。

### 检查 6：folder 字段同步（机械结果 + 自动修复）

从 `[CHECK6_FOLDER_SYNC]` 读取不同步文件列表。

若有不同步文件，**直接自动修复**（无需询问确认）：
- 对每个不同步文件调用 `obsidian-cli` 的 `property:set` 工具
  - 需要设置 folder → 设置为期望值
  - 需要清除 folder → 设置为空字符串
- 修复完成后在报告中注明"已自动修复 N 个文件"

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
- folder 字段不同步：N 个文件（已自动修复）
- 发现问题：N

## 孤立概念

- [[wiki/concepts/<名>|<标题>]]：未被其他文件引用，建议合并或删除

## 标签不一致

- `#Gardener` ↔ `#Gardener/Operations` 等：建议统一为层级标签
- ...

## 来源标签缺失

- `wiki/concepts/<名>.md`：缺少 source_tag 字段

## Concept 重叠

- [[concept-A]] 和 [[concept-B]]：主题高度重叠，建议合并

## 断裂链接

- Index 条目引用的 concept 文件不存在：`[[<名>]]`
- ...

## Folder 字段同步

（若无不同步文件则省略此章节）

| 文件 | 原 folder | 修复为 |
|------|-----------|--------|
| [[xxx]] | (未设置) | Gardener |
```

## 注意事项

- 检查 1、3、5、6 为机械规则判断，直接采用脚本结果
- 检查 2、4 需要语义判断，Claude 负责最终结论
- folder 字段不同步时自动修复，无需确认
- 使用 `obsidian-markdown` 确保报告格式正确
