#!/usr/bin/env python3
"""Runs the whole MERGE DROP mirror test-suite.

    python3 tool/mirror/run_tests.py [-v] [pattern]
"""
import argparse
import os
import sys
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)
sys.path.insert(0, os.path.join(HERE, "tests"))


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("pattern", nargs="?", default="test_*.py")
    parser.add_argument("-v", "--verbose", action="store_true")
    args = parser.parse_args()

    loader = unittest.TestLoader()
    suite = loader.discover(os.path.join(HERE, "tests"), pattern=args.pattern)
    runner = unittest.TextTestRunner(verbosity=2 if args.verbose else 1)
    result = runner.run(suite)
    return 0 if result.wasSuccessful() else 1


if __name__ == "__main__":
    raise SystemExit(main())
