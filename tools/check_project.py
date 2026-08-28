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

WORKFLOWS = sorted(pathlib.Path(".github/workflows").glob("*.yml")) if \
    pathlib.Path(".github/workflows").is_dir() else []
PROJECT = pathlib.Path("LineFlow.xcodeproj/project.pbxproj")
SCHEME = pathlib.Path("LineFlow.xcodeproj/xcshareddata/xcschemes/LineFlow.xcscheme")
PLISTS = [
    pathlib.Path("LineFlow/Info.plist"),
    pathlib.Path("LineFlow/PrivacyInfo.xcprivacy"),
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

    info = plistlib.loads(pathlib.Path("LineFlow/Info.plist").read_bytes())
    for key in ("CFBundleIdentifier", "CFBundleShortVersionString", "CFBundleVersion",
                "UILaunchScreen", "ITSAppUsesNonExemptEncryption"):
        if key not in info:
            failures.append(f"Info.plist is missing {key}")

    icon = pathlib.Path("LineFlow/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon.png")
    if not icon.exists():
        failures.append("the app icon is missing")
    else:
        header = icon.read_bytes()[:26]
        if header[:8] != b"\x89PNG\r\n\x1a\n":
            failures.append("the app icon is not a PNG")
        elif header[25] != 2:
            # Colour type 2 is RGB. iOS rejects icons that carry alpha.
            failures.append("the app icon has an alpha channel; iOS icons must be opaque")


def check_workflows(failures):
    """Parse the CI workflows. An inline script with the wrong indentation
    silently invalidates the whole document, and GitHub only tells you after
    you have pushed it."""
    if not WORKFLOWS:
        return
    try:
        import yaml
    except ImportError:
        print("  (PyYAML not installed - skipping workflow syntax check)")
        return
    for path in WORKFLOWS:
        try:
            document = yaml.safe_load(path.read_text())
        except Exception as error:
            failures.append(f"{path} is not valid YAML: {error}")
            continue
        if not isinstance(document, dict) or "jobs" not in document:
            failures.append(f"{path} has no jobs")


def check_house_ad_videos(failures):
    """Every video a house advertisement names must be in the resources.

    A missing file is not a build error - the view falls back to its card - but
    the fallback exists for a corrupt install, not for a typo committed here.
    """
    path = pathlib.Path("LineFlow/Services/HouseAds.swift")
    if not path.exists():
        failures.append("HouseAds.swift is missing")
        return
    for name in re.findall(r'video:\s*"([^"]+)"', path.read_text()):
        video = pathlib.Path("LineFlow/Resources") / f"{name}.mp4"
        if not video.exists():
            failures.append(f"house ad names {name}.mp4, which is not in LineFlow/Resources")


def check_tracking_declaration(failures):
    """Info.plist and PrivacyInfo.xcprivacy have to tell the same story.

    App Store Connect refuses a build that asks for tracking permission while
    declaring it does not track - the two are read together, and the privacy
    manifest is the one reviewers trust. This is not a ban on the key: the day
    an ad network arrives, NSPrivacyTracking becomes true and the usage string
    becomes required. What is forbidden is shipping one without the other.
    """
    info = pathlib.Path("LineFlow/Info.plist")
    manifest = pathlib.Path("LineFlow/PrivacyInfo.xcprivacy")
    if not info.exists() or not manifest.exists():
        failures.append("Info.plist or PrivacyInfo.xcprivacy is missing")
        return

    project = pathlib.Path("LineFlow.xcodeproj/project.pbxproj").read_text()
    # Xcode can inject plist entries from build settings, which is a second
    # place the key can hide.
    asks_to_track = (
        "NSUserTrackingUsageDescription" in info.read_text()
        or "INFOPLIST_KEY_NSUserTrackingUsageDescription" in project
    )
    declares_tracking = "<key>NSPrivacyTracking</key>" in manifest.read_text() and \
        manifest.read_text().split("<key>NSPrivacyTracking</key>")[1].lstrip().startswith("<true/>")

    if asks_to_track and not declares_tracking:
        failures.append(
            "NSUserTrackingUsageDescription is present but PrivacyInfo.xcprivacy "
            "declares NSPrivacyTracking false - App Store Connect rejects that pair"
        )
    if declares_tracking and not asks_to_track:
        failures.append(
            "PrivacyInfo.xcprivacy declares tracking but no "
            "NSUserTrackingUsageDescription is set - ATT cannot be requested without it"
        )


def check_legal_links(failures):
    """A placeholder privacy or terms URL is a guaranteed rejection, and it is
    invisible until a reviewer taps it. The links are literals in one file, so
    the check is cheap and the failure is unambiguous."""
    path = pathlib.Path("LineFlow/Services/LegalLinks.swift")
    if not path.exists():
        failures.append("LegalLinks.swift is missing")
        return
    text = path.read_text()
    for placeholder in ("example.com", "example.org", "TODO", "REPLACE"):
        if placeholder in text:
            failures.append(f"LegalLinks.swift still contains a placeholder: {placeholder}")
    if "https://" not in text:
        failures.append("LegalLinks.swift has no https URL")


def main():
    failures = []
    targets = check_pbxproj(failures)
    check_scheme(failures, {t[0] for t in targets})
    check_plists(failures)
    check_workflows(failures)
    check_legal_links(failures)
    check_tracking_declaration(failures)
    check_house_ad_videos(failures)

    print(f"targets: {sorted(name for _, name in targets)}")
    print(f"workflows: {[p.name for p in WORKFLOWS]}")
    for failure in failures:
        print(f"  FAIL  {failure}")
    print("project structure ok" if not failures else f"{len(failures)} problems")
    return 1 if failures else 0


if __name__ == "__main__":
    sys.exit(main())
