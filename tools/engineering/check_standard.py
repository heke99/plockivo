#!/usr/bin/env python3
"""Read-only structural checks for Engineering Startkit 3.0.0 (Python 3.10+).

This checks files, Python syntax and local Markdown references. It does not run
the project, access a network or certify product functionality or security.
"""
from __future__ import annotations

import argparse
import ast
import html
import json
import os
import re
import sys
from pathlib import Path
from urllib.parse import unquote, urlsplit

STATIC_FILES = (
    "README_START.md", "START_PROMPT.txt", "VERSION",
    "docs/ENGINEERING_STANDARD.md", "docs/SKILLS_CATALOG.md",
    "docs/PROJECT_PROFILES.md", "docs/START_HERE.md",
    "docs/CI_INTEGRATION.md", "docs/CHANGELOG.md",
    "docs/PROJECT_CONTEXT.template.md", "docs/PROJECT_STATE.template.md",
    "docs/DECISIONS.template.md", "docs/WORK_ITEM.template.md",
    "docs/PRODUCT_REQUIREMENTS.template.md",
    "tools/engineering/bootstrap.py", "tools/engineering/check_standard.py",
)
RUNTIME_FILES = {
    "docs/PROJECT_CONTEXT.md", "docs/PROJECT_STATE.md", "docs/DECISIONS.md",
    "docs/PRODUCT_REQUIREMENTS.md",
}


def stripped_markdown(text: str) -> str:
    """Remove fenced examples/comments while retaining source line numbers."""
    text = re.sub(r"<!--.*?-->", lambda m: "\n" * m.group().count("\n"), text,
                  flags=re.S)
    output: list[str] = []
    fence_char = ""
    fence_length = 0
    for line in text.splitlines(keepends=True):
        match = re.match(r"^ {0,3}(`{3,}|~{3,})", line)
        if not fence_char:
            if match:
                fence_char, fence_length = match[1][0], len(match[1])
                output.append("\n" if line.endswith("\n") else "")
            else:
                output.append(line)
        else:
            if match and match[1][0] == fence_char and len(match[1]) >= fence_length:
                fence_char = ""
            output.append("\n" if line.endswith("\n") else "")
    return "".join(output)


def anchors(text: str) -> set[str]:
    result: set[str] = set()
    counts: dict[str, int] = {}
    text = stripped_markdown(text)
    for line in text.splitlines():
        match = re.match(r"^ {0,3}#{1,6}\s+(.+?)\s*#*\s*$", line)
        if match:
            title = html.unescape(match[1])
            title = re.sub(r"!?\[([^\]]+)\]\([^)]*\)", r"\1", title)
            title = re.sub(r"<[^>]*>", "", title).lower()
            slug = "".join(c for c in title if c.isalnum() or c in "_ -")
            slug = re.sub(r"\s", "-", slug)
            number = counts.get(slug, 0)
            counts[slug] = number + 1
            result.add(slug if number == 0 else f"{slug}-{number}")
    for match in re.finditer(r"\b(?:id|name)\s*=\s*['\"]([^'\"]+)['\"]", text):
        result.add(match[1])
    return result


def local_links(text: str):
    clean = stripped_markdown(text)
    # The kit uses ordinary inline links and reference definitions, not a full
    # Markdown parser. Balanced parentheses in destinations are supported.
    pattern = re.compile(r"!?\[[^\]\n]*\]\(\s*(<[^>\n]+>|(?:[^\s()\\]|\\.|\([^()]*\))+)(?:\s+['\"][^\n]*?['\"])?\s*\)")
    for match in pattern.finditer(clean):
        destination = match[1].strip("<>")
        yield destination, clean.count("\n", 0, match.start()) + 1
    for match in re.finditer(r"^ {0,3}\[[^\]\n]+\]:\s*(<[^>\n]+>|\S+)", clean, re.M):
        yield match[1].strip("<>"), clean.count("\n", 0, match.start()) + 1


def symlink_component(path: Path, root: Path) -> bool:
    try:
        parts = path.relative_to(root).parts
    except ValueError:
        return True
    current = root
    if current.is_symlink():
        return True
    for part in parts:
        current /= part
        if current.is_symlink():
            return True
    return False


