#!/usr/bin/env python3
"""Structural checks on the Xcode project, scheme and plists.

None of these need Xcode. They catch the damage a bad merge does to a
project file - a dangling object reference, an unbalanced brace, a scheme
pointing at a target that no longer exists - which otherwise shows up as
"cannot open project" with no explanation.

Run: python3 tools/check_project.py
"""
import collections
import pathlib
import plistlib
import re
import sys
import xml.dom.minidom

PROJECT = pathlib.Path("PrismFlow.xcodeproj/project.pbxproj")
SCHEME = pathlib.Path("PrismFlow.xcodeproj/xcshareddata/xcschemes/PrismFlow.xcscheme")
PLISTS = [
    pathlib.Path("PrismFlow/Info.plist"),
    pathlib.Path("PrismFlow/PrivacyInfo.xcprivacy"),
]
STOREKIT_IN_SCHEME = "../../../Configuration/Products.storekit"


def check_pbxproj(failures):
    text = PROJECT.read_text()
    identifiers = re.findall(r"\b([0-9A-F]{24})\b", text)
    counts = collections.Counter(identifiers)
    defined = set(re.findall(r"^\t\t([0-9A-F]{24}) ", text, re.M))

    for dangling in sorted(set(identifiers) - defined):
        failures.append(f"pbxproj references {dangling} but never defines it")
    for orphan in sorted(i for i in defined if counts[i] < 2):
        failures.append(f"pbxproj defines {orphan} but nothing references it")
    if text.count("{") != text.count("}"):
        failures.append("pbxproj braces are unbalanced")
    if text.count("(") != text.count(")"):
        failures.append("pbxproj parentheses are unbalanced")

    for section in re.findall(r"/\* Begin (\w+) section \*/", text):
        if text.count(f"/* End {section} section */") != 1:
            failures.append(f"pbxproj section {section} is not closed exactly once")

    # The app target must not also copy Info.plist in as a resource.
    if "membershipExceptions" not in text or "Info.plist," not in text:
        failures.append("pbxproj does not exclude Info.plist from the synchronised group")

    # Every target the scheme names must exist.
    return set(re.findall(r"^\t\t([0-9A-F]{24}) /\* (\w+) \*/ = \{\n\t\t\tisa = PBXNativeTarget",
                          text, re.M))


def check_scheme(failures, targets):
    text = SCHEME.read_text()
    xml.dom.minidom.parseString(text)
    for identifier in re.findall(r'BlueprintIdentifier = "([0-9A-F]{24})"', text):
        if identifier not in {t for t in targets}:
            failures.append(f"scheme points at unknown target {identifier}")
    if STOREKIT_IN_SCHEME not in text:
        failures.append("scheme does not reference Configuration/Products.storekit")
    if not pathlib.Path("Configuration/Products.storekit").exists():
        failures.append("Configuration/Products.storekit is missing")


def check_plists(failures):
    for path in PLISTS:
        try:
            plistlib.loads(path.read_bytes())
        except Exception as error:
            failures.append(f"{path} does not parse: {error}")

    info = plistlib.loads(pathlib.Path("PrismFlow/Info.plist").read_bytes())
    for key in ("CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion",
                "UILaunchScreen", "ITSAppUsesNonExemptEncryption"):
        if key not in info:
            failures.append(f"Info.plist is missing {key}")

    icon = pathlib.Path("PrismFlow/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
    if not icon.exists():
        failures.append("the app icon is missing")
    else:
        header = icon.read_bytes()[:26]
        if header[:8] != b"\x89PNG\r\n\x1a\n":
            failures.append("the app icon is not a PNG")
        elif header[25] != 2:
            # Colour type 2 is RGB. iOS rejects icons that carry alpha.
            failures.append("the app icon has an alpha channel; iOS icons must be opaque")


def main():
    failures = []
    targets = check_pbxproj(failures)
    check_scheme(failures, {t[0] for t in targets})
    check_plists(failures)

    print(f"targets: {sorted(name for _, name in targets)}")
    for failure in failures:
        print(f"  FAIL  {failure}")
    print("project structure ok" if not failures else f"{len(failures)} problems")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
