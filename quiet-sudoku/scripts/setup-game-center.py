#!/usr/bin/env python3
"""Creates the Game Center achievements and leaderboards from AppStore/game-center.json
through the App Store Connect API (credentials: see scripts/asc.py).

    scripts/setup-game-center.py            # what would change
    scripts/setup-game-center.py --apply    # create what's missing, update visibility

Idempotent: matches by vendor identifier and locale and only creates what's missing;
it never deletes and only edits whether an achievement shows before it is earned. The app must already exist in App Store Connect.
"""
import json
import pathlib
import sys

import asc

ROOT = pathlib.Path(__file__).resolve().parent.parent
BUNDLE_ID = "com.tavoohoh.quietsudoku"
# Game Center locales: English (U.S.) and Spanish (Mexico), like the store listing.
LOCALES = {"en-US": "en", "es-MX": "es"}
# The daily board resets at 05:00 UTC, midnight in Colombia (DailyKey.rolloverHour = 0 in QuietKit).
DAILY_START = "2026-10-31T05:00:00Z"
SINGULAR = {" points": " point", " puntos": " punto", " days": " day", " días": " día"}

APPLY = "--apply" in sys.argv


def create(kind, attributes, relationships):
    if not APPLY:
        return {"id": "(dry run)"}
    body = {"data": {"type": kind, "attributes": attributes, "relationships": relationships}}
    return asc.request("POST", f"/v1/{kind}", body)["data"]


def relation(kind, identifier):
    return {"data": {"type": kind, "id": identifier}}


def game_center_detail(app_id):
    detail = asc.request("GET", f"/v1/apps/{app_id}/gameCenterDetail")
    if detail and detail.get("data"):
        return detail["data"]["id"]
    print("+ Game Center for the app")
    return create("gameCenterDetails", {}, {"app": relation("apps", app_id)})["id"]


def upload_image(localization_id, path):
    print(f"    + image {path.name}")
    if not APPLY:
        return
    data = path.read_bytes()
    image = create("gameCenterAchievementImages", {"fileName": path.name, "fileSize": len(data)},
                   {"gameCenterAchievementLocalization": relation("gameCenterAchievementLocalizations", localization_id)})
    for operation in image["attributes"]["uploadOperations"]:
        chunk = data[operation["offset"]:operation["offset"] + operation["length"]]
        headers = {h["name"]: h["value"] for h in operation.get("requestHeaders", [])}
        asc.request(operation["method"], None, raw=chunk, headers=headers, url=operation["url"])
    asc.request("PATCH", f"/v1/gameCenterAchievementImages/{image['id']}",
                {"data": {"type": "gameCenterAchievementImages", "id": image["id"], "attributes": {"uploaded": True}}})


