#!/usr/bin/env python3
"""Uploads the App Store listing through the App Store Connect API (credentials: see
scripts/asc.py): texts from fastlane/metadata, category, copyright and the App Store images.

    scripts/upload-metadata.py                         # what would change
    scripts/upload-metadata.py --apply                 # write texts; upload images to empty sets
    scripts/upload-metadata.py --apply --replace-screenshots   # also replace uploaded images

Texts are written as they are in fastlane/metadata (same layout fastlane deliver uses, so it
could take over later). Only the version being prepared is touched. Images: iPhone 6.9"
(AppStore/store-images/iphone-6.9) and iPad 13" (ipad-13); App Store Connect scales them
down for smaller devices. "What's New" isn't sent for the first version.
"""
import hashlib
import pathlib
import sys

import asc

ROOT = pathlib.Path(__file__).resolve().parent.parent
METADATA = ROOT / "fastlane/metadata"
IMAGES = ROOT / "AppStore/store-images"
BUNDLE_ID = "com.tavoohoh.quietsudoku"
LOCALES = {"en-US": "en", "es-MX": "es"}
COPYRIGHT = "2026 Quiet Studios"
# Games › Puzzle, with Board as the second subcategory.
CATEGORY = {"primaryCategory": "GAMES", "primarySubcategoryOne": "GAMES_PUZZLE", "primarySubcategoryTwo": "GAMES_BOARD"}
SCREENSHOTS = {"APP_IPHONE_67": "iphone-6.9", "APP_IPAD_PRO_3GEN_129": "ipad-13"}

APPLY = "--apply" in sys.argv
REPLACE = "--replace-screenshots" in sys.argv


def text(locale, name):
    path = METADATA / locale / f"{name}.txt"
    return path.read_text().rstrip("\n") if path.exists() else None


def write(method, path, kind, attributes=None, relationships=None, identifier=None):
    if not APPLY:
        return {"id": "(dry run)"}
    data = {"type": kind}
    if identifier:
        data["id"] = identifier
    if attributes:
        data["attributes"] = attributes
    if relationships:
        data["relationships"] = relationships
    response = asc.request(method, path, {"data": data})
    return response["data"] if response else None


def relation(kind, identifier):
    return {"data": {"type": kind, "id": identifier}}


def sync_localization(kind, parent_kind, parent_id, existing, locale, wanted):
    """Creates or updates one localization with the fields that differ."""
    current = existing.get(locale)
    if current is None:
        print(f"+ {kind} {locale}: {', '.join(wanted)}")
        write("POST", f"/v1/{kind}", kind, {"locale": locale, **wanted},
              {parent_kind[0]: relation(parent_kind[1], parent_id)})
        return
    changed = {k: v for k, v in wanted.items() if current["attributes"].get(k) != v}
    if changed:
        print(f"~ {kind} {locale}: {', '.join(changed)}")
        write("PATCH", f"/v1/{kind}/{current['id']}", kind, changed, identifier=current["id"])


def app_info(app_id):
    infos = asc.request("GET", f"/v1/apps/{app_id}/appInfos")["data"]
    info = next(i for i in infos if i["attributes"]["state"] != "READY_FOR_DISTRIBUTION")
    existing = {l["attributes"]["locale"]: l for l in asc.get_all(f"/v1/appInfos/{info['id']}/appInfoLocalizations")}
    for locale in LOCALES:
        wanted = {"name": text(locale, "name"), "subtitle": text(locale, "subtitle"),
                  "privacyPolicyUrl": text(locale, "privacy_url")}
        sync_localization("appInfoLocalizations", ("appInfo", "appInfos"), info["id"], existing, locale, wanted)
    current = {k: (asc.request("GET", f"/v1/appInfos/{info['id']}/relationships/{k}")["data"] or {}).get("id")
               for k in CATEGORY}
    if current != CATEGORY:
        print(f"~ category: {' › '.join(CATEGORY.values())}")
        write("PATCH", f"/v1/appInfos/{info['id']}", "appInfos", identifier=info["id"],
              relationships={k: relation("appCategories", v) for k, v in CATEGORY.items()})


