#!/usr/bin/env python3
"""Checks that every localisation key referenced in Swift exists in every
.strings file, and that no .strings file carries a key nothing uses.

A missing key ships as a raw dotted identifier on screen; an unused one is
usually a rename that was only half applied. Both are cheap to catch here and
expensive to catch in review.

Run: python3 tools/check_localization.py
"""
import pathlib
import re
import sys

SOURCE_DIRS = ["PrismFlow", "PuzzleKit/Sources"]
STRINGS_GLOB = "PrismFlow/Resources/*.lproj/Localizable.strings"

# Keys built at runtime from an enum or a catalogue rather than written out.
DYNAMIC_PREFIXES = (
    "chapter.",
    "cosmetic.category.",
    "cosmetic.palette.",
    "cosmetic.trail.",
    "cosmetic.background.",
    "cosmetic.node.",
    "product.",
    "period.",
)

KEY_PATTERN = re.compile(r'"([a-z][A-Za-z0-9]*(?:\.[A-Za-z0-9]+)+)"')

# Dotted string literals that are not localisation keys: SF Symbol names and
# the short product slugs the product keys are assembled from.
SYMBOL_ARGUMENT = re.compile(r'(?:system(?:Name|Image)|\bicon)\s*:')
TUPLE_LEAD = re.compile(r'^\s*\("([^"]+)",', re.M)     # (symbol, titleKey, bodyKey) tuples
QUOTED = re.compile(r'"([^"]+)"')


def symbol_literals(text):
    """Every string handed to an SF Symbol argument, ternaries included."""
    found = set(TUPLE_LEAD.findall(text))
    for match in SYMBOL_ARGUMENT.finditer(text):
        line = text[match.end():].split("\n", 1)[0]
        # Only this argument, not the rest of the call: `icon:` is often
        # followed by `titleKey:` on the same line.
        argument = re.split(r"[,)]", line, maxsplit=1)[0]
        found |= set(QUOTED.findall(argument))
    return found


def swift_keys():
    keys, symbols = set(), set()
    for directory in SOURCE_DIRS:
        for path in pathlib.Path(directory).rglob("*.swift"):
            text = path.read_text()
            symbols |= symbol_literals(text)
            for match in KEY_PATTERN.finditer(text):
                key = match.group(1)
                if key.startswith("com.") or "/" in key:
                    continue
                if key.endswith((".swift", ".json", ".png")):
                    continue
                keys.add(key)

    return keys - symbols


def dynamic_keys():
    """Keys assembled at runtime, reconstructed from the catalogues."""
    keys = set()
    catalog = pathlib.Path("PuzzleKit/Sources/PuzzleKit/Economy/CosmeticCatalog.swift").read_text()
    keys |= set(re.findall(r'nameKey: "([^"]+)"', catalog))
    for category in ("palette", "trail", "background", "nodeShape"):
        keys.add(f"cosmetic.category.{category}")

    chapters = pathlib.Path("PuzzleKit/Sources/PuzzleKit/Progression/Chapter.swift").read_text()
    keys |= set(re.findall(r'\("(chapter\.[a-z]+)"', chapters))

    products = pathlib.Path("PuzzleKit/Sources/PuzzleKit/Economy/ProductCatalog.swift").read_text()
    for short in re.findall(r':\s*"([a-z]+(?:\.[a-z]+)?)"\s*$', products, re.M):
        keys.add(f"product.{short}.name")
        keys.add(f"product.{short}.description")
    for unit in ("day", "week", "month", "year"):
        keys.add(f"period.{unit}")
    return keys


def strings_keys(path):
    text = path.read_text(encoding="utf-8")
    return set(re.findall(r'^\s*"([^"]+)"\s*=', text, re.M))


def main():
    referenced = swift_keys() | dynamic_keys()
    # Drop the short product slugs (`gems.pouch`) that only exist so the real
    # keys (`product.gems.pouch.name`) can be assembled from them.
    referenced -= {k for k in referenced if f"product.{k}.name" in referenced}
    files = sorted(pathlib.Path(".").glob(STRINGS_GLOB))
    if not files:
        print("no .strings files found")
        return 1

    failures = 0
    baseline = None
    for path in files:
        defined = strings_keys(path)
        if baseline is None:
            baseline = defined

        missing = sorted(referenced - defined)
        unused = sorted(k for k in defined - referenced
                        if not k.startswith(DYNAMIC_PREFIXES))
        drift = sorted(baseline.symmetric_difference(defined))

        print(f"{path}: {len(defined)} keys")
        for key in missing:
            print(f"  MISSING  {key}")
        for key in unused:
            print(f"  UNUSED   {key}")
        for key in drift:
            print(f"  DRIFT    {key} (not in every language)")
        failures += len(missing) + len(unused) + len(drift)

    print(f"\n{len(referenced)} keys referenced in source - problems: {failures}")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
