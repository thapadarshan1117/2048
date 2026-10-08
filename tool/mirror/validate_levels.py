#!/usr/bin/env python3
"""Validates an exported level catalogue without regenerating it.

    python3 tool/mirror/validate_levels.py [--levels assets/levels] [--games 6]
"""
import argparse
import glob
import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "tests"))

from mergedrop.game_simulator import GameSimulator          # noqa: E402
from mergedrop.level import Level                            # noqa: E402
from mergedrop.level_validator import ERROR, WARNING, LevelValidator  # noqa: E402

# Levels 1-3 are the tutorial: they are supposed to be trivial.
TUTORIAL_EXEMPT_IDS = frozenset({1, 2, 3})


def load_catalogue(directory):
    levels = []
    for path in sorted(glob.glob(os.path.join(directory, "chapter_*.json"))):
        with open(path, encoding="utf-8") as handle:
            payload = json.load(handle)
        for raw in payload["levels"]:
            levels.append(Level.from_json(raw))
    levels.sort(key=lambda l: l.id)
    return levels


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--levels", default=os.path.join(
        os.path.dirname(HERE), "..", "assets", "levels"))
    parser.add_argument("--games", type=int, default=6)
    parser.add_argument("--skill", type=float, default=0.8)
    parser.add_argument("--sample", type=int, default=0,
                        help="validate every Nth level only (0 = all)")
    args = parser.parse_args(argv)

    levels = load_catalogue(os.path.abspath(args.levels))
    if not levels:
        print("no levels found in %s" % args.levels)
        return 1

    simulator = GameSimulator(skill=args.skill, max_moves=120)
    validator = LevelValidator(simulator=simulator, games=args.games,
                               skill=args.skill,
                               trivial_exempt_ids=TUTORIAL_EXEMPT_IDS)

    if args.sample:
        levels = levels[::args.sample]

    reports = [validator.validate(level) for level in levels]
    errors = [r for r in reports if not r.ok]
    warnings = [r for r in reports if r.warnings]

    for report in errors:
        print("ERROR %s" % report.summary())
    for report in warnings:
        print("WARN  %s" % report.summary())

    print("validated %d levels: %d errors, %d warnings"
          % (len(reports), len(errors), len(warnings)))
    return 1 if errors else 0


if __name__ == "__main__":
    raise SystemExit(main())