def version(app_id):
    versions = asc.request("GET", f"/v1/apps/{app_id}/appStoreVersions?filter[platform]=IOS")["data"]
    editable = [v for v in versions if v["attributes"]["appStoreState"] in
                ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED")]
    if not editable:
        raise SystemExit("No iOS version being prepared in App Store Connect.")
    current = editable[0]
    first = len(versions) == 1
    print(f"Version {current['attributes']['versionString']} ({current['attributes']['appStoreState']})")
    if current["attributes"].get("copyright") != COPYRIGHT:
        print(f"~ copyright: {COPYRIGHT}")
        write("PATCH", f"/v1/appStoreVersions/{current['id']}", "appStoreVersions", {"copyright": COPYRIGHT},
              identifier=current["id"])
    existing = {l["attributes"]["locale"]: l for l in
                asc.get_all(f"/v1/appStoreVersions/{current['id']}/appStoreVersionLocalizations")}
    for locale in LOCALES:
        wanted = {"description": text(locale, "description"), "keywords": text(locale, "keywords"),
                  "promotionalText": text(locale, "promotional_text"), "supportUrl": text(locale, "support_url"),
                  "marketingUrl": text(locale, "marketing_url") or text(locale, "support_url").rsplit("/", 1)[0] + "/"}
        if not first:
            wanted["whatsNew"] = text(locale, "release_notes")
        sync_localization("appStoreVersionLocalizations", ("appStoreVersion", "appStoreVersions"), current["id"],
                          existing, locale, wanted)
    if APPLY:
        existing = {l["attributes"]["locale"]: l for l in
                    asc.get_all(f"/v1/appStoreVersions/{current['id']}/appStoreVersionLocalizations")}
    return existing


def upload(set_id, path):
    data = path.read_bytes()
    shot = write("POST", "/v1/appScreenshots", "appScreenshots", {"fileName": path.name, "fileSize": len(data)},
                 {"appScreenshotSet": relation("appScreenshotSets", set_id)})
    if not APPLY:
        return
    for operation in shot["attributes"]["uploadOperations"]:
        chunk = data[operation["offset"]:operation["offset"] + operation["length"]]
        headers = {h["name"]: h["value"] for h in operation.get("requestHeaders", [])}
        asc.request(operation["method"], None, raw=chunk, headers=headers, url=operation["url"])
    write("PATCH", f"/v1/appScreenshots/{shot['id']}", "appScreenshots",
          {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}, identifier=shot["id"])


def screenshots(localizations):
    for locale, language in LOCALES.items():
        localization = localizations.get(locale)
        if localization is None:  # dry run: created on --apply
            print(f"  {locale}: images after the localization exists")
            continue
        sets = {s["attributes"]["screenshotDisplayType"]: s for s in
                asc.get_all(f"/v1/appStoreVersionLocalizations/{localization['id']}/appScreenshotSets")}
        for display, folder in SCREENSHOTS.items():
            files = sorted((IMAGES / folder / language).glob("*.png"))
            if not files:
                raise SystemExit(f"No images in {IMAGES / folder / language}; run scripts/store-images.py")
            current = sets.get(display)
            if current is None:
                print(f"+ {locale} {display} set")
                current = write("POST", "/v1/appScreenshotSets", "appScreenshotSets", {"screenshotDisplayType": display},
                                {"appStoreVersionLocalization": relation("appStoreVersionLocalizations", localization["id"])})
                uploaded = []
            else:
                uploaded = asc.get_all(f"/v1/appScreenshotSets/{current['id']}/appScreenshots")
            if uploaded and not REPLACE:
                print(f"= {locale} {display}: {len(uploaded)} images already (--replace-screenshots to replace)")
                continue
            for old in uploaded:
                print(f"- {locale} {display}: {old['attributes']['fileName']}")
                if APPLY:
                    asc.request("DELETE", f"/v1/appScreenshots/{old['id']}")
            for path in files:
                print(f"+ {locale} {display}: {path.name}")
                upload(current["id"], path)


def main():
    apps = asc.request("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")["data"]
    if not apps:
        raise SystemExit(f"No app with bundle ID {BUNDLE_ID} in App Store Connect yet; create it first.")
    app_info(apps[0]["id"])
    localizations = version(apps[0]["id"])
    # The store images come in phase 6; until then only texts, category and copyright.
    if IMAGES.exists():
        screenshots(localizations)
    else:
        print(f"(no {IMAGES.relative_to(ROOT)} yet: images skipped)")
    print("Done." if APPLY else "Dry run; pass --apply to write.")


if __name__ == "__main__":
    main()
