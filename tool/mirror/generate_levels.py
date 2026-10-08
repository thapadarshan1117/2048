#!/usr/bin/env python3
"""Generates, calibrates, validates and exports the MERGE DROP level catalogue.

This is the Python reference implementation of `tool/generate_levels.dart`.
It is run once to produce `assets/levels/chapter_XX.json`; the Dart tool
regenerates identical output so the catalogue can be rebuilt without Python.

Usage:
    python3 tool/mirror/generate_levels.py [--levels 500] [--out assets/levels]
"""
import argparse
import json
import os
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "tests"))

from mergedrop.game_simulator import GameSimulator          # noqa: E402
from mergedrop.level_generator import LEVELS_PER_CHAPTER, LevelGenerator  # noqa: E402
from mergedrop.level_validator import ERROR, LevelValidator  # noqa: E402

# Levels 1-3 are the tutorial: they are supposed to be trivial.
TUTORIAL_EXEMPT_IDS = frozenset({1, 2, 3})

CHAPTER_THEMES = [
    "theme_dawn", "theme_reef", "theme_amber", "theme_forest",
    "theme_violet", "theme_ember", "theme_glacier", "theme_orchid",
    "theme_cobalt", "theme_saffron", "theme_jade", "theme_coral",
    "theme_indigo", "theme_mint", "theme_rose", "theme_onyx",
    "theme_aurora", "theme_copper", "theme_teal", "theme_magenta",
]


def build_parser():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--levels", type=int, default=500)
    parser.add_argument("--out", default=os.path.join(
        os.path.dirname(HERE), "..", "assets", "levels"))
    parser.add_argument("--games", type=int, default=4)
    parser.add_argument("--validate-games", type=int, default=6)
    parser.add_argument("--skill", type=float, default=0.8)
    parser.add_argument("--no-validate", action="store_true")
    return parser


def main(argv=None):
    args = build_parser().parse_args(argv)
    out_dir = os.path.abspath(args.out)
    os.makedirs(out_dir, exist_ok=True)

    simulator = GameSimulator(skill=args.skill, max_moves=120)
    generator = LevelGenerator(total_levels=args.levels, simulator=simulator,
                               games=args.games, skill=args.skill,
                               max_moves=120)

    started = time.time()
    levels = []
    simulations = {}
    for level_id in range(1, args.levels + 1):
        level, report = generator.generate_with_report(level_id)
        levels.append(level)
        if report is not None:
            simulations[level_id] = report
        if level_id % 25 == 0 or level_id == 1:
            print("  calibrated %d/%d levels (%.0fs)"
                  % (level_id, args.levels, time.time() - started), flush=True)

    print("calibration finished in %.0fs" % (time.time() - started), flush=True)

    # --- validation --------------------------------------------------------
    reports = []
    if not args.no_validate:
        validator = LevelValidator(simulator=simulator, games=args.validate_games,
                                   skill=args.skill,
                                   trivial_exempt_ids=TUTORIAL_EXEMPT_IDS)
        for level in levels:
            # Reuse the calibration simulation: it is the same seed, the same
            # bot and the same budget, so the numbers cannot disagree.
            reports.append(validator.validate(
                level, simulation=simulations.get(level.id)))
        errors = [r for r in reports if not r.ok]
        warnings = [r for r in reports if r.warnings]
        print("validation: %d levels, %d with errors, %d with warnings"
              % (len(reports), len(errors), len(warnings)))
        for report in errors[:20]:
            print("  ERROR level %d: %s" % (report.level_id, report.summary()))
        for report in warnings[:20]:
            print("  WARN  level %d: %s" % (report.level_id, report.summary()))

    # --- export ------------------------------------------------------------
    chapters = {}
    for level in levels:
        chapters.setdefault(level.chapter, []).append(level)

    for chapter in sorted(chapters):
        theme = CHAPTER_THEMES[(chapter - 1) % len(CHAPTER_THEMES)]
        start, end = generator.chapter_range(chapter)
        payload = {
            "chapter": chapter,
            "theme": theme,
            "nameKey": "chapter_%d" % chapter,
            "startLevel": start,
            "endLevel": end,
            "levels": [level.to_json() for level in chapters[chapter]],
        }
        path = os.path.join(out_dir, "chapter_%02d.json" % chapter)
        with open(path, "w", encoding="utf-8") as handle:
            json.dump(payload, handle, indent=1, ensure_ascii=False)
            handle.write("\n")
        print("wrote %s (%d levels)" % (os.path.relpath(path), len(chapters[chapter])))

    total_bytes = sum(
        os.path.getsize(os.path.join(out_dir, name))
        for name in os.listdir(out_dir) if name.endswith(".json"))
    print("done: %d levels in %d chapters, %.1f KB total, %.0fs"
          % (len(levels), len(chapters), total_bytes / 1024.0,
             time.time() - started))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
