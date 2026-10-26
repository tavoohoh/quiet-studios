#!/usr/bin/env python3
"""Checks AppStore/game-center.json against the Game Center IDs in the code.

    scripts/check-game-center.py
"""
import json
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
service = (ROOT / "App/Services/GameCenterService.swift").read_text()
core = (ROOT / "Packages/QuietNumbersCore/Sources/QuietNumbersCore/Achievements.swift").read_text()
config = json.loads((ROOT / "AppStore/game-center.json").read_text())

cases = re.findall(r"^\s*case (\w+)\s*$", core.split("public var target")[0], re.MULTILINE)
achievement_ids = dict(re.findall(r'case \.(\w+): "([a-z_]+)"', service.split("var gameCenterID")[1]))
leaderboard_ids = dict(re.findall(r'case (\w+) = "([a-z_]+)"', service))

problems = []
for case in cases:
    if case not in achievement_ids:
        problems.append(f"Achievement.{case} has no gameCenterID")
configured = {a["id"]: a for a in config["achievements"]}
for case, identifier in achievement_ids.items():
    if identifier not in configured:
        problems.append(f"achievement '{identifier}' (Achievement.{case}) is missing from game-center.json")
    elif configured[identifier]["codeCase"] != f"Achievement.{case}":
        problems.append(f"achievement '{identifier}' maps to {configured[identifier]['codeCase']}, code says Achievement.{case}")
for identifier in configured.keys() - set(achievement_ids.values()):
    problems.append(f"achievement '{identifier}' is in game-center.json but not used in code")

boards = {l["id"] for l in config["leaderboards"]}
for case, identifier in leaderboard_ids.items():
    if identifier not in boards:
        problems.append(f"leaderboard '{identifier}' (.{case}) is missing from game-center.json")
    if f"to: .{case}" not in (ROOT / "App/AppModel.swift").read_text():
        problems.append(f"leaderboard '{identifier}' is never submitted to")
for identifier in boards - set(leaderboard_ids.values()):
    problems.append(f"leaderboard '{identifier}' is in game-center.json but not used in code")

total = sum(a["points"] for a in config["achievements"])
if total > 1000:
    problems.append(f"achievement points add up to {total} (max 1000)")
if any(a["points"] > 100 for a in config["achievements"]):
    problems.append("an achievement is worth more than 100 points")

print(f"{len(achievement_ids)} achievements, {total} points; {len(leaderboard_ids)} leaderboards.")
if problems:
    print("\n".join(f"  • {p}" for p in problems))
    sys.exit(1)
print("IDs in game-center.json match the code.")
