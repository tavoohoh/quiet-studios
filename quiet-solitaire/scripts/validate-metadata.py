#!/usr/bin/env python3
"""Checks fastlane/metadata against App Store Connect limits and our copy rules.

    scripts/validate-metadata.py

Counts characters the way App Store Connect does (Unicode characters, trailing newline ignored).
"""
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent / "fastlane" / "metadata"
LIMITS = {
    "name.txt": 30,
    "subtitle.txt": 30,
    "promotional_text.txt": 170,
    "description.txt": 4000,
    "keywords.txt": 100,
    "release_notes.txt": 4000,
    "privacy_url.txt": None,
    "support_url.txt": None,
}
# Other apps' names never appear in our copy.
BANNED = [r"microsoft", r"mobilityware", r"solitaire\s*collection", r"spider", r"freecell"]

problems = []
for locale in sorted(p for p in ROOT.iterdir() if p.is_dir()):
    print(f"\n{locale.name}")
    name_words = set()
    for file, limit in LIMITS.items():
        path = locale / file
        if not path.exists():
            problems.append(f"{locale.name}/{file}: missing")
            continue
        text = path.read_text().rstrip("\n")
        count = len(text)
        status = "ok" if limit is None or count <= limit else "TOO LONG"
        print(f"  {file:<22} {count:>5}" + (f" / {limit:<5}" if limit else "        ") + f" {status}")
        if status != "ok":
            problems.append(f"{locale.name}/{file}: {count} > {limit}")
        if not text.strip():
            problems.append(f"{locale.name}/{file}: empty")
        for pattern in BANNED:
            if re.search(pattern, text, re.IGNORECASE):
                problems.append(f"{locale.name}/{file}: mentions '{pattern}'")
        if file == "name.txt":
            name_words = {w.lower() for w in re.findall(r"\w+", text)}
        if file == "keywords.txt":
            keywords = [k.strip().lower() for k in text.split(",")]
            if any(k != k.strip() or not k for k in text.split(",")):
                problems.append(f"{locale.name}/keywords.txt: spaces around commas or empty keyword")
            if len(keywords) != len(set(keywords)):
                problems.append(f"{locale.name}/keywords.txt: repeated keyword")
            for word in {w for k in keywords for w in re.findall(r"\w+", k)} & name_words:
                problems.append(f"{locale.name}/keywords.txt: repeats '{word}' from the name")
        if file.endswith("_url.txt") and not text.startswith("https://"):
            problems.append(f"{locale.name}/{file}: not an https URL")
        if file.endswith("_url.txt") and ("USERNAME" in text or "REPO" in text):
            problems.append(f"{locale.name}/{file}: placeholder URL, set the real GitHub Pages address")

print()
if problems:
    print("Problems:")
    for problem in problems:
        print(f"  • {problem}")
    sys.exit(1)
print("All metadata within limits.")
