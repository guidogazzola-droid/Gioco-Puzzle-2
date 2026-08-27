#!/usr/bin/env python3
"""Checks the three places a product identifier has to agree.

A typo in one of them is invisible until a real purchase fails on a real
device, which is the most expensive place to find it:

  * PuzzleKit's StoreProductID - what the app asks StoreKit for
  * Configuration/Products.storekit - what the simulator serves back
  * the localisation files - what the shop screen renders

App Store Connect is the fourth; docs/APP_STORE_CHECKLIST.md covers it.

Run: python3 tools/check_products.py
"""
import json
import pathlib
import re
import sys

CATALOG = pathlib.Path("PuzzleKit/Sources/PuzzleKit/Economy/ProductCatalog.swift")
STOREKIT = pathlib.Path("Configuration/Products.storekit")
STRINGS = sorted(pathlib.Path(".").glob("PrismFlow/Resources/*.lproj/Localizable.strings"))


def swift_products():
    text = CATALOG.read_text()
    ids = set(re.findall(r'= "(com\.prismflow\.game\.[\w.]+)"', text))
    group = re.search(r'subscriptionGroupID = "([^"]+)"', text)
    return ids, (group.group(1) if group else None)


def storekit_products():
    config = json.loads(STOREKIT.read_text())
    ids = {product["productID"] for product in config["products"]}
    groups = {}
    for group in config["subscriptionGroups"]:
        groups[group["id"]] = {s["productID"] for s in group["subscriptions"]}
        ids |= groups[group["id"]]
    return ids, groups, config


def main():
    failures = []

    declared, group_id = swift_products()
    served, groups, config = storekit_products()

    for missing in sorted(declared - served):
        failures.append(f"{missing} is requested by the app but not in Products.storekit")
    for extra in sorted(served - declared):
        failures.append(f"{extra} is in Products.storekit but the app never asks for it")

    if group_id not in groups:
        failures.append(
            f"subscription group '{group_id}' in ProductCatalog.swift is not in Products.storekit "
            f"(found {sorted(groups)})"
        )

    # Every subscription must offer a trial: it is the single biggest lever on
    # subscription conversion, and forgetting it is silent.
    for group in config["subscriptionGroups"]:
        for subscription in group["subscriptions"]:
            if "introductoryOffer" not in subscription:
                failures.append(f"{subscription['productID']} has no introductory offer")

    # Both languages must name and describe every product.
    for path in STRINGS:
        keys = set(re.findall(r'^\s*"([^"]+)"\s*=', path.read_text(encoding="utf-8"), re.M))
        for identifier in sorted(declared):
            short = identifier.removeprefix("com.prismflow.game.")
            for suffix in ("name", "description"):
                key = f"product.{short}.{suffix}"
                if key not in keys:
                    failures.append(f"{path.parent.name}: missing {key}")

    print(f"app products: {len(declared)}   storekit products: {len(served)}   "
          f"subscription group: {group_id}")
    for failure in failures:
        print(f"  FAIL  {failure}")
    print("products consistent" if not failures else f"{len(failures)} problems")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
