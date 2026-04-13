---
name: tkb-xiaohongshu
description: >
  TKB 小红书笔记入库。通过浏览器自动化抓取小红书笔记内容（文字 + 图片 + 截屏），
  存入 TKB 知识库并编译 wiki。
  触发词：由 tkb-ingest 内部调用，或直接使用 "tkb xiaohongshu", "小红书入库"。
  输入：<SOURCE_TAG> <小红书URL>
---

# TKB Xiaohongshu Ingest

将小红书笔记采集到 TKB 知识库，自动完成图文抓取与 wiki 编译。

## 仓库位置

TKB 知识库根目录：`/Users/I333878/Library/Mobile Documents/com~apple~CloudDocs/TKB/TKB/`

## 前置条件：首次登录

首次使用前，需要完成一次性登录流程（之后自动复用登录状态）：

```bash
agent-browser --session-name xiaohongshu open https://www.xiaohongshu.com
```

在浏览器中完成登录（扫码或账号密码），然后：

```bash
agent-browser close
```

登录状态自动保存到 `~/.agent-browser/sessions/`，后续所有调用自动复用，无需再次登录。

## 流程

### Step 1：接收参数

接收以下参数（来自 tkb-ingest 或直接调用）：
- `URL`：小红书笔记 URL（支持 `xiaohongshu.com` 和 `xhslink.com` 短链）
- `SOURCE_TAG`：`#work` 或 `#ttt`（默认 `#ttt`）

### Step 2：打开笔记页面

使用 agent-browser 复用已保存的登录会话打开笔记：

```bash
agent-browser --session-name xiaohongshu open "<URL>"
agent-browser wait --load networkidle
```

如果页面显示登录提示或内容为空，说明 session 已过期，提示用户重新执行首次登录流程，然后中止。

### Step 3：截屏

对整个页面截屏，作为笔记的视觉备份：

```bash
agent-browser screenshot --full
```

将截屏文件记录为变量 `SCREENSHOT_PATH`（agent-browser 返回的临时文件路径）。

### Step 4：提取文字内容

#### 4a. 获取页面标题

```bash
agent-browser get title
```

将结果记为 `NOTE_TITLE`。

#### 4b. 提取笔记正文和作者

执行以下 JavaScript 提取笔记核心内容：

```bash
agent-browser eval --stdin <<'EVALEOF'
JSON.stringify({
  title: document.querySelector('#detail-title')?.innerText
    || document.querySelector('.title')?.innerText
    || document.title,
  author: document.querySelector('.author-wrapper .username')?.innerText
    || document.querySelector('.user-name')?.innerText
    || '',
  body: document.querySelector('#detail-desc')?.innerText
    || document.querySelector('.desc')?.innerText
    || document.querySelector('.note-content')?.innerText
    || '',
  imageUrls: Array.from(document.querySelectorAll('.note-slider-img, .swiper-slide img, .content img'))
    .map(img => img.src || img.dataset.src)
    .filter(src => src && src.startsWith('http') && !src.includes('avatar'))
})
EVALEOF
```

将 JSON 结果解析为：
- `NOTE_TITLE`：标题（优先用 JS 提取，fallback 到 `agent-browser get title`）
- `NOTE_AUTHOR`：作者昵称
- `NOTE_BODY`：正文文字
- `IMAGE_URLS`：图片 URL 数组

如果 `NOTE_BODY` 为空，使用 get text fallback：

```bash
agent-browser get text body
```

将可见文字中与笔记内容相关的部分记为 `NOTE_BODY`。

### Step 5：生成目录结构

1. 生成 slug：将 `NOTE_TITLE` 转为小写 + 连字符，去除特殊字符，截取前 50 字符
2. 生成目录名：`<YYYY-MM-DD>-<slug>`（日期用系统日期，格式 `date +%Y-%m-%d`）
3. 设置路径变量：
   - `TRIAGE_DIR` = `/Users/I333878/Library/Mobile Documents/com~apple~CloudDocs/TKB/TKB/triage/xiaohongshu/<目录名>`
   - `IMAGES_DIR` = `<TRIAGE_DIR>/images`

创建目录：

```bash
mkdir -p "<IMAGES_DIR>"
```

### Step 6：下载图片

将 `SCREENSHOT_PATH` 复制到 `images/screenshot.png`：

```bash
cp "<SCREENSHOT_PATH>" "<IMAGES_DIR>/screenshot.png"
```

对 `IMAGE_URLS` 中每个 URL（按顺序编号 `img-01.jpg`、`img-02.jpg`...）：

```bash
curl -sL \
  -H "Referer: https://www.xiaohongshu.com" \
  -H "User-Agent: Mozilla/5.0" \
  -o "<IMAGES_DIR>/img-NN.jpg" \
  "<图片URL>"
```

如果 curl 返回非 0 或文件大小为 0，跳过该图片，记录警告（截屏已作为备份）。

### Step 7：写入 triage

用 Write 工具创建 `<TRIAGE_DIR>/index.md`，内容格式如下：

```markdown
---
title: "<NOTE_TITLE>"
source_url: "<URL>"
author: "<NOTE_AUTHOR>"
date: <YYYY-MM-DD>
type: xiaohongshu
---

# <NOTE_TITLE>

**作者：** <NOTE_AUTHOR>
**来源：** <URL>

## 正文

<NOTE_BODY>

## 图片

<仅列出 Step 6 中成功下载的图片（curl 未报错且文件非空），每张一行，格式：![图N](./images/img-NN.jpg)>
![截屏](./images/screenshot.png)
```

### Step 8：返回控制权

完成后，将以下变量传递给 tkb-ingest 继续执行：
- `TRIAGE_DIR`：triage 目录完整路径
- `ENTRY_SLUG`：目录名（用于后续路径构建）
- 来源类型标记：`xiaohongshu`（供第五步移动逻辑识别）

继续执行 tkb-ingest 的：
- **第四步：去重检查**（匹配 `source_url`）
- **第五步：移动到 raw/web/**
- **第六步：全量编译（含图文联读）**

## 错误处理

| 场景 | 处理方式 |
|------|----------|
| session 未登录 / 内容为空 | 提示用户执行首次登录流程后重试，中止 |
| 笔记不存在或已删除 | 报错提示，不继续 |
| 图片下载失败 | 跳过，记录警告，截屏作为备份 |
| 截屏文件不存在 | 报错，流程中止 |
| 正文提取为空 | 提示用户，等待用户手动输入正文后继续 |
