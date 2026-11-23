#!/usr/bin/env python3
"""Derive the readable rungs of every quote in quote.md.

quote.md stays the only source: his words, verbatim, append only. This writes
quote.levels.md beside it, where each entry is shown raw and then at three
mechanical levels. Nothing here decides meaning; every change is a declared
rule, and the count of each rule's work is printed above the rung.

Levels:
  L0  raw. What he said, including the ums and the transcription errors.
  L1  names fixed. Only the words in GLOSSARY, which are mistranscriptions of
      a name, never style.
  L2  L1 plus immediate repeats and stutters ("we can we can" -> "we can").
  L3  L2 plus spoken filler (um, uh, erm, "you know", "I mean", comma-like).
      "like" is only removed where it stands alone between commas, because
      elsewhere it carries meaning.

An article that quotes him may use L1. L2 and L3 are for reading the thread of
it. Anything beyond L3 is editorial and has to be written by hand, signed, and
never presented as a quote.
"""
from __future__ import annotations

import re
import sys
from dataclasses import dataclass
from pathlib import Path

GLOSSARY = {
    "aleo": "Elio",
    "alio": "Elio",
}

FILLERS = re.compile(r"\b(?:um+|umm+|uh+|uhh+|erm+|er)\b[,\s]*", re.IGNORECASE)
PHRASES = re.compile(r"[,\s]*\b(?:you know|i mean)\b[,\s]*", re.IGNORECASE)
COMMA_LIKE = re.compile(r",\s*like\s*,", re.IGNORECASE)
DOUBLE_COMMA = re.compile(r",\s*,")
REPEAT = re.compile(r"\b(\w+)((?:\s+\1\b)+)", re.IGNORECASE)


def tidy_spacing(text: str) -> str:
    text = DOUBLE_COMMA.sub(",", text)
    text = re.sub(r"[ \t]{2,}", " ", text)
    text = re.sub(r"\s+([,.;:!?])", r"\1", text)
    text = re.sub(r"([,.;:!?])(?=[A-Za-z])", r"\1 ", text)
    text = re.sub(r"\(\s+", "(", text)
    text = re.sub(r"\s+\)", ")", text)
    return text.strip()


def level_one(text: str) -> tuple[str, int]:
    changes = 0

    def swap(match: re.Match[str]) -> str:
        nonlocal changes
        word = match.group(0)
        replacement = GLOSSARY.get(word.lower())
        if replacement is None:
            return word
        changes += 1
        # Keep a capital if the original had one, otherwise the glossary's.
        if word[0].isupper():
            return replacement
        return replacement[0].lower() + replacement[1:]

    pattern = re.compile(r"\b(" + "|".join(GLOSSARY) + r")\b", re.IGNORECASE)
    return tidy_spacing(pattern.sub(swap, text)), changes


def level_two(text: str) -> tuple[str, int]:
    changes = 0

    def collapse(match: re.Match[str]) -> str:
        nonlocal changes
        changes += 1
        return match.group(1)

    return tidy_spacing(REPEAT.sub(collapse, text)), changes


def level_three(text: str) -> tuple[str, int]:
    changes = 0
    for pattern, replacement in ((FILLERS, " "), (PHRASES, " "),
                                 (COMMA_LIKE, " ")):
        text, count = pattern.subn(replacement, text)
        changes += count
    text = tidy_spacing(text)
    # A cut filler often opens the sentence that follows it.
    text = re.sub(r"([.!?]\s+)([a-z])",
                  lambda m: m.group(1) + m.group(2).upper(), text)
    if text[:1].islower():
        text = text[:1].upper() + text[1:]
    return text, changes


@dataclass
class Entry:
    heading: str
    origin: str
    text: str


def parse(source: str) -> list[Entry]:
    entries: list[Entry] = []
    heading: str | None = None
    origin = ""
    lines: list[str] = []

    def flush() -> None:
        nonlocal heading, origin, lines
        if heading is None:
            return
        text = "\n".join(lines).strip()
        # The format example in the header is not an entry.
        if text and text != "his words, exactly":
            entries.append(Entry(heading, origin, text))
        heading, origin, lines = None, "", []

    for line in source.splitlines():
        if line.startswith("### "):
            flush()
            heading = line[4:].strip()
        elif heading is not None:
            stripped = line.strip()
            if stripped.startswith("origin:"):
                origin = stripped[len("origin:"):].strip()
            elif stripped.startswith(">"):
                text = stripped[1:]
                if text.startswith(" "):
                    text = text[1:]
                lines.append(text.rstrip())
    flush()
    return entries


def words(text: str) -> int:
    return len(re.findall(r"\S+", text))


def main() -> int:
    root = Path(__file__).resolve().parent.parent
    source_path = root / "quote.md"
    if not source_path.exists():
        print("no quote.md beside this script", file=sys.stderr)
        return 1

    entries = parse(source_path.read_text())
    if not entries:
        print("no entries found in quote.md", file=sys.stderr)
        return 1

    out: list[str] = [
        "# Quote, at four levels",
        "",
        "Generated from `quote.md` by `scripts/quote-levels.py`. Edit the source,",
        "never this file. L0 is the quote; L1 is the closest thing to it that reads",
        "as written English, and is the highest level an article should ever quote.",
        "",
        "---",
        "",
    ]

    for entry in entries:
        raw = entry.text
        one, one_n = level_one(raw)
        two, two_n = level_two(one)
        three, three_n = level_three(two)
        out += [
            f"## {entry.heading}",
            f"origin: {entry.origin}",
            "",
            f"**L0 raw** · {words(raw)} words",
            "",
            raw,
            "",
            f"**L1 names fixed** · {one_n} fix{'es' if one_n != 1 else ''}, {words(one)} words",
            "",
            one,
            "",
            f"**L2 repeats removed** · {two_n} collapse{'s' if two_n != 1 else ''}, {words(two)} words",
            "",
            two,
            "",
            f"**L3 filler removed** · {three_n} filler{'s' if three_n != 1 else ''} cut, {words(three)} words",
            "",
            three,
            "",
            "---",
            "",
        ]

    target = root / "quote.levels.md"
    target.write_text("\n".join(out).rstrip() + "\n")
    print(f"wrote {target.relative_to(root)} · {len(entries)} entries")
    for entry in entries:
        raw = entry.text
        one, one_n = level_one(raw)
        two, two_n = level_two(one)
        three, three_n = level_three(two)
        print(f"  {entry.heading[:40]:42} "
              f"{words(raw):4} → {words(three):4} words "
              f"({one_n} names, {two_n} repeats, {three_n} fillers)")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
