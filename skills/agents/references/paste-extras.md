# Paste 模式追加内容

此文件由 `tkbagents` 在 wiki-compilation.md 编译完成后执行，为 paste（粘贴翻译）来源追加讲义专有内容。

## 前置条件

执行此文件前，`wiki-compilation.md` 的第六步（全量编译）已完成，concept 和 analysis 文件已创建或更新。

`ARTICLE_TITLE_EN`、`ENTRY_SLUG`、三种 Register（A/B/C）均已在 `tkbagents` 的前序步骤中生成。

---

## 步骤 E1：向 Concept 追加"关键术语"节

在 `wiki/concepts/<concept-slug>.md` 的"来源"节**前**插入以下内容（如果该节已存在则跳过）：

```markdown
## 关键术语 (Key Terms)

| English | 中文 | 说明 |
|---------|------|------|
| Term1 | 术语1 | <简短说明> |
| Term2 | 术语2 | <简短说明> |
```

**术语来源：** 从 Register A 的 `**关键术语 (Key Terms)：**` 字段提取，补充原文中其他首次出现并标注了中文的专业术语（格式：`术语 (Term)`）。每行一个术语，去重。

---

## 步骤 E2：向 Analysis 追加"复习问答"节

在 `wiki/analysis/<concept-slug>.md` 的"批判性思考"节**前**插入以下内容（如果该节已存在则跳过）：

```markdown
## 复习问答 (Review Q&A)

**Q: <关于概念的理解性问题>**
A: <证明理解的答案>

**Q: <关于概念的理解性问题>**
A: <证明理解的答案>
```

**问答来源：** Register C（5-8 对问答）。问题测试理解深度，而非死记硬背。