def check(project: Path, mode: str) -> dict:
    findings: list[dict] = []

    def add(level: str, file: str, message: str, line: int | None = None):
        item = {"level": level, "file": file, "message": message}
        if line is not None:
            item["line"] = line
        findings.append(item)

    if not project.is_dir():
        add("error", str(project), "Projektkatalogen finns inte eller är ingen katalog.")
        return {"mode": mode, "project": str(project), "checked_files": 0,
                "findings": findings, "ok": False}

    agent = "AGENTS.md"
    if mode == "project" and (project / "AGENTS.engineering.md").is_file():
        agent = "AGENTS.engineering.md"
        add("warning", agent, "Kompletterande instruktioner finns. Kontrollera att projektets aktiva agentinstruktioner hänvisar till dem; automatisk aktivering har inte verifierats.")
    expected = (agent,) + STATIC_FILES
    texts: dict[Path, str] = {}
    checked = 0
    for relative in expected:
        path = project / relative
        if symlink_component(path, project):
            add("error", relative, "Symbolisk länk i paketets sökväg; välj vanliga filer/kataloger.")
            continue
        if not path.is_file():
            add("error", relative, "Obligatorisk standardfil saknas.")
            continue
        checked += 1
        try:
            content = path.read_text(encoding="utf-8")
        except (OSError, UnicodeError) as exc:
            add("error", relative, f"Kan inte läsa UTF-8-fil: {exc}")
            continue
        if not content.strip():
            add("error", relative, "Standardfilen är tom.")
        if path.suffix.lower() == ".md":
            texts[path] = content
        elif path.suffix == ".py":
            try:
                ast.parse(content, filename=relative)
            except SyntaxError as exc:
                add("error", relative, f"Python-syntaxfel: {exc.msg}", exc.lineno)

    cache = {path: anchors(content) for path, content in texts.items()}
    for path, content in texts.items():
        relative = path.relative_to(project).as_posix()
        for destination, line in local_links(content):
            destination = html.unescape(destination)
            if re.search(r"\{\{|\}\}|<(?:id|path|sökväg|namn)>", destination, re.I):
                continue  # Explicit template placeholders are not broken links.
            try:
                parsed = urlsplit(destination)
            except ValueError as exc:
                add("error", relative, f"Ogiltig länkdestination: {destination}: {exc}", line)
                continue
            if parsed.scheme or parsed.netloc:
                continue  # No network requests; external links are not validated.
            raw_path = unquote(parsed.path)
            if not raw_path and not parsed.fragment:
                add("warning", relative, "Tom länkdestination.", line)
                continue
            target = Path(os.path.abspath(path.parent / raw_path)) if raw_path else path
            try:
                target_relative = target.relative_to(project).as_posix()
            except ValueError:
                add("error", relative, f"Lokal länk lämnar projektkatalogen: {destination}", line)
                continue
            if symlink_component(target, project):
                add("error", relative, f"Länkmålet använder symbolisk länk: {destination}", line)
                continue
            if not target.exists():
                runtime = target_relative in RUNTIME_FILES or target_relative.startswith("docs/work/")
                add("warning" if runtime else "error", relative,
                    f"{'Projektets arbetsdokument saknas ännu' if runtime else 'Lokalt länkmål saknas'}: {destination}", line)
                continue
            if parsed.fragment and target.suffix.lower() == ".md" and target.is_file():
                if target not in cache:
                    try:
                        cache[target] = anchors(target.read_text(encoding="utf-8"))
                    except (OSError, UnicodeError) as exc:
                        add("error", relative, f"Kan inte läsa länkmålet {destination}: {exc}", line)
                        continue
                if unquote(parsed.fragment) not in cache[target]:
                    add("error", relative, f"Markdown-ankare saknas: {destination}", line)

    if mode == "project":
        for relative in ("docs/PROJECT_CONTEXT.md", "docs/PROJECT_STATE.md"):
            if not (project / relative).is_file():
                add("warning", relative, "Saknas på standardsökvägen. Återanvänd dokumenterad motsvarighet eller skapa från mallen när uppdraget kräver det.")
    errors = sum(item["level"] == "error" for item in findings)
    warnings = sum(item["level"] == "warning" for item in findings)
    return {"mode": mode, "project": str(project), "checked_files": checked,
            "errors": errors, "warnings": warnings, "findings": findings,
            "ok": errors == 0,
            "scope": "Struktur, lokal Markdownlänkning och Python-syntax. Externa länkar, agentaktivering, applikationens funktion och säkerhet är inte verifierade."}


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, default=Path.cwd(), help="Katalog att kontrollera (standard: aktuell katalog).")
    parser.add_argument("--mode", choices=("package", "project"), default="project", help="package: distributionspaket; project: importerad standard och orienterande projektvarningar.")
    parser.add_argument("--json", action="store_true", help="Skriv maskinläsbart resultat.")
    args = parser.parse_args()
    project = Path(os.path.abspath(args.project.expanduser()))
    result = check(project, args.mode)
    if args.json:
        print(json.dumps(result, ensure_ascii=False, indent=2))
    else:
        for item in result["findings"]:
            location = item["file"] + (f":{item['line']}" if "line" in item else "")
            print(f"{item['level'].upper()}: {location}: {item['message']}")
        print(f"Kontrollerade filer: {result['checked_files']}. Fel: {result.get('errors', 1)}. Varningar: {result.get('warnings', 0)}.")
        print(result.get("scope", "Kontrollen kunde inte genomföras."))
    return 0 if result["ok"] else 1


if __name__ == "__main__":
    sys.exit(main())
