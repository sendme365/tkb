---
name: tkb-link
description: >
  TKB 知识库全局关联扫描。修复 related 字段中缺失的反向链接，发现新的跨概念关联。
  触发词："tkb link", "关联扫描", "修复反向链接", "跨概念关联", "tkb-link"。
---

# TKB Link

全库跨概念关联 (Cross-Concept Association) 扫描与修复工具。修复 `related` 字段中缺失的反向链接，并发现新的概念关联。

## 仓库位置

TKB 知识库根目录：`/Users/I333878/Library/Mobile Documents/com~apple~CloudDocs/TKB/TKB/`

## 设计原则

**不在 tkb-ingest 中执行** — ingest 只建立"新内容 → 已有 concept"的直接关联，保持入库流程轻量。全局关联分析由本 skill 独立承担，按需手动触发，避免每次入库都扫全库（token 消耗随知识库增长线性上涨）。

## 流程

### 第一步：读取全库 Concept 列表

读取 `wiki/concepts/*.md` 所有文件，逐一提取：

| 字段 | 用途 |
|------|------|
| 文件名（不含 `.md`）| wikilink 标识符，如 `gardener-sre-ops` |
| `title` | 显示名称 |
| `tags` | 标签列表，用于重叠判断 |
| `related` | 现有关联，避免重复添加 |
| 核心观点前 3 条 | 约 200 字，用于语义判断 |

### 第二步：两两语义比较

对所有 concept **两两**进行主题关联判断。

**判断维度（优先级从高到低）：**
1. **已有单向关联** — `related` 字段中存在 `[[B]]` 但 B 的 `related` 中没有 `[[A]]` → 直接判定为"缺失反向链接"，无需进一步分析
2. **标签重叠** — `tags` 字段有共同标签 → 较高关联可能
3. **标题/关键词相似** — 标题词汇重叠
4. **内容语义** — 核心观点有互补、对比、或因果关系

**关联强度分级：**
- **强关联** → 更新 `related` 字段：主题高度重叠（>60%）或明确互相引用
- **弱关联** → 在 analysis 的"跨概念关联"章节追加说明：有间接关系但主题不同

**跳过条件：**
- 已在 `related` 字段中**双向**存在 → 跳过

### 第三步：生成关联提案（不修改文件）

先生成提案供用户确认，格式如下：

```
## 关联提案

### 补全反向链接（已有关联但方向缺失）

- agent-skills-vs-mcp.related 缺少 ← [[gardener-sre-ops]]
  建议：在 related 字段追加 [[gardener-sre-ops]]

- gardener-robot.related 缺少 ← [[gardener-sre-ops]]
  建议：在 related 字段追加 [[gardener-sre-ops]]

### 新发现的关联

- [[concept-A]] ↔ [[concept-B]]
  理由：两者均涉及 XXX，A 的核心观点 N 与 B 的核心观点 M 有直接因果关系
  建议关联强度：强/弱

无新关联 — 所有关联已完整（如果确实没有新发现）
```

### 第四步：用户确认后执行

等待用户明确确认（"确认"、"全部执行"、或指定执行部分提案）后，按以下规则执行：

**补全反向链接：**
1. 读取目标 concept 文件
2. 在 `related` frontmatter 字段末尾追加缺失的 wikilink
3. 格式保持一致（逗号分隔，`"[[A]], [[B]]"` 形式）

**新关联（强）：**
1. 双向追加 `related` 字段（A 追加 B，B 追加 A）

**新关联（弱）：**
1. 在对应的 `wiki/analysis/<concept>-analysis.md` 的"跨概念关联"章节追加说明
2. 如无 analysis 文件，跳过（不强制创建）

### 第五步：报告

输出执行结果：
```
## 执行结果

- 修复的反向链接：N 条
  - agent-skills-vs-mcp.related ← [[gardener-sre-ops]] ✅
  - ...

- 新建立的强关联：N 条
  - [[A]] ↔ [[B]] ✅

- 发现的弱关联：N 条（已记录于 analysis，未修改 related 字段）
  - [[C]] ~ [[D]]：理由...
```

## 注意事项

- **不自动执行** — 始终生成提案后等待用户确认
- **不覆盖已有 `related`** — 只追加缺失的链接，不删除现有链接
- **弱关联不修改 `related`** — 只在 analysis 文件中记录，保持 `related` 字段语义精确
- **幂等性** — 运行多次结果相同；若无缺失关联，提示"所有关联已完整"
