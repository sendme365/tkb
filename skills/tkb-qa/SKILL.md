---
name: tkb-qa
description: >
  TKB 知识库查询。根据用户问题检索知识库，支持按来源过滤。
  触发词："tkb qa", "知识库问答", "查一下", "搜索知识库"。
  输入：[work:|ttt:] <问题>。前缀可选，不写则搜全库。
---

# TKB Q&A

查询 TKB 知识库并回答用户问题。采用 Wiki 为主 + Raw 按需追溯的策略。

## 仓库位置

TKB 知识库根目录：`/Users/I333878/Library/Mobile Documents/com~apple~CloudDocs/TKB/TKB/`

## 来源过滤

支持三种查询模式：
- **无前缀**（如 `问题`）— 搜索全库所有内容（FILTER=all）
- **`work:` 前缀**（如 `work: 问题`）— 只搜 #work 的 concepts 和 analysis（FILTER=work）
- **`ttt:` 前缀**（如 `ttt: 问题`）— 只搜 #ttt 的 concepts 和 analysis（FILTER=ttt）

## 查询流程

### 第零步：解析来源过滤

1. 检查输入是否以 `work:` 或 `ttt:` 开头
2. 如果有前缀，提取过滤模式（`work` 或 `ttt`），剩余部分为问题；将 `FILTER` 设为 `work` 或 `ttt`
3. 如果无前缀，`FILTER=all`，整个输入为问题

### 第一步：读 Index 定位（快速扫描）

1. 读取 `wiki/_index.md`
2. 根据用户问题，匹配相关的 Index 条目（通过标签、标题、摘要关键词匹配）
3. 如果 `FILTER != all`，只考虑包含 `来源分区：#<FILTER>` 字段的条目
4. 收集所有相关条目指向的 concept 文件和 raw 文件路径

### 第二步：读 Wiki 深入（结构化知识）

1. 读取第一步定位到的 `wiki/concepts/*.md` 文件
2. 读取相关的 `wiki/analysis/*.md` 文件
3. 如果 `FILTER != all`，只读取 frontmatter 中 `source_tag: "#<FILTER>"` 的文件
4. 基于 concept 和 analysis 的内容，尝试回答问题

### 第三步：判断是否充分

LLM 自行判断现有 wiki 内容是否足够回答问题：

**足够：**
- 直接回答用户，引用来源 concept 文件

**不够：**
- 读取相关 `raw/web/*/index.md` 或 `raw/git/*/index.md` 原始文档补充信息
- 综合回答用户，标注哪些信息来自 wiki 哪些来自 raw

### 第四步：可选回填（仅在产生有价值新洞察时）

如果回答过程中产生了新的洞察或发现了知识库中缺失的关联：

1. 询问用户是否要将新洞察写入知识库
2. 如果用户同意，创建或更新 `wiki/analysis/<topic>-analysis.md`
3. 使用 `obsidian-markdown` 确保格式正确

## 回答格式

回答问题时：
1. 先给出简洁的答案
2. 然后展开细节
3. 最后标注来源：`来源：[[wiki/concepts/<名>|<概念名>]]`
4. 如果引用了 raw 原文，也标注：`原文：[[raw/web/<目录名>/index.md|<标题>]]` 或 `[[raw/git/<目录名>/index.md|<标题>]]`

## 注意事项

- 默认搜索全库；使用 `work:` 或 `ttt:` 前缀可限定来源
- 不要编造知识库中没有的信息
- 如果知识库中没有相关内容，诚实告知用户
- 回答使用与用户问题相同的语言
