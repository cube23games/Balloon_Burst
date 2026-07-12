#!/usr/bin/env python3
"""Balloon Burst SlimNation Audit v2.

A one-file static audit and evidence bundler for the Balloon Burst Flutter
project. It catches known regressions and obvious release risks, then writes
text, JSON, and ZIP reports. It does not replace real gameplay testing.

Usage:
    python tools/slimnation_audit.py
    python tools/slimnation_audit.py --strict

Default mode always writes reports and exits 0. --strict exits 1 when an open
FAIL exists, which is useful as a local verification gate after fixes.
"""

from __future__ import annotations

import argparse
import contextlib
import datetime as dt
import hashlib
import json
import re
import subprocess
import sys
import wave
import zipfile
from collections import Counter
from pathlib import Path
from typing import Any, Iterable

AUDIT_VERSION = "2.0"
ROOT = Path(__file__).resolve().parents[1]
REPORT_DIR = ROOT / "reports"
TXT_REPORT = REPORT_DIR / "slimnation_audit_report.txt"
JSON_REPORT = REPORT_DIR / "slimnation_audit_report.json"
ZIP_REPORT = REPORT_DIR / "slimnation_audit_bundle.zip"

TEXT_SUFFIXES = {
    ".dart", ".kt", ".kts", ".java", ".xml", ".gradle", ".yaml", ".yml",
    ".json", ".md", ".txt", ".properties", ".sh",
}
SCAN_ROOTS = ("lib", "android", ".github", "test", "integration_test")
TOP_LEVEL_TEXT_FILES = (
    "pubspec.yaml", "pubspec.lock", "analysis_options.yaml", "README.md",
)
OPEN_STATUSES = {"FAIL", "WARN"}
checks: list[dict[str, Any]] = []


def run_command(command: list[str]) -> tuple[int, str]:
    try:
        result = subprocess.run(
            command,
            cwd=ROOT,
            text=True,
            stdout=subprocess.PIPE,
            stderr=subprocess.STDOUT,
            check=False,
        )
        return result.returncode, result.stdout.strip()
    except OSError as exc:
        return 127, f"command unavailable: {exc}"


def git(*args: str) -> str:
    return run_command(["git", *args])[1]


