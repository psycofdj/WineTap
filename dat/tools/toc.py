#!/usr/bin/env python3
"""Table des matières de chaque page du DAT, entre les marqueurs <!-- toc --> et <!-- /toc -->.

Placée après le titre de niveau 1 (en tête de page pour 00-presentation.md, qui n'en a pas).
Reprend les sections ## et ### ; ancres au format GitHub. À relancer après toute modification
des titres :

    python3 tools/toc.py            # depuis la racine du dépôt dat
"""
import glob
import re

START, END = "<!-- toc -->", "<!-- /toc -->"


def anchor(title):
    t = title.replace("`", "").strip().lower()
    t = re.sub(r"[^\w\- ]", "", t)
    return t.replace(" ", "-")


def headings(lines):
    out, seen, fence = [], {}, False
    for line in lines:
        if line.startswith("```"):
            fence = not fence
            continue
        m = None if fence else re.match(r"^(#{1,6})\s+(.*?)\s*$", line)
        if not m:
            continue
        a = anchor(m.group(2))
        if a in seen:
            seen[a] += 1
            a = f"{a}-{seen[a]}"
        else:
            seen[a] = 0
        out.append((len(m.group(1)), m.group(2), a))
    return out


def toc(text):
    body = re.sub(rf"{re.escape(START)}.*?{re.escape(END)}\n*", "", text, flags=re.S)
    lines = body.split("\n")
    items = [(lvl, t, a) for lvl, t, a in headings(lines) if lvl in (2, 3)]
    if not items:
        return body
    block = [START, "", "**Sur cette page**", ""]
    for lvl, title, a in items:
        block.append(f"{'  ' * (lvl - 2)}- [{title}](#{a})")
    block += ["", END, ""]
    h1 = next((i for i, l in enumerate(lines) if re.match(r"^# ", l)), None)
    at = 0 if h1 is None else h1 + 1
    if h1 is not None:
        block = [""] + block
    return "\n".join(lines[:at] + block + lines[at:]).replace("\n\n\n", "\n\n")


for path in sorted(glob.glob("[0-9][0-9]-*.md")):
    text = open(path).read()
    new = toc(text)
    if new != text:
        open(path, "w").write(new)
        print("toc :", path)
