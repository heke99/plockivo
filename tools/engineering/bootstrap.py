#!/usr/bin/env python3
"""Import Engineering Startkit files without overwriting project files.

Python 3.10+. Dry-run is the default; --apply copies only a fixed whitelist.
No dependencies are installed, project commands run or agent settings changed.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
import stat
import sys
from pathlib import Path

FILES = (
    "AGENTS.md", "README_START.md", "START_PROMPT.txt", "VERSION",
    "docs/ENGINEERING_STANDARD.md", "docs/SKILLS_CATALOG.md",
    "docs/PROJECT_PROFILES.md", "docs/START_HERE.md",
    "docs/CI_INTEGRATION.md", "docs/CHANGELOG.md",
    "docs/PROJECT_CONTEXT.template.md", "docs/PROJECT_STATE.template.md",
    "docs/DECISIONS.template.md", "docs/WORK_ITEM.template.md",
    "docs/PRODUCT_REQUIREMENTS.template.md",
    "tools/engineering/bootstrap.py", "tools/engineering/check_standard.py",
)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def no_symlinks(path: Path) -> None:
    """Reject an existing symlink anywhere along the requested path."""
    for item in reversed((path,) + tuple(path.parents)):
        if item.is_symlink():
            raise ValueError(f"Symbolisk länk tillåts inte i mål-/källsökväg: {item}")
        if item.exists() and item != path and not item.is_dir():
            raise ValueError(f"En överordnad sökväg är inte en katalog: {item}")


def read_regular(path: Path) -> bytes:
    no_symlinks(path)
    flags = os.O_RDONLY | getattr(os, "O_NOFOLLOW", 0)
    descriptor = os.open(path, flags)
    with os.fdopen(descriptor, "rb") as stream:
        if not stat.S_ISREG(os.fstat(stream.fileno()).st_mode):
            raise ValueError(f"Inte en vanlig fil: {path}")
        return stream.read()


def plan(source: Path, project: Path) -> dict:
    no_symlinks(project)
    if project.exists() and not project.is_dir():
        raise ValueError(f"Målet är inte en katalog: {project}")
    entries: list[dict] = []
    conflicts: list[str] = []
    manual_merge = False
    for relative in FILES:
        source_path = source / relative
        if not source_path.is_file():
            conflicts.append(f"Källpaketet saknar obligatorisk fil: {relative}")
            continue
        data = read_regular(source_path)
        target_relative = relative
        destination = project / target_relative
        no_symlinks(destination)
        if relative == "AGENTS.md" and destination.exists():
            if destination.is_file() and read_regular(destination) != data:
                target_relative = "AGENTS.engineering.md"
                destination = project / target_relative
                no_symlinks(destination)
                manual_merge = True
        if destination.exists():
            if not destination.is_file():
                conflicts.append(f"Målet är ingen vanlig fil: {target_relative}")
                continue
            if read_regular(destination) == data:
                action = "unchanged"
            else:
                conflicts.append(f"Befintlig fil skiljer sig och bevaras: {target_relative}")
                continue
        else:
            action = "create"
        entries.append({"source": relative, "target": target_relative,
                        "action": action, "sha256": digest(data), "size_bytes": len(data)})
    return {"source": str(source), "project": str(project), "entries": entries,
            "conflicts": conflicts, "manual_agent_merge_required": manual_merge}


def apply_plan(result: dict) -> None:
    """Check the complete plan again, then create each file exclusively.

    Pre-existing conflicts cause zero writes. A concurrent filesystem change
    can interrupt a copy; files already created are reported and remain usable.
    No existing destination file is ever opened for writing.
    """
    source, project = Path(result["source"]), Path(result["project"])
    second = plan(source, project)
    if second != result:
        raise ValueError("Filsystemet ändrades efter förkontrollen. Kör om för att granska en ny plan.")
    created: list[str] = []
    try:
        for entry in result["entries"]:
            if entry["action"] != "create":
                continue
            destination = project / entry["target"]
            no_symlinks(destination)
            destination.parent.mkdir(parents=True, exist_ok=True)
            no_symlinks(destination)
            data = read_regular(source / entry["source"])
            if digest(data) != entry["sha256"]:
                raise ValueError(f"Källfilen ändrades under kopieringen: {entry['source']}")
            flags = os.O_WRONLY | os.O_CREAT | os.O_EXCL | getattr(os, "O_NOFOLLOW", 0)
            descriptor = os.open(destination, flags, 0o644)
            try:
                with os.fdopen(descriptor, "wb") as stream:
                    stream.write(data)
                    stream.flush()
                    os.fsync(stream.fileno())
            except BaseException:
                # This path was created with O_EXCL by this invocation. Leave
                # it visible in the error report rather than guessing at the
                # state of a concurrently edited file during cleanup.
                created.append(entry["target"])
                raise
            created.append(entry["target"])
    except (OSError, ValueError) as exc:
        raise ValueError(f"Importen avbröts: {exc}. Redan skapade filer: {', '.join(created) or 'inga'}. Befintliga filer skrevs inte över.") from exc


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--project", type=Path, required=True, help="Målprojekt. Befintliga filer bevaras.")
    group = parser.add_mutually_exclusive_group()
    group.add_argument("--apply", action="store_true", help="Kopiera efter godkänd lokal förkontroll.")
    group.add_argument("--dry-run", action="store_true", help="Visa planen utan att skriva (standard).")
    parser.add_argument("--json", action="store_true", help="Skriv maskinläsbar plan och resultat.")
    args = parser.parse_args()
    source = Path(__file__).resolve().parents[2]
    project = Path(os.path.abspath(args.project.expanduser()))
    try:
        result = plan(source, project)
        result["applied"] = False
        if result["conflicts"]:
            result["ok"] = False
        elif args.apply:
            # Keep execution-only status fields out of the stable preflight.
            execution_plan = {key: value for key, value in result.items() if key != "applied"}
            apply_plan(execution_plan)
            result["applied"] = True
            result["ok"] = True
        else:
            result["ok"] = True
        if args.json:
            print(json.dumps(result, ensure_ascii=False, indent=2))
        else:
            print("APPLY" if result["applied"] else "DRY-RUN: inga filer skrivs.")
            for entry in result["entries"]:
                print(f"{entry['action'].upper()}: {entry['target']}")
            for conflict in result["conflicts"]:
                print(f"CONFLICT: {conflict}")
            if result["conflicts"]:
                print("Ingen import utförd. Samordna skillnaderna manuellt och kör en ny förkontroll.")
            elif not args.apply:
                print("Använd --apply för att kopiera den granskade filuppsättningen.")
            if result["manual_agent_merge_required"]:
                print("Befintlig AGENTS.md bevaras. AGENTS.engineering.md är ett mergeunderlag; aktivering kräver att projektets aktiva instruktioner hänvisar till innehållet. Detta har inte skett automatiskt.")
            print("Inga beroenden, projektskript, globala inställningar eller driftsmiljöer ändras. Kör utan samtidiga ändringar i målkatalogerna.")
        return 0 if result["ok"] else 1
    except (OSError, ValueError) as exc:
        if args.json:
            print(json.dumps({"ok": False, "error": str(exc)}, ensure_ascii=False, indent=2))
        else:
            print(f"ERROR: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
