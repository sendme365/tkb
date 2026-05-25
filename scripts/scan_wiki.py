#!/usr/bin/env python3
# scan_wiki.py — run all mechanical lint checks on TKB wiki, output text summary
# Usage: python3 scan_wiki.py
# Output: plain-text sections to stdout; Claude reads this for semantic analysis

import re
import glob
import os

TKB = os.environ.get(
    "TKB_ROOT",
    "$HOME/Library/Mobile Documents/com~apple~CloudDocs/TKB/TKB",
)


def parse_file(path, base):
    content = open(path, encoding="utf-8").read()
    fm_m = re.search(r"^---\n(.*?)\n---", content, re.DOTALL)
    rel = os.path.relpath(path, base)
    e = {
        "file": rel,
        "abs": path,
        "title": None,
        "source_tag": None,
        "folder": None,
        "tags": [],
        "wikilinks": [],
    }
    if fm_m:
        fm = fm_m.group(1)
        for field in ["title", "source_tag", "folder"]:
            m = re.search(rf"^{field}:\s*\"?([^\"\n]+)\"?", fm, re.MULTILINE)
            if m:
                e[field] = m.group(1).strip().strip('"')
        tags_m = re.search(r"^tags:\s*\[([^\]]*)\]", fm, re.MULTILINE)
        if tags_m:
            e["tags"] = [t.strip() for t in tags_m.group(1).split(",") if t.strip()]
        else:
            e["tags"] = re.findall(r"^\s+-\s+(.+)", fm, re.MULTILINE)
    all_links = re.findall(r"\[\[([^\]|]+)", content)
    e["wikilinks"] = list(set(l for l in all_links if not l.startswith("raw/")))
    return e


# ── Scan all files ────────────────────────────────────────────────────────────
concepts, analyses = [], []
for kind, store in [("concepts", concepts), ("analysis", analyses)]:
    base = f"{TKB}/wiki/{kind}"
    for f in sorted(glob.glob(f"{base}/**/*.md", recursive=True)):
        store.append(parse_file(f, base))

all_files = concepts + analyses
concept_stems = {os.path.splitext(os.path.basename(e["abs"]))[0] for e in concepts}

# ── Index ─────────────────────────────────────────────────────────────────────
index_path = f"{TKB}/wiki/_index.md"
index_content = open(index_path, encoding="utf-8").read()
index_entry_count = index_content.count("### ")

# ── Check 1: Orphaned concepts ───────────────────────────────────────────────
all_refs = set()
for e in all_files:
    for link in e["wikilinks"]:
        all_refs.add(os.path.splitext(os.path.basename(link))[0])
for link in re.findall(r"\[\[([^\]|]+)", index_content):
    all_refs.add(os.path.splitext(os.path.basename(link))[0])

orphaned = [
    e["file"]
    for e in concepts
    if os.path.splitext(os.path.basename(e["abs"]))[0] not in all_refs
]

# ── Check 2: Tag hierarchy conflicts ─────────────────────────────────────────
all_tags = set(t for e in concepts for t in e["tags"])
flat_with_children = {}
for tag in sorted(all_tags):
    if "/" not in tag:
        children = sorted(t for t in all_tags if t.startswith(tag + "/"))
        if children:
            n_files = sum(1 for e in concepts if tag in e["tags"])
            flat_with_children[tag] = {"files": n_files, "variants": children}

# ── Check 3: source_tag completeness ─────────────────────────────────────────
valid_source_tags = {"#work", "#ttt"}
bad_source = [
    e["file"]
    for e in all_files
    if not e["source_tag"] or e["source_tag"] not in valid_source_tags
]

# ── Check 4: Concept overlap candidates (≥3 shared tags) ─────────────────────
overlaps = []
for i in range(len(concepts)):
    for j in range(i + 1, len(concepts)):
        common = set(concepts[i]["tags"]) & set(concepts[j]["tags"])
        if len(common) >= 3:
            a = os.path.splitext(concepts[i]["file"])[0]
            b = os.path.splitext(concepts[j]["file"])[0]
            overlaps.append(
                f"{a} & {b}: common=[{','.join(sorted(common))}]({len(common)})"
            )

# ── Check 5: Broken concept links in _index.md ───────────────────────────────
# Only check bare wikilinks that look like concept file names (no path prefix,
# no tag-style names like AI/Agent which are actually inline tags not files)
broken = []
for link in re.findall(r"\[\[([^\]|]+)\]\]", index_content):
    if link.startswith("raw/") or link.startswith("wiki/"):
        continue
    # Skip tag-style references (contain / but are not file paths)
    # A concept file reference is either a bare slug (no /) or a path (wiki/...)
    # Tags like "AI/Agent" should not be treated as concept file references
    if "/" in link:
        continue
    stem = os.path.splitext(os.path.basename(link))[0]
    if stem not in concept_stems:
        broken.append(f"{link}: missing")

# ── Check 6: Folder field sync ───────────────────────────────────────────────
folder_issues = []
for e in all_files:
    parts = e["file"].split(os.sep)
    expected = "/".join(parts[:-1]) if len(parts) > 1 else ""
    actual = e["folder"] or ""
    if expected != actual:
        folder_issues.append(
            f"{e['file']}: expected={expected or '(none)'} actual={actual or '(未设置)'}"
        )

# ── Output ────────────────────────────────────────────────────────────────────
sections = []

sections.append("[STATS]")
sections.append(
    f"concepts={len(concepts)} analyses={len(analyses)} index_entries={index_entry_count}"
)
sections.append("")

sections.append("[CHECK1_ORPHANED]")
sections += orphaned if orphaned else ["NONE"]
sections.append("")

sections.append("[CHECK2_TAG_HIERARCHY]")
if flat_with_children:
    for tag, info in flat_with_children.items():
        sections.append(
            f"{tag}({info['files']} files) vs {','.join(info['variants'])}"
        )
else:
    sections.append("NONE")
sections.append("")

sections.append("[CHECK3_SOURCE_TAG]")
sections += bad_source if bad_source else ["NONE"]
sections.append("")

sections.append("[CHECK4_OVERLAP_CANDIDATES]")
sections += overlaps if overlaps else ["NONE"]
sections.append("")

sections.append("[CHECK5_BROKEN_LINKS]")
sections += broken if broken else ["NONE"]
sections.append("")

sections.append("[CHECK6_FOLDER_SYNC]")
sections += folder_issues if folder_issues else ["NONE"]

print("\n".join(sections))
