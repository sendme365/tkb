# 视频采集流程（YouTube / Bilibili）

仅在来源类型为 YouTube 或 Bilibili 时执行此文件中的步骤。完成后返回主流程继续第四步。

## 第二步（视频）：采集字幕内容

### 2v-a. 确定平台和路径变量

```bash
if echo "$URL" | grep -qE "(youtube\.com|youtu\.be)"; then PLATFORM="youtube"
else PLATFORM="bilibili"; fi

TKB_ROOT="/Users/I333878/Library/Mobile Documents/com~apple~CloudDocs/TKB/TKB"
TODAY=$(date +%Y-%m-%d)
```

### 2v-b. 调用 fetch_subtitle.sh

先建临时目录（视频标题未知，占位用），再调用脚本：

```bash
SCRIPT="$HOME/.claude/plugins/marketplaces/tkb/scripts/fetch_subtitle.sh"
TEMP_SLUG="$TODAY-fetching"
TEMP_DIR="$TKB_ROOT/raw/video/$PLATFORM/$TEMP_SLUG"
mkdir -p "$TEMP_DIR"

RESULT=$(bash "$SCRIPT" "$URL" "$TEMP_DIR")
EXIT_CODE=$?
```

退出码处理：
- `4`：向用户报告"该视频无可用字幕，无法入库"，终止流程，删除 `$TEMP_DIR`
- `5`：向用户报告 yt-dlp 错误，终止流程，删除 `$TEMP_DIR`
- 其他非 `0`：报告错误信息，终止流程，删除 `$TEMP_DIR`

### 2v-c. 解析返回值

用 `python3 -c` 解析 JSON（不依赖 jq）：

```bash
VIDEO_ID=$(echo "$RESULT"       | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['video_id'])")
VIDEO_TITLE=$(echo "$RESULT"    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['title'])")
CHANNEL=$(echo "$RESULT"        | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['channel'])")
DURATION=$(echo "$RESULT"       | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['duration'])")
UPLOAD_DATE=$(echo "$RESULT"    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['upload_date'])")
DESCRIPTION=$(echo "$RESULT"    | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['description'])")
SUB_LANG=$(echo "$RESULT"       | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['lang'])")
TRANSCRIPT_REL=$(echo "$RESULT" | python3 -c "import sys,json; d=json.load(sys.stdin); print(d['transcript_file'])")
```

### 2v-d. 生成正式目录名并重命名

```bash
TITLE_SLUG=$(echo "$VIDEO_TITLE" \
  | tr '[:upper:]' '[:lower:]' \
  | sed 's/[^a-z0-9]/-/g' \
  | sed 's/-\+/-/g' \
  | sed 's/^-//;s/-$//' \
  | cut -c1-50)

ENTRY_SLUG="$TODAY-$TITLE_SLUG"
FINAL_DIR="$TKB_ROOT/raw/video/$PLATFORM/$ENTRY_SLUG"
mv "$TEMP_DIR" "$FINAL_DIR"
```

### 2v-e. 读取转录内容

用 Read 工具读取 `$FINAL_DIR/$TRANSCRIPT_REL`，将内容存入 `TRANSCRIPT_CONTENT`，供第三步（视频）使用。

---

## 第三步（视频）：直接写入 raw

仅在来源类型为 YouTube 或 Bilibili 时执行。跳过 triage，直接写入 raw（字幕下载是确定性操作，无需人工审核）。

目录已由 2v-d 创建于 `$FINAL_DIR`（`raw/video/<platform>/<ENTRY_SLUG>/`）。

将 `UPLOAD_DATE`（格式 `YYYYMMDD`）转为 `YYYY-MM-DD`：
```bash
VIDEO_DATE="${UPLOAD_DATE:0:4}-${UPLOAD_DATE:4:2}-${UPLOAD_DATE:6:2}"
```

用 Write 工具写入 `$FINAL_DIR/index.md`：

```markdown
---
title: "<VIDEO_TITLE>"
source_url: "<URL>"
source_type: "<PLATFORM>"
channel: "<CHANNEL>"
video_id: "<VIDEO_ID>"
date: <VIDEO_DATE>
duration: "<DURATION>"
subtitles: ["<SUB_LANG>.srt"]
type: video
source_tag: "<SOURCE_TAG>"
---

# <VIDEO_TITLE>

**来源 (Source)：** [<PLATFORM 大写>](<URL>)
**频道 / 作者 (Channel)：** <CHANNEL>
**日期 (Date)：** <VIDEO_DATE>　**时长 (Duration)：** <DURATION>

## 视频描述 (Description)

<DESCRIPTION>

## 字幕文件 (Subtitle Files)

- [[subtitles/<SUB_LANG>.srt|<SUB_LANG> 字幕 (SRT)]]

## 转录内容 (Transcript)

<TRANSCRIPT_CONTENT>
```

---

**完成后**：返回主流程，继续执行 `references/wiki-compilation.md` 中的第四步。
