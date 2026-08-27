#!/usr/bin/env python3
"""Runs every check that does not need a Mac.

This is what CI runs on a Linux box, and what to run before opening a pull
request. It does not replace `swift test` - it covers the parts a Swift test
cannot reach: the generation algorithm as an executable specification, the
palettes, the localisation, the product wiring and the project file.

Run: python3 tools/verify.py
"""
import subprocess
import sys

CHECKS = [
    ("generation algorithm", ["python3", "tools/generator_reference.py", "--levels", "200"]),
    ("cosmetic palettes", ["python3", "tools/palette_builder.py", "--check"]),
    ("localisation", ["python3", "tools/check_localization.py"]),
    ("store products", ["python3", "tools/check_products.py"]),
    ("xcode project", ["python3", "tools/check_project.py"]),
]


def main():
    failed = []
    for name, command in CHECKS:
        print(f"\n=== {name} " + "=" * max(0, 56 - len(name)))
        result = subprocess.run(command)
        if result.returncode != 0:
            failed.append(name)

    print("\n" + "=" * 62)
    if failed:
        print("FAILED: " + ", ".join(failed))
        return 1
    print(f"all {len(CHECKS)} checks passed")
    return 0


if __name__ == "__main__":
    sys.exit(main())