def read_text(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""


def relative(path: Path) -> str:
    try:
        return str(path.relative_to(ROOT))
    except ValueError:
        return str(path)


def sha256(path: Path) -> str:
    digest = hashlib.sha256()
    try:
        with path.open("rb") as handle:
            for chunk in iter(lambda: handle.read(1024 * 1024), b""):
                digest.update(chunk)
        return digest.hexdigest()
    except OSError:
        return "unavailable"


def collect_text_files() -> dict[Path, str]:
    output: dict[Path, str] = {}
    for folder_name in SCAN_ROOTS:
        folder = ROOT / folder_name
        if not folder.exists():
            continue
        for path in folder.rglob("*"):
            if not path.is_file() or path.suffix.lower() not in TEXT_SUFFIXES:
                continue
            if any(part in {"build", ".dart_tool", ".gradle", "__pycache__"} for part in path.parts):
                continue
            try:
                if path.stat().st_size > 2_000_000:
                    continue
            except OSError:
                continue
            output[path] = read_text(path)
    for filename in TOP_LEVEL_TEXT_FILES:
        path = ROOT / filename
        if path.exists() and path.is_file():
            output[path] = read_text(path)
    return output


TEXT_FILES = collect_text_files()
ALL_TEXT = "\n".join(TEXT_FILES.values())


def add_check(
    section: str,
    name: str,
    status: str,
    priority: str,
    detail: str,
    evidence: Iterable[str] | None = None,
    recommendation: str = "",
) -> None:
    checks.append(
        {
            "section": section,
            "name": name,
            "status": status,
            "priority": priority,
            "detail": detail,
            "evidence": list(evidence or []),
            "recommendation": recommendation,
        }
    )


def matching_lines(
    text: str,
    pattern: str,
    *,
    limit: int = 20,
    flags: int = re.IGNORECASE,
) -> list[str]:
    regex = re.compile(pattern, flags)
    results: list[str] = []
    for number, line in enumerate(text.splitlines(), start=1):
        if regex.search(line):
            results.append(f"{number}: {line.strip()}")
            if len(results) >= limit:
                break
    return results


def file_hits(path: Path, pattern: str, *, limit: int = 20) -> list[str]:
    return [f"{relative(path)}:{line}" for line in matching_lines(read_text(path), pattern, limit=limit)]


def project_hits(pattern: str, *, limit: int = 20) -> list[str]:
    regex = re.compile(pattern, re.IGNORECASE)
    results: list[str] = []
    for path, text in sorted(TEXT_FILES.items(), key=lambda item: str(item[0])):
        for number, line in enumerate(text.splitlines(), start=1):
            if regex.search(line):
                results.append(f"{relative(path)}:{number}: {line.strip()}")
                if len(results) >= limit:
                    return results
    return results


def function_block(text: str, marker: str, *, max_lines: int = 140) -> str:
    """Return a practical source window beginning at marker.

    This deliberately avoids pretending to fully parse Dart. It is sufficient
    for the narrow structural regression checks in this audit.
    """
    lines = text.splitlines()
    start = next((i for i, line in enumerate(lines) if marker in line), None)
    if start is None:
        return ""
    return "\n".join(lines[start : start + max_lines])


def has_any(text: str, patterns: Iterable[str]) -> bool:
    return any(re.search(pattern, text, re.IGNORECASE | re.DOTALL) for pattern in patterns)


def inspect_repository() -> None:
    branch = git("branch", "--show-current")
    add_check(
        "Repository",
        "Audit is running on main",
        "PASS" if branch == "main" else "FAIL",
        "P0",
        f"Current branch is {branch or 'unknown'}.",
        recommendation="Run release verification only from main.",
    )

    status = git("status", "--short")
    tracked_dirty = git("diff", "--name-only") or git("diff", "--cached", "--name-only")
    add_check(
        "Repository",
        "Tracked working tree is clean",
        "PASS" if not tracked_dirty else "WARN",
        "P1",
        "No tracked changes are present." if not tracked_dirty else "Tracked changes are present while auditing.",
        status.splitlines()[:30],
        "Commit or intentionally review tracked changes before calling a build verified.",
    )


def inspect_gameplay_tuning() -> None:
    path = ROOT / "lib/game/balloon_spawner.dart"
    text = read_text(path)
    if not text:
        add_check("Gameplay", "Balloon spawner available", "FAIL", "P0", f"Missing {relative(path)}.")
        return

    expected = (
        "1.68", "0.92", "0.60", "clusterOriginRangeWorld4 = 0.86",
        "0.58", "0.24", "0.045",
    )
    missing = [token for token in expected if token not in text]
    add_check(
        "Gameplay",
        "TJ-43A World 4 tuning remains present",
        "PASS" if not missing else "WARN",
        "P1",
        "Expected World 4 tuning values were found." if not missing else f"Missing expected tuning markers: {', '.join(missing)}.",
        file_hits(path, r"worldSpeedMultiplier|worldSpawnInterval|minThreshold|clusterOriginRangeWorld4|outwardFloor|exponent|asymmetry", limit=35),
        "Do not silently lose TJ-43A while applying later gameplay fixes.",
    )

    cluster_rule = "no 5-clusters" in text.lower() and "rare 4-clusters" in text.lower()
    add_check(
        "Gameplay",
        "World 3 cluster control remains present",
        "PASS" if cluster_rule else "WARN",
        "P1",
        "World 3 documents no five-balloon clusters and rare fours." if cluster_rule else "World 3 cluster restrictions are not clearly present.",
        file_hits(path, r"no 5-clusters|rare 4-clusters|Pressure world", limit=10),
    )

    game_screen = read_text(ROOT / "lib/screens/game_screen.dart")
    combined_formula = has_any(
        game_screen,
        (
            r"spawner\.speedMultiplier\s*\*\s*widget\.engine\.difficulty\.speedMultiplier",
            r"difficulty\.speedMultiplier\s*\*\s*widget\.spawner\.speedMultiplier",
        ),
    )
    add_check(
        "Gameplay",
        "Multiple difficulty multipliers are intentionally visible",
        "INFO" if combined_formula else "PASS",
        "P1",
        "Movement speed multiplies world/spawner and engine difficulty ramps." if combined_formula else "No obvious compounded multiplier formula was found.",
        file_hits(ROOT / "lib/screens/game_screen.dart", r"speedMultiplier|balloonTypeMultiplier|final speed", limit=20),
        "Treat both ramps as one system when tuning fairness.",
    )

    telemetry_patterns = (
        r"effectiveSpeed",
        r"combinedSpeed",
        r"combinedMultiplier",
        r"actualSpeed",
        r"movementPxPerSecond",
        r"effectiveSpawn",
        r"actualSpawnInterval",
    )
    telemetry_hits = project_hits("|".join(telemetry_patterns), limit=20)
    add_check(
        "Diagnostics",
        "Combined effective difficulty telemetry",
        "PASS" if telemetry_hits else "WARN",
        "P1",
        "Combined/effective speed or spawn telemetry is present." if telemetry_hits else "Diagnostics do not clearly expose the combined world × engine movement pressure and effective spawn threshold.",
        telemetry_hits,
        "Log the actual final balloon speed and effective spawn interval before further World 3 tuning.",
    )

    add_check(
        "Gameplay",
        "Human difficulty verification",
        "WARN",
        "P1",
        "Static checks cannot prove Worlds 3 and 4 are fun, fair, or beatable.",
        recommendation="Run three complete no-YouTube tests and record the first unfair world and cause of death.",
    )


def inspect_audio() -> None:
    native_hits = project_hits(r"\bSoundPool\b|native.?pop|playNativePop|MethodChannel.*(pop|audio)|(pop|audio).*MethodChannel", limit=25)
    add_check(
        "Audio",
        "Native pop bridge remains removed",
        "PASS" if not native_hits else "FAIL",
        "P0",
        "No native SoundPool/pop MethodChannel path was found." if not native_hits else "A possible native pop bridge was found.",
        native_hits,
        "Do not reintroduce the native SoundPool path without overwhelming evidence.",
    )

    audio_path = ROOT / "lib/audio/audio_player.dart"
    audio_text = read_text(audio_path)
    warm_hits = file_hits(audio_path, r"warm|preload|_popWarmed|setSource|prime", limit=20)
    add_check(
        "Audio",
        "Pop audio warmup",
        "PASS" if warm_hits else "WARN",
        "P1",
        "Pop warmup evidence was found." if warm_hits else "No clear pop warmup evidence was found.",
        warm_hits,
    )

    game_path = ROOT / "lib/screens/game_screen.dart"
    game_text = read_text(game_path)
    pop_lines = file_hits(game_path, r"AudioPlayerService\.playPop", limit=10)
    delayed = has_any(function_block(game_text, "AudioPlayerService.playPop", max_lines=2), (r"addPostFrameCallback",))
    miss_return_before_pop = bool(re.search(r"TAP RESULT miss[\s\S]{0,900}?return;[\s\S]{0,300}?AudioPlayerService\.playPop", game_text))
    status = "PASS" if pop_lines and not delayed and miss_return_before_pop else "FAIL" if delayed else "WARN"
    add_check(
        "Audio",
        "Pop audio is immediate and after the miss return",
        status,
        "P0" if status == "FAIL" else "P1",
        "The miss path returns before immediate pop audio." if status == "PASS" else "The audit could not prove immediate confirmed-hit pop placement.",
        pop_lines,
        "Keep pop audio inside successful-hit processing and outside post-frame callbacks.",
    )

    wav_results: list[str] = []
    wav_warnings: list[str] = []
    pop_wavs = sorted(
        path for path in ROOT.rglob("*.wav")
        if path.stem.lower() == "pop" or path.stem.lower().startswith("pop_")
    )
    for path in pop_wavs:
        try:
            with contextlib.closing(wave.open(str(path), "rb")) as handle:
                rate = handle.getframerate()
                duration = handle.getnframes() / rate if rate else 0.0
                result = f"{relative(path)}: {duration:.3f}s, {handle.getnchannels()} channel(s), {rate} Hz"
                wav_results.append(result)
                if duration > 0.30:
                    wav_warnings.append(result)
        except (wave.Error, OSError) as exc:
            wav_warnings.append(f"{relative(path)}: unreadable ({exc})")
    add_check(
        "Audio",
        "Pop WAV duration",
        "PASS" if wav_results and not wav_warnings else "WARN",
        "P1",
        "All pop WAV files are 0.30 seconds or shorter." if wav_results and not wav_warnings else "A pop WAV may be missing, long, or unreadable.",
        wav_results + [item for item in wav_warnings if item not in wav_results],
    )


def inspect_rendering_lifecycle() -> None:
    timing_hits = project_hits(r"_maxParticles|timingLockActive.*take|timingBurst\.take", limit=25)
    add_check(
        "Rendering",
        "Timing Lock particle limits",
        "PASS" if timing_hits else "WARN",
        "P1",
        "Particle caps/Timing Lock reductions were found." if timing_hits else "Expected particle caps were not clearly found.",
        timing_hits,
    )

    lightning_painter = project_hits(r"\bLightningPainter\b", limit=12)
    lightning_reset = project_hits(r"_lightningCtrl\.reset|reset.*lightning|lightning.*reset", limit=12)
    add_check(
        "Rendering",
        "Lightning bolt preserved and afterimage reset",
        "PASS" if lightning_painter and lightning_reset else "FAIL" if not lightning_painter else "WARN",
        "P0" if not lightning_painter else "P1",
        "LightningPainter and reset evidence were found." if lightning_painter and lightning_reset else "Lightning feature/reset evidence is incomplete.",
        lightning_painter + lightning_reset,
        "Preserve the bolt while resetting the completed animation.",
    )

    lifecycle = project_hits(r"WidgetsBindingObserver|didChangeAppLifecycleState|AppLifecycleState\.(paused|inactive|resumed)", limit=25)
    grace = project_hits(r"_resumeGraceDuration|resume.?grace|_resumeGraceUntil", limit=25)
    add_check(
        "Lifecycle",
        "Automatic lifecycle pause",
        "PASS" if lifecycle else "FAIL",
        "P0",
        "Lifecycle handling evidence was found." if lifecycle else "No lifecycle observer/handler was found.",
        lifecycle,
    )
    add_check(
        "Lifecycle",
        "Resume grace countdown",
        "PASS" if grace else "WARN",
        "P1",
        "Resume grace evidence was found." if grace else "No 2–3 second resume grace evidence was found.",
        grace,
    )

    screenshot = project_hits(r"DETECT_SCREEN_CAPTURE|ScreenCaptureCallback|screenshotObserver|screenshotSuppress", limit=25)
    add_check(
        "Lifecycle",
        "Screenshot exception handling",
        "PASS" if screenshot else "WARN",
        "P2",
        "Screenshot exception handling was found." if screenshot else "Screenshot exception handling was not found.",
        screenshot,
    )

    diagnostics = project_hits(r"DEVICE DIAG|refreshHz|systemAvail|systemTotal|lowMemory", limit=20)
    add_check(
        "Diagnostics",
        "Device diagnostics",
        "PASS" if diagnostics else "WARN",
        "P1",
        "Device/heap/memory diagnostics were found." if diagnostics else "Expected device diagnostics were not found.",
        diagnostics,
    )


def inspect_reward_integrity() -> None:
    game_path = ROOT / "lib/screens/game_screen.dart"
    game = read_text(game_path)
    run_path = ROOT / "lib/tj_engine/engine/run/run_lifecycle_manager.dart"
    run_text = read_text(run_path)
    overlay_path = ROOT / "lib/game/end/run_end_overlay.dart"
    overlay = read_text(overlay_path)

    submit_block = function_block(game, "void _maybeSubmitLeaderboard", max_lines=45)
    revive_block = function_block(game, "Future<void> _revive", max_lines=55)
    lifecycle_revive = function_block(run_text, "void revive()", max_lines=40)

    credits_summary = "creditRunCoins(summary)" in submit_block
    resets_submission = "_leaderboardSubmitted = false" in revive_block
    preserves_cumulative = all(token not in lifecycle_revive for token in ("_pops = 0", "_score = 0", "_bestStreak = 0"))
    explicit_once_guard = has_any(
        game + read_text(ROOT / "lib/tj_engine/engine/tj_engine.dart"),
        (
            r"rewardCredited", r"rewardSettled", r"settledRun", r"creditedRunIds?",
            r"creditRunCoinsOnce", r"creditIncrementalReward", r"lastCreditedPops",
        ),
    )
    duplicate_risk = credits_summary and resets_submission and preserves_cumulative and not explicit_once_guard
    add_check(
        "Reward Integrity",
        "Revive does not duplicate settled run rewards",
        "FAIL" if duplicate_risk else "PASS",
        "P0",
        "Revive resets submission while preserving cumulative run totals, so a later ending can credit the pre-revive run again." if duplicate_risk else "No obvious revive reward-duplication pattern was found.",
        file_hits(game_path, r"creditRunCoins|_leaderboardSubmitted = false|runLifecycle\.revive", limit=20)
        + file_hits(run_path, r"void revive|_pops|_score|_bestStreak|_latestSummary", limit=20),
        "Settle run currency exactly once per run or credit only the post-revive delta.",
    )

    passes_revive_unconditionally = bool(re.search(r"RunEndOverlay\([\s\S]{0,700}?onRevive:\s*_revive", game))
    overlay_shows_unconditionally = "if (widget.onRevive != null)" in overlay
    on_revive_lines = "\n".join(
        line for line in game.splitlines() if "onRevive:" in line
    )
    overlay_revive_conditions = "\n".join(
        line for line in overlay.splitlines()
        if "widget.onRevive" in line and "if" in line
    )
    victory_guard = (
        has_any(
            on_revive_lines,
            (
                r"(victory|_isVictory).*\?\s*null",
                r"\?\s*null\s*:\s*_revive",
            ),
        )
        or has_any(
            overlay_revive_conditions,
            (r"!_isVictory", r"reason\s*!=\s*RunEndReason\.victory"),
        )
        or has_any(
            revive_block,
            (
                r"latestSummary[\s\S]{0,180}?(victory|RunEndReason\.victory)[\s\S]{0,80}?return",
                r"if\s*\([^)]*(victory|_isVictory)[^)]*\)\s*return",
            ),
        )
    )
    victory_loop = passes_revive_unconditionally and overlay_shows_unconditionally and not victory_guard
    add_check(
        "Reward Integrity",
        "Victory cannot be revived into a repeatable reward loop",
        "FAIL" if victory_loop else "PASS",
        "P0",
        "Victory currently receives the same Revive action as ordinary failure, while revive preserves 500 pops." if victory_loop else "A victory-specific revive guard was found or Revive is not exposed on victory.",
        file_hits(game_path, r"EndReason\.victory|onRevive:|Future<void> _revive", limit=20)
        + file_hits(overlay_path, r"_isVictory|widget\.onRevive|REVIVE", limit=20),
        "Hide/disable Revive on victory and defensively reject victory revive in game logic.",
    )


def inspect_economy_and_player_contracts() -> None:
    engine_path = ROOT / "lib/tj_engine/engine/tj_engine.dart"
    engine = read_text(engine_path)
    economy_hits = file_hits(engine_path, r"base\s*=|popCoins|worldCoins|accuracyCoins|streakCoins|shieldCost", limit=25)
    add_check(
        "Economy",
        "Run economy tuning remains deferred",
        "WARN",
        "Later",
        "The current formula still awards one coin per pop; tune only after difficulty and run length stabilize.",
        economy_hits,
        "Revisit popCoins after Worlds 3–4 are fair and representative run lengths are known.",
    )

    start_path = ROOT / "lib/screens/start_screen.dart"
    start = read_text(start_path)
    hardcoded_world = len(re.findall(r"currentWorldLevel:\s*1", start)) >= 1
    add_check(
        "Daily Reward",
        "Daily reward uses real progression level",
        "WARN" if hardcoded_world else "PASS",
        "P1",
        "StartScreen hardcodes currentWorldLevel: 1, so world scaling never reflects progression." if hardcoded_world else "No hardcoded World 1 reward input was found.",
        file_hits(start_path, r"currentWorldLevel:\s*1", limit=10),
        "Use the highest unlocked/reached world or remove the world-scaling claim.",
    )

    bonus_displayed = "bonusPoints" in start
    bonus_consumers = [hit for hit in project_hits(r"bonusPoints", limit=40) if "daily_reward" not in hit.lower() and "start_screen.dart" not in hit]
    add_check(
        "Daily Reward",
        "Displayed bonus points are actually credited",
        "WARN" if bonus_displayed and not bonus_consumers else "PASS",
        "P1",
        "The UI advertises bonus points, but no independent consumer/credit path was found." if bonus_displayed and not bonus_consumers else "A bonus-point consumer was found or the UI no longer promises it.",
        file_hits(start_path, r"bonusPoints|Bonus", limit=12) + bonus_consumers,
        "Credit bonus points to a real system or remove them from the claim copy.",
    )

    run_path = ROOT / "lib/tj_engine/engine/run/run_lifecycle_manager.dart"
    run = read_text(run_path)
    escape_block = function_block(run, "if (event is EscapeEvent)", max_lines=32)
    absorbs_batch = bool(re.search(r"_shield\.isActive[\s\S]{0,250}?_shield\.consume\(\)[\s\S]{0,120}?return;", escape_block)) and "event.count - 1" not in escape_block
    add_check(
        "Player Contract",
        "Shield wording matches batch escape behavior",
        "WARN" if absorbs_batch else "PASS",
        "P2",
        "One shield can absorb an entire multi-balloon EscapeEvent even though the UI says first escape." if absorbs_batch else "Shield processing appears to account for only one escape or the wording has been adjusted.",
        file_hits(run_path, r"EscapeEvent|shield|event\.count|return;", limit=24),
        "Subtract one escape from the event or change the player-facing promise.",
    )


def inspect_leaderboard() -> None:
    path = ROOT / "lib/tj_engine/engine/leaderboard/leaderboard_manager.dart"
    text = read_text(path)
    if not text:
        add_check("Leaderboard", "Leaderboard manager available", "FAIL", "P1", f"Missing {relative(path)}.")
        return

    submit = function_block(text, "Future<int?> submit", max_lines=38)
    trim_before_index = submit.find("_sortAndTrim()") >= 0 and submit.find("_entries.indexOf(entry)") > submit.find("_sortAndTrim()")
    negative_guard = has_any(submit, (r"placement\s*<\s*0", r"placement\s*==\s*-1"))
    add_check(
        "Leaderboard",
        "Out-of-top-ten runs cannot display placement #0",
        "FAIL" if trim_before_index and not negative_guard else "PASS",
        "P1",
        "The list is trimmed before indexOf; a removed entry can produce placement -1 + 1 = #0." if trim_before_index and not negative_guard else "A negative placement guard or safe ordering was found.",
        file_hits(path, r"_sortAndTrim|indexOf|placement|return", limit=20),
        "Return null when placement is negative or determine placement before trimming.",
    )

    load = function_block(text, "Future<void> load", max_lines=35)
    has_decode = "jsonDecode" in load
    has_catch = "catch" in load
    add_check(
        "Leaderboard",
        "Corrupt saved leaderboard data is contained",
        "FAIL" if has_decode and not has_catch else "PASS",
        "P1",
        "Leaderboard load decodes persisted JSON without local recovery." if has_decode and not has_catch else "Leaderboard load has recovery or does not decode persisted JSON directly.",
        file_hits(path, r"Future<void> load|jsonDecode|catch|_entries = \[\]", limit=20),
        "Catch decode/model errors, clear or quarantine corrupt data, and let startup continue.",
    )


def inspect_release_pipeline() -> None:
    workflow_files = sorted((ROOT / ".github/workflows").glob("*.y*ml")) if (ROOT / ".github/workflows").exists() else []
    workflows = "\n".join(read_text(path) for path in workflow_files)
    workflow_evidence = []
    for path in workflow_files:
        workflow_evidence.extend(file_hits(path, r"flutter (build|analyze|test)|ENABLE_QA_AUTOTAP|upload-artifact", limit=30))

    release_autotap = bool(re.search(r"flutter build (apk|appbundle)[^\n]*--release[^\n]*ENABLE_QA_AUTOTAP=true", workflows, re.IGNORECASE))
    production_separation = has_any(workflows, (r"production", r"public release", r"store", r"ENABLE_QA_AUTOTAP=false"))
    add_check(
        "Release",
        "Public release build does not enable QA auto-tap",
        "FAIL" if release_autotap and not production_separation else "PASS",
        "P0",
        "The release APK is built with ENABLE_QA_AUTOTAP=true and no separate production path was found." if release_autotap and not production_separation else "A production-safe build path was found or release auto-tap is disabled.",
        workflow_evidence,
        "Keep an internal QA artifact if useful, but add a production artifact with auto-tap disabled and no accessible debug controls.",
    )

    debug_path = ROOT / "lib/screens/debug_screen.dart"
    game_path = ROOT / "lib/screens/game_screen.dart"
    debug_text = read_text(debug_path)
    game_text = read_text(game_path)
    debug_entry = "DebugScreen" in game_text or "onRequestDebug" in game_text
    auto_controls = has_any(debug_text, (r"auto.?tap", r"AutoTap"))
    long_press_block = function_block(game_text, "void _handleLongPress", max_lines=18)
    debug_screen_build = function_block(debug_text, "Widget build", max_lines=220)
    release_guard = has_any(
        long_press_block,
        (r"kDebugMode", r"kReleaseMode", r"ENABLE_QA_AUTOTAP", r"AutoTapController\.enabled"),
    ) or has_any(
        debug_screen_build,
        (r"kDebugMode", r"kReleaseMode", r"ENABLE_QA_AUTOTAP", r"AutoTapController\.enabled"),
    )
    add_check(
        "Release",
        "Debug/auto-tap UI is gated from public builds",
        "WARN" if debug_entry and auto_controls and not release_guard else "PASS",
        "P1",
        "DebugScreen and auto-tap controls appear reachable without a clear release guard." if debug_entry and auto_controls and not release_guard else "A release/debug gate was found or auto-tap UI is not reachable.",
        file_hits(game_path, r"DebugScreen|Icons\.bug|kDebugMode|kReleaseMode", limit=20)
        + file_hits(debug_path, r"AutoTap|auto.?tap|kDebugMode|kReleaseMode", limit=20),
        "Hide the debug entry point and auto-tap controls in public/store builds.",
    )

    gradle_path = ROOT / "android/app/build.gradle"
    gradle = read_text(gradle_path)
    debug_signing = bool(re.search(r"release\s*\{[\s\S]{0,300}?signingConfig\s+signingConfigs\.debug", gradle))
    add_check(
        "Release",
        "Release build is not signed with the debug key",
        "WARN" if debug_signing else "PASS",
        "P1",
        "The release build type currently uses debug signing." if debug_signing else "No debug signing was found in the release build type.",
        file_hits(gradle_path, r"buildTypes|release|signingConfig", limit=15),
        "Before Play distribution, use a protected upload/release keystore configuration.",
    )

    has_analyze = bool(re.search(r"flutter analyze", workflows))
    has_test = bool(re.search(r"flutter test", workflows))
    has_aab = bool(re.search(r"flutter build appbundle", workflows))
    for name, present, command, recommendation in (
        ("CI runs flutter analyze", has_analyze, "flutter analyze", "Add an analyzer step after restoring meaningful analyzer coverage."),
        ("CI runs flutter test", has_test, "flutter test", "Repair the stale test, then add flutter test to CI."),
        ("CI builds an Android App Bundle", has_aab, "flutter build appbundle", "Add an AAB artifact for the Play release path."),
    ):
        add_check(
            "Release",
            name,
            "PASS" if present else "WARN",
            "P1",
            f"{command} is present in CI." if present else f"{command} is not present in the active workflows.",
            workflow_evidence,
            recommendation,
        )


def inspect_quality_gates() -> None:
    test_path = ROOT / "test/widget_test.dart"
    test_text = read_text(test_path)
    stale = "const MyApp()" in test_text or "Counter increments smoke test" in test_text
    add_check(
        "Quality Gates",
        "Widget test matches the current application",
        "WARN" if stale else "PASS",
        "P1",
        "The default counter test still references MyApp and does not match Balloon Burst." if stale else "No default stale counter test marker was found.",
        file_hits(test_path, r"MyApp|Counter increments|pumpWidget|find\.text", limit=20),
        "Replace it with a real Balloon Burst smoke test before enabling flutter test in CI.",
    )

    options_path = ROOT / "analysis_options.yaml"
    options = read_text(options_path)
    exclusions = matching_lines(options, r"lib/|test/", limit=30)
    broad = any(token in options for token in ("lib/tj_engine/**", "lib/screens/**", "test/**"))
    add_check(
        "Quality Gates",
        "Analyzer covers core gameplay, engine, screens, and tests",
        "WARN" if broad else "PASS",
        "P1",
        "Core screens, engine code, or tests are broadly excluded from analysis." if broad else "No broad core-code analyzer exclusions were found.",
        [f"{relative(options_path)}:{line}" for line in exclusions],
        "Remove exclusions incrementally as existing issues are repaired; avoid a giant cleanup patch.",
    )


def inspect_structure() -> None:
    game_screen = ROOT / "lib/screens/game_screen.dart"
    line_count = len(read_text(game_screen).splitlines()) if game_screen.exists() else 0
    add_check(
        "Structure",
        "GameScreen file size",
        "LATER" if line_count > 1200 else "PASS",
        "Later",
        f"{relative(game_screen)} has {line_count} lines." if line_count else "GameScreen was not found.",
        recommendation="Modularize only when needed for safe focused changes; do not interrupt gameplay stabilization.",
    )

    duplicate_names: dict[str, list[str]] = {}
    for path in ROOT.rglob("*.dart"):
        if any(part in {"build", ".dart_tool"} for part in path.parts):
            continue
        duplicate_names.setdefault(path.name, []).append(relative(path))
    duplicates = [f"{name}: {', '.join(paths)}" for name, paths in duplicate_names.items() if len(paths) > 1]
    add_check(
        "Structure",
        "Duplicate Dart filenames",
        "INFO" if duplicates else "PASS",
        "Later",
        "Duplicate filenames exist and may represent legacy/parallel systems." if duplicates else "No duplicate Dart filenames were found.",
        duplicates[:30],
        "Treat as maintenance debt; do not broad-refactor before gameplay and release blockers are resolved.",
    )


def build_framework() -> dict[str, Any]:
    open_checks = [check for check in checks if check["status"] in OPEN_STATUSES]
    failures = [check for check in checks if check["status"] == "FAIL"]
    passes = [check for check in checks if check["status"] == "PASS"]
    status_counts = Counter(check["status"] for check in checks)
    open_priority_counts = Counter(check["priority"] for check in open_checks)

    what_works = [f'{check["name"]}: {check["detail"]}' for check in passes]
    concerns = [f'[{check["priority"]}] {check["name"]}: {check["detail"]}' for check in open_checks]
    recommendations = [
        f'[{check["priority"]}] {check["name"]}: {check["recommendation"]}'
        for check in open_checks if check["recommendation"]
    ]

    questions = [
        "At what point does World 3 stop feeling fair?",
        "Is World 4 intense and dangerous, or physically untappable?",
        "Are deaths caused by missed taps, escapes, unreadable overlap, or impossible clusters?",
        "Does every successful tap feel immediate?",
        "Can the player understand why the run ended?",
        "Does failure create one-more-try energy?",
        "Are rewards meaningful, or are they becoming noise or an exploit?",
        "Does normal no-YouTube gameplay remain stable on low-end Android?",
        "Would SlimNation immediately catch an obvious flaw?",
        "Are we calling this good because it is genuinely good, or because we are tired?",
    ]

    p0_failures = [check for check in failures if check["priority"] == "P0"]
    if p0_failures:
        good_enough = "No for public release. One or more P0 failures remain open."
        verdict = "SLIMNATION VERDICT: HOLD PUBLIC RELEASE. Use only as an internal QA build while P0 findings remain."
    elif failures:
        good_enough = "Not yet release-ready. Confirmed failures remain, though no P0 failure is open."
        verdict = "SLIMNATION VERDICT: HOLD RELEASE. Continue focused one-commit fixes and rerun Audit V2."
    else:
        good_enough = "Code-level blockers detected by this audit are clear; human gameplay and CI evidence are still required."
        verdict = "SLIMNATION VERDICT: STATIC AUDIT CLEAR. Proceed to human gameplay and build verification."

    return {
        "what_works": what_works,
        "what_may_confuse_frustrate_or_disappoint": concerns,
        "the_slimnation_test": (
            "Audit V2 catches known structural regressions and release risks, but it cannot prove fun, fairness, tactile responsiveness, or real-device stability."
        ),
        "questions_i_should_ask_myself": questions,
        "recommended_changes": recommendations,
        "status_counts": dict(status_counts),
        "open_priority_counts": {
            priority: open_priority_counts.get(priority, 0)
            for priority in ("P0", "P1", "P2", "Later")
        },
        "open_findings": len(open_checks),
        "failed_checks": len(failures),
        "good_enough": good_enough,
        "slimnation_verdict": verdict,
    }


def selected_source_files() -> set[Path]:
    selected = {
        ROOT / "lib/game/balloon_spawner.dart",
        ROOT / "lib/audio/audio_player.dart",
        ROOT / "lib/screens/game_screen.dart",
        ROOT / "lib/screens/debug_screen.dart",
        ROOT / "lib/game/end/run_end_overlay.dart",
        ROOT / "lib/tj_engine/engine/tj_engine.dart",
        ROOT / "lib/tj_engine/engine/run/run_lifecycle_manager.dart",
        ROOT / "lib/tj_engine/engine/leaderboard/leaderboard_manager.dart",
        ROOT / "lib/tj_engine/engine/daily/daily_reward_manager.dart",
        ROOT / "lib/screens/start_screen.dart",
        ROOT / "android/app/build.gradle",
        ROOT / "analysis_options.yaml",
        ROOT / "test/widget_test.dart",
        ROOT / "pubspec.yaml",
        Path(__file__).resolve(),
    }
    workflows = ROOT / ".github/workflows"
    if workflows.exists():
        selected.update(path for path in workflows.glob("*.y*ml") if path.is_file())
    for path in ROOT.rglob("*.dart"):
        if any(token in path.name.lower() for token in ("lightning", "surge", "auto_tap")):
            selected.add(path)
    return {path for path in selected if path.exists() and path.is_file()}


def write_reports() -> dict[str, Any]:
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    checks.clear()

    inspect_repository()
    inspect_gameplay_tuning()
    inspect_audio()
    inspect_rendering_lifecycle()
    inspect_reward_integrity()
    inspect_economy_and_player_contracts()
    inspect_leaderboard()
    inspect_release_pipeline()
    inspect_quality_gates()
    inspect_structure()

    framework = build_framework()
    now = dt.datetime.now(dt.timezone.utc).isoformat()
    branch = git("branch", "--show-current")
    head = git("rev-parse", "--short", "HEAD")
    status = git("status", "--short")
    recent_log = git("--no-pager", "log", "--oneline", "--decorate", "-15")
    diff = git("--no-pager", "diff", "--", ".")
    staged_diff = git("--no-pager", "diff", "--cached", "--", ".")

    sources = sorted(selected_source_files(), key=lambda path: relative(path))
    hashes = {relative(path): sha256(path) for path in sources}

    payload = {
        "audit_version": AUDIT_VERSION,
        "generated_at_utc": now,
        "repository": str(ROOT),
        "git_branch": branch,
        "git_head": head,
        "git_status": status,
        "checks": checks,
        "framework": framework,
        "source_sha256": hashes,
    }
    JSON_REPORT.write_text(json.dumps(payload, indent=2), encoding="utf-8")

    lines: list[str] = [
        f"BALLOON BURST — SLIMNATION AUDIT V{AUDIT_VERSION}",
        "=" * 72,
        f"Generated UTC: {now}",
        f"Repository: {ROOT}",
        f"Branch: {branch}",
        f"Commit: {head}",
        f"Git status: {status or 'clean'}",
        f"Open findings: {framework['open_findings']}",
        f"Failed checks: {framework['failed_checks']}",
        "",
        "IMPORTANT",
        "-" * 72,
        "This static audit does not replace real gameplay testing or GitHub Actions.",
        "",
        "OPEN FAILURES AND WARNINGS",
        "=" * 72,
    ]

    open_checks = [check for check in checks if check["status"] in OPEN_STATUSES]
    if not open_checks:
        lines.append("None.")
    for check in open_checks:
        lines.extend([
            "",
            f"[{check['status']}] [{check['priority']}] {check['section']} — {check['name']}",
            check["detail"],
        ])
        if check["recommendation"]:
            lines.append(f"Recommended: {check['recommendation']}")
        if check["evidence"]:
            lines.append("Evidence:")
            lines.extend(f"  - {item}" for item in check["evidence"])

    lines.extend(["", "PASSED / INFORMATIONAL CHECKS", "=" * 72])
    for check in checks:
        if check["status"] in OPEN_STATUSES:
            continue
        lines.extend([
            "",
            f"[{check['status']}] [{check['priority']}] {check['section']} — {check['name']}",
            check["detail"],
        ])
        if check["evidence"]:
            lines.append("Evidence:")
            lines.extend(f"  - {item}" for item in check["evidence"])

    headings = (
        ("WHAT WORKS", "what_works"),
        ("WHAT MAY CONFUSE, FRUSTRATE, OR DISAPPOINT USERS", "what_may_confuse_frustrate_or_disappoint"),
        ("THE SLIMNATION TEST", "the_slimnation_test"),
        ("QUESTIONS I SHOULD ASK MYSELF", "questions_i_should_ask_myself"),
        ("RECOMMENDED CHANGES", "recommended_changes"),
        ("OPEN PRIORITY COUNTS", "open_priority_counts"),
        ("GOOD ENOUGH?", "good_enough"),
        ("SLIMNATION VERDICT", "slimnation_verdict"),
    )
    for heading, key in headings:
        lines.extend(["", heading, "=" * 72])
        value = framework[key]
        if isinstance(value, list):
            lines.extend(f"- {item}" for item in value) if value else lines.append("- None.")
        elif isinstance(value, dict):
            lines.extend(f"- {name}: {count}" for name, count in value.items())
        else:
            lines.append(str(value))

    TXT_REPORT.write_text("\n".join(lines) + "\n", encoding="utf-8")

    manifest = "\n".join([
        f"Balloon Burst SlimNation Audit V{AUDIT_VERSION}",
        f"Generated UTC: {now}",
        f"Branch: {branch}",
        f"Commit: {head}",
        f"Open findings: {framework['open_findings']}",
        f"Failed checks: {framework['failed_checks']}",
        "",
        "This bundle is an automated review aid, not proof of gameplay fairness.",
    ])
    hashes_text = "\n".join(f"{digest}  {name}" for name, digest in hashes.items()) + "\n"
    with zipfile.ZipFile(ZIP_REPORT, "w", compression=zipfile.ZIP_DEFLATED) as archive:
        archive.write(TXT_REPORT, TXT_REPORT.name)
        archive.write(JSON_REPORT, JSON_REPORT.name)
        archive.writestr("audit_manifest.txt", manifest)
        archive.writestr("evidence/git_status.txt", status + "\n")
        archive.writestr("evidence/git_recent_log.txt", recent_log + "\n")
        archive.writestr("evidence/git_diff.txt", diff + "\n")
        archive.writestr("evidence/git_staged_diff.txt", staged_diff + "\n")
        archive.writestr("evidence/source_sha256.txt", hashes_text)
        for path in sources:
            archive.write(path, f"sources/{relative(path)}")

    print(f"SlimNation Audit v{AUDIT_VERSION} complete.")
    print(f"Open findings: {framework['open_findings']}")
    print(f"Failed checks: {framework['failed_checks']}")
    print(f"Text report: {relative(TXT_REPORT)}")
    print(f"JSON report: {relative(JSON_REPORT)}")
    print(f"ZIP bundle:  {relative(ZIP_REPORT)}")
    return payload


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--strict",
        action="store_true",
        help="Exit 1 when an open FAIL exists after reports are written.",
    )
    return parser.parse_args()


def main() -> int:
    args = parse_args()
    try:
        payload = write_reports()
    except KeyboardInterrupt:
        print("Audit cancelled.", file=sys.stderr)
        return 130
    except Exception as exc:
        print(f"Audit failed: {exc}", file=sys.stderr)
        return 2
    if args.strict and payload["framework"]["failed_checks"] > 0:
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
