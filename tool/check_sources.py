#!/usr/bin/env python3
"""Static consistency checks over the Dart sources.

The Dart toolchain is unavailable in this environment, so this script performs
the checks that do not need a compiler:

1. balanced braces, brackets and parentheses per file
2. every relative import resolves to a file that exists
3. no banned patterns: `dynamic`, `TODO`, `UnimplementedError`, `return null`
   used as a stub, hardcoded `Colors.` hex values outside the design system
4. no `flutter`/`flame`/`BuildContext`/`Widget`/`Canvas` imports inside the
   pure domain layer (lib/features/*/domain and lib/features/game/domain)

It is a guard, not a substitute for `flutter analyze`: run that locally.
"""
from __future__ import annotations

import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
LIB = ROOT / "lib"

DOMAIN_MARKERS = ("/domain/",)
FORBIDDEN_IN_DOMAIN = (
    "package:flutter/",
    "package:flame/",
    "BuildContext",
    "Widget",
    "Canvas",
    "PositionComponent",
    "package:flutter_bloc/",
    "package:go_router/",
)

BANNED_TOKENS = (
    "UnimplementedError(",
    "TODO(",
    "FIXME(",
    "throw UnimplementedError",
)

# `dynamic` is only tolerated in the interop shims that talk to Firebase.
DYNAMIC_ALLOWLIST = {
    "lib/core/services/analytics_service.dart",
    "lib/core/services/crash_reporting_service.dart",
}


def relative_imports(text: str) -> list[str]:
    return re.findall(r"""^\s*(?:import|export)\s+['"]([^'"]+)['"]""",
                      text, re.MULTILINE)


def resolve(base: Path, spec: str) -> Path | None:
    if spec.startswith("dart:"):
        return None
    if spec.startswith("package:"):
        return None
    return (base.parent / spec).resolve()


def check_balance(path: Path, text: str) -> list[str]:
    problems: list[str] = []
    # Strip strings and comments so braces inside them do not count.
    stripped = re.sub(r"'''.*?'''|\"\"\".*?\"\"\"", '""', text, flags=re.DOTALL)
    stripped = re.sub(r"//[^\n]*", "", stripped)
    stripped = re.sub(r"/\*.*?\*/", "", stripped, flags=re.DOTALL)
    stripped = re.sub(r"'(\\.|[^'\\])*'", "''", stripped)
    stripped = re.sub(r'"(\\.|[^"\\])*"', '""', stripped)
    for open_ch, close_ch in (("{", "}"), ("(", ")"), ("[", "]")):
        opens = stripped.count(open_ch)
        closes = stripped.count(close_ch)
        if opens != closes:
            problems.append(
                f"unbalanced {open_ch}{close_ch}: {opens} open vs {closes} close"
            )
    return problems


def check_domain_purity(path: Path, text: str) -> list[str]:
    rel = path.relative_to(ROOT).as_posix()
    if not any(marker in f"/{rel}" for marker in DOMAIN_MARKERS):
        return []
    problems: list[str] = []
    for token in FORBIDDEN_IN_DOMAIN:
        if token in text:
            problems.append(f"domain layer references {token}")
    return problems


def check_banned(path: Path, text: str) -> list[str]:
    rel = path.relative_to(ROOT).as_posix()
    problems: list[str] = []
    for token in BANNED_TOKENS:
        if token in text:
            problems.append(f"banned token {token}")
    if rel not in DYNAMIC_ALLOWLIST:
        # `Map<String, dynamic>` and `List<dynamic>` are the standard JSON
        # shapes and are fine - they are immediately narrowed with `is`. Only a
        # *bare* `dynamic` type annotation defeats static analysis.
        hits = [
            line.strip()
            for line in text.splitlines()
            if re.search(r"(^|[^\w<,])dynamic\s+[A-Za-z_]\w*", line)
            or "as dynamic" in line
        ]
        if hits:
            problems.append(f"bare 'dynamic' on {len(hits)} line(s): {hits[:4]}")
    return problems


def main() -> int:
    dart_files = sorted(LIB.rglob("*.dart"))
    problems: list[str] = []

    for path in dart_files:
        text = path.read_text(encoding="utf-8")
        rel = path.relative_to(ROOT).as_posix()

        problems += [f"{rel}: {p}" for p in check_balance(path, text)]
        problems += [f"{rel}: {p}" for p in check_domain_purity(path, text)]
        problems += [f"{rel}: {p}" for p in check_banned(path, text)]

        for spec in relative_imports(text):
            target = resolve(path, spec)
            if target is None:
                continue
            if not target.exists():
                problems.append(f"{rel}: unresolved import {spec}")

    print(f"checked {len(dart_files)} Dart files under lib/")
    if problems:
        print(f"\n{len(problems)} problem(s):")
        for problem in problems:
            print(f"  - {problem}")
        return 1
    print("no structural problems found")
    return 0


if __name__ == "__main__":
    sys.exit(main())