def achievements(detail_id, specs):
    existing = {} if detail_id == "(dry run)" else {
        a["attributes"]["vendorIdentifier"]: a["id"]
        for a in asc.get_all(f"/v1/gameCenterDetails/{detail_id}/gameCenterAchievements?limit=200")
    }
    for spec in specs:
        achievement_id = existing.get(spec["id"])
        if not achievement_id:
            print(f"+ achievement {spec['id']} ({spec['points']} points{', hidden' if spec['hidden'] else ''})")
            achievement_id = create("gameCenterAchievements", {
                "referenceName": spec["name"]["en"],
                "vendorIdentifier": spec["id"],
                "points": spec["points"],
                "showBeforeEarned": not spec["hidden"],
                "repeatable": spec["achievableMoreThanOnce"],
            }, {"gameCenterDetail": relation("gameCenterDetails", detail_id)})["id"]
        else:
            current = asc.request("GET", f"/v1/gameCenterAchievements/{achievement_id}")["data"]["attributes"]
            if current["showBeforeEarned"] != (not spec["hidden"]):
                print(f"~ achievement {spec['id']}: {'hidden' if spec['hidden'] else 'shown'} before earned")
                if APPLY:
                    asc.request("PATCH", f"/v1/gameCenterAchievements/{achievement_id}", {"data": {
                        "type": "gameCenterAchievements", "id": achievement_id,
                        "attributes": {"showBeforeEarned": not spec["hidden"]},
                    }})
        localizations = {} if achievement_id == "(dry run)" else {
            l["attributes"]["locale"]: l["id"]
            for l in asc.get_all(f"/v1/gameCenterAchievements/{achievement_id}/localizations?limit=50")
        }
        for locale, language in LOCALES.items():
            localization_id = localizations.get(locale)
            if not localization_id:
                print(f"  + {locale}: {spec['name'][language]}")
                localization_id = create("gameCenterAchievementLocalizations", {
                    "locale": locale,
                    "name": spec["name"][language],
                    "beforeEarnedDescription": spec["preEarnedDescription"][language],
                    "afterEarnedDescription": spec["earnedDescription"][language],
                }, {"gameCenterAchievement": relation("gameCenterAchievements", achievement_id)})["id"]
                has_image = False
            else:
                image = asc.request("GET", f"/v1/gameCenterAchievementLocalizations/{localization_id}/gameCenterAchievementImage")
                has_image = bool(image and image.get("data"))
            if not has_image:
                upload_image(localization_id, ROOT / spec["image"])


def leaderboards(detail_id, specs):
    existing = {} if detail_id == "(dry run)" else {
        l["attributes"]["vendorIdentifier"]: l["id"]
        for l in asc.get_all(f"/v1/gameCenterDetails/{detail_id}/gameCenterLeaderboards?limit=200")
    }
    for spec in specs:
        leaderboard_id = existing.get(spec["id"])
        if not leaderboard_id:
            print(f"+ leaderboard {spec['id']} ({spec['type']})")
            attributes = {
                "referenceName": spec["name"]["en"],
                "vendorIdentifier": spec["id"],
                "defaultFormatter": "INTEGER",
                "submissionType": "MOST_RECENT_SCORE" if spec["scoreSubmission"] == "Most recent score" else "BEST_SCORE",
                "scoreSortType": "DESC",
            }
            if spec["type"] == "recurring":
                attributes.update(recurrenceStartDate=DAILY_START, recurrenceDuration="PT24H", recurrenceRule="FREQ=DAILY;INTERVAL=1")
            leaderboard_id = create("gameCenterLeaderboards", attributes,
                                    {"gameCenterDetail": relation("gameCenterDetails", detail_id)})["id"]
        localizations = {} if leaderboard_id == "(dry run)" else {
            l["attributes"]["locale"]
            for l in asc.get_all(f"/v1/gameCenterLeaderboards/{leaderboard_id}/localizations?limit=50")
        }
        for locale, language in LOCALES.items():
            if locale in localizations:
                continue
            suffix = spec["formatSuffix"][language]
            print(f"  + {locale}: {spec['name'][language]}")
            create("gameCenterLeaderboardLocalizations", {
                "locale": locale,
                "name": spec["name"][language],
                "formatterSuffix": suffix,
                "formatterSuffixSingular": SINGULAR[suffix],
            }, {"gameCenterLeaderboard": relation("gameCenterLeaderboards", leaderboard_id)})


def main():
    spec = json.loads((ROOT / "AppStore/game-center.json").read_text())
    apps = asc.request("GET", f"/v1/apps?filter[bundleId]={BUNDLE_ID}")["data"]
    if not apps:
        raise SystemExit(f"No app with bundle ID {BUNDLE_ID} in App Store Connect yet; create it first.")
    detail_id = game_center_detail(apps[0]["id"])
    achievements(detail_id, spec["achievements"])
    leaderboards(detail_id, spec["leaderboards"])
    print("Done." if APPLY else "Dry run; pass --apply to make these changes.")


if __name__ == "__main__":
    main()
