---
name: bookmark
description: >
  收藏书签到 TKB vault。触发词：bookmark、书签、收藏。
  输入格式：bookmark <URL> <一句话描述>
  例：bookmark https://github.com/simonw/datasette 把 SQLite 变成 API 的工具
---

# TKB Bookmark

轻量书签收藏工具。将 URL 和一句话描述追加到 `bookmarks/bookmarks.md`，方便以后查找。

## 仓库位置

TKB 知识库根目录：`$HOME/Library/Mobile\ Documents/iCloud\~md\~obsidian/Documents/TKB/`

书签文件：`bookmarks/bookmarks.md`

## 流程

### Step 1 — 解析输入

从用户输入中提取 URL 和描述。

- URL：以 `http://` 或 `https://` 开头的部分
- 描述：URL 之后的所有文字

**若描述为空**，使用 `WebFetch` 访问该 URL，自动生成一句话中文描述（≤30 字，说清楚"是什么/干什么"）。
只有在无法访问该 URL 时，才停止并提示用户补充描述。

### Step 2 — 写入书签文件

书签文件路径：`$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/TKB/bookmarks/bookmarks.md`

**若文件不存在**，创建文件，内容如下：

```markdown
---
type: bookmarks
---

# Bookmarks

- [<URL>](<URL>) — <描述>
```

**若文件已存在**，在 `# Bookmarks` 标题下方、第一条记录**之前**插入新条目：

```markdown
- [<URL>](<URL>) — <描述>
```

新条目始终在列表最顶部，保持时间逆序。

### Step 3 — 确认

输出：

```
✓ 已添加书签：<URL>
```
