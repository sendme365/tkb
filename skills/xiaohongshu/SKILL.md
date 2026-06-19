---
name: xiaohongshu
description: >
  TKB 小红书笔记入库。通过 Obsidian 插件静默导入小红书笔记内容（文字 + 图片），
  存入 TKB 知识库并编译 wiki。
  触发词：由 ingest 内部调用，或直接使用 "xiaohongshu", "小红书入库"。
  输入：<SOURCE_TAG> <小红书URL>
---

# TKB Xiaohongshu Ingest

将小红书笔记采集到 TKB 知识库，通过 Obsidian `xiaohongshu-importer` 插件静默导入。

## 仓库位置

TKB 知识库根目录：`$HOME/Library/Mobile Documents/iCloud~md~obsidian/Documents/TKB/`

## 前置条件

Obsidian 必须处于运行状态，且 `xiaohongshu-importer` 插件已启用。

验证：

```bash
obsidian vault="TKB" eval code="app.plugins.getPlugin('xiaohongshu-importer') ? 'ok' : 'not loaded'"
```

## 流程

### Step 1：接收参数

接收以下参数（来自 ingest 或直接调用）：
- `URL`：小红书笔记 URL（`xiaohongshu.com/explore/...` 格式；不支持已失效的 `xhslink.com` 短链）
- `SOURCE_TAG`：`#work` 或 `#ttt`（默认 `#ttt`）
- `CATEGORY`：笔记分类，映射规则：`#work` → `工作`，`#ttt` → `知识`（默认）

### Step 2：静默导入

通过 Obsidian eval 直接调用插件内部方法，完全跳过 UI 对话框：

```bash
obsidian vault="TKB" eval code="(async () => { const p = app.plugins.getPlugin('xiaohongshu-importer'); await p.importXHSNote('<URL>', '<CATEGORY>', false); })()"
```

插件将：
1. 用 `requestUrl` fetch 笔记页面 HTML
2. 解析 `window.__INITIAL_STATE__` 提取标题、正文、图片列表
3. 在 `XHS/<CATEGORY>/` 目录下创建 Markdown 文件

等待 3 秒让异步操作完成：

```bash
sleep 3
```

### Step 3：获取生成的文件路径

```bash
obsidian vault="TKB" eval code="app.workspace.getActiveFile()?.path"
```

将结果记为 `IMPORTED_PATH`（格式：`XHS/<CATEGORY>/<标题>.md`）。

如果结果为 null 或路径不以 `XHS/` 开头，说明导入失败——检查 URL 是否有效，报错中止。

### Step 4：读取导入内容

```bash
obsidian vault="TKB" read path="<IMPORTED_PATH>"
```

确认文件内容非空（title 字段有值，正文非 "Content not found"）。

如果正文为 "Content not found"，说明页面被反爬或需要登录——提示用户用浏览器验证 URL 内容可访问，然后中止。

### Step 5：移动到 raw/web/

将导入文件移动到 TKB 标准的 raw/web 路径：

1. 生成目标路径：
   - `RAW_PATH` = `raw/web/xiaohongshu-<YYYY-MM-DD>-<slug>.md`
   - slug：取标题前 50 字符，转小写，空格换连字符，去除特殊字符

2. 执行移动：

```bash
obsidian vault="TKB" eval code="app.vault.rename(app.vault.getAbstractFileByPath('<IMPORTED_PATH>'), '<RAW_PATH>')"
```

3. 更新 frontmatter，添加 `source_tag` 字段：

```bash
obsidian vault="TKB" property:set name="source_tag" value="<SOURCE_TAG>" path="<RAW_PATH>"
```

### Step 6：返回控制权

完成后，将以下信息传递给 ingest 继续执行：
- `RAW_PATH`：raw 文件路径（供第四步去重检查和第六步编译使用）
- `NOTE_TITLE`：笔记标题（从 frontmatter `title` 字段读取）
- 来源类型标记：`xiaohongshu`

继续执行 ingest 的：
- **第四步：去重检查**（匹配 `source` URL）
- **第六步：全量编译**

## 错误处理

| 场景 | 处理方式 |
|------|----------|
| Obsidian 未运行 | 提示用户打开 Obsidian，中止 |
| 插件未加载 | 提示用户在 Obsidian 中启用 xiaohongshu-importer 插件，中止 |
| URL 已失效（404）| 报错提示，不继续 |
| 正文为 "Content not found" | 提示可能被反爬，建议用浏览器验证 URL，中止 |
| `getActiveFile()` 返回 null | 导入未完成，等待 2 秒后重试一次，仍失败则中止 |
