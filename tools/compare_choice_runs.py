#!/usr/bin/env python3
"""Isolated, bounded runs of the unchanged playthrough bot and paired reports."""
import argparse
import concurrent.futures
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess
import sys
import time

HARNESS = Path("tests/godot/playthrough_probe.gd")
STRATEGIES = ("human_legion", "human_elite", "elf_cycle", "elf_ambush",
              "undead_sacrifice", "undead_blood")


def write_json(path, value):
    path.write_text(json.dumps(value, sort_keys=True, indent=2) + "\n")


def source_hash(project):
    digest = hashlib.sha256()
    paths = [project / "project.godot"]
    for folder in ("src", "data", "assets"):
        paths.extend(p for p in (project / folder).rglob("*")
                     if p.is_file() and p.suffix not in (".uid", ".import"))
    for path in sorted(paths):
        digest.update(str(path.relative_to(project)).encode())
        digest.update(path.read_bytes())
    return digest.hexdigest()


def summarize(cases, battles):
    return {
        "runs": len(cases), "wins": sum(c["result"] == "win" for c in cases),
        "losses": sum(c["result"] == "loss" for c in cases),
        "stalls": sum(c["stalled"] for c in cases),
        "duplicate_settlement_passes": sum(c["duplicate_settlement_ok"] for c in cases),
        "battles": len(battles),
        "first_turn_wins": sum(b["first_turn_win"] for b in battles),
        "finishers": sum(b["finisher"] for b in battles),
        "mean_turns": round(sum(b["turns"] for b in battles) / len(battles), 6) if battles else None,
        "max_actions": max((b["actions"] for b in battles), default=0),
    }


def run(args):
    project = args.project.resolve()
    output = args.output.resolve()
    previous = None
    if args.resume:
        previous = json.loads((output / "report.json").read_text())
    else:
        output.mkdir(parents=True, exist_ok=False)
    harness = Path(__file__).resolve().parents[1] / HARNESS
    target = project / HARNESS
    digest = hashlib.sha256(harness.read_bytes()).hexdigest()
    before = source_hash(project)
    if previous:
        expected = {"harness_sha256": digest, "source_sha256": before,
                    "seed_start": args.seed_start, "seed_count": args.seed_count,
                    "source_unchanged": True}
        for field, value in expected.items():
            if previous[field] != value:
                raise ValueError(f"Cannot resume changed benchmark: {field}")
        if hashlib.sha256(target.read_bytes()).hexdigest() != digest:
            raise ValueError("Cannot resume changed project harness")
    elif harness != target:
        shutil.copy2(harness, target)
    env = dict(os.environ, CARD_DRAFT_TEST_DATA_DIR=str(output / "import-storage"))
    # GameStorage routes profile/run writes explicitly; XDG also separates Linux caches.
    env["XDG_DATA_HOME"] = str(output / "xdg")
    base = [args.godot, "--headless", "--path", str(project)]
    if not args.resume:
        with (output / "import.log").open("w") as log:
            imported = subprocess.run(base + ["--editor", "--import"], env=env,
                                      stdout=log, stderr=subprocess.STDOUT, timeout=180)
        if imported.returncode:
            raise RuntimeError("Headless import failed; see import.log")

    def worker(strategy):
        directory = output / strategy
        directory.mkdir(exist_ok=args.resume)
        command = base + ["--script", str(HARNESS), "--",
                          f"--test-data-dir={directory}", f"--strategy={strategy}",
                          f"--seed-count={args.seed_count}", f"--seed-start={args.seed_start}"]
        print(f"START {strategy}", flush=True)
        with (directory / "engine.log").open("a" if args.resume else "w") as log:
            process = subprocess.Popen(command, env=env, stdout=log, stderr=subprocess.STDOUT)
            deadline = time.monotonic() + args.timeout
            code = None
            try:
                while process.poll() is None:
                    content = (directory / "engine.log").read_text()
                    if "SCRIPT ERROR:" in content or "\nERROR:" in content:
                        code = 2
                        break
                    if time.monotonic() >= deadline:
                        code = 124
                        break
                    time.sleep(0.5)
            finally:
                if process.poll() is None:
                    process.terminate()
                    try:
                        process.wait(timeout=5)
                    except subprocess.TimeoutExpired:
                        process.kill()
                process.wait()
            if code is None:
                code = process.returncode
        errors = [line for line in (directory / "engine.log").read_text().splitlines()
                  if "SCRIPT ERROR:" in line or line.startswith("ERROR:")]
        report_path = directory / "playthrough_metrics.json"
        if not report_path.exists():
            report_path = directory / "progress.json"
        report = json.loads(report_path.read_text()) if report_path.exists() else {}
        print(f"DONE {strategy} exit={code} cases={len(report.get('cases', []))}", flush=True)
        return strategy, code, errors, report

    with concurrent.futures.ThreadPoolExecutor(max_workers=args.jobs) as pool:
        results = list(pool.map(worker, STRATEGIES))
    cases, battles, executions = [], [], []
    for strategy, code, errors, report in results:
        cases.extend(report.get("cases", []))
        battles.extend(report.get("battles", []))
        executions.append({"strategy": strategy, "exit_code": code, "errors": errors,
                           "probe_failed": report.get("failed", True)})
    key = lambda row: (row["strategy_id"], row["seed"], row["elite"])
    cases.sort(key=key)
    battles.sort(key=lambda row: (*key(row), row["battle_index"]))
    expected = {(strategy, seed, elite) for strategy in STRATEGIES
                for seed in range(args.seed_start, args.seed_start + args.seed_count)
                for elite in (False, True)}
    complete = len(cases) == len(expected) and {key(c) for c in cases} == expected
    after = source_hash(project)
    passed = (complete and before == after and all(not c["stalled"] and c["duplicate_settlement_ok"] for c in cases)
              and all(e["exit_code"] == 0 and not e["errors"] and not e["probe_failed"] for e in executions))
    report = {"schema": 1, "seed_start": args.seed_start, "seed_count": args.seed_count,
              "harness_sha256": digest, "source_sha256": before, "source_unchanged": before == after,
              "matrix_complete": complete, "passed": passed, "executions": executions,
              "previous_executions": (previous.get("previous_executions", []) + previous["executions"]) if previous else [],
              "summary": summarize(cases, battles), "cases": cases, "battles": battles,
              "groups": {f"{s}/{'elite' if e else 'normal'}": summarize(
                  [c for c in cases if c["strategy_id"] == s and c["elite"] == e],
                  [b for b in battles if b["strategy_id"] == s and b["elite"] == e])
                  for s in STRATEGIES for e in (False, True)}}
    write_json(output / "report.json", report)
    print(json.dumps({"passed": passed, **report["summary"]}, sort_keys=True), flush=True)
    return 0 if passed else 1


def compare(args):
    baseline = json.loads(args.baseline.read_text())
    current = json.loads(args.current.read_text())
    for field in ("harness_sha256", "seed_start", "seed_count", "matrix_complete"):
        if baseline[field] != current[field]:
            raise ValueError(f"Incompatible comparison: {field}")
    if not baseline["matrix_complete"]:
        raise ValueError("Incomplete matrix")
    key = lambda c: (c["strategy_id"], c["seed"], c["elite"])
    old = {key(c): c for c in baseline["cases"]}
    new = {key(c): c for c in current["cases"]}
    if old.keys() != new.keys():
        raise ValueError("Case keys differ")
    report = {"baseline": baseline["summary"], "current": current["summary"],
              "baseline_passed": baseline["passed"], "current_passed": current["passed"],
              "outcome_changes": [{"strategy": k[0], "seed": k[1], "elite": k[2],
                                   "baseline": old[k]["result"], "current": new[k]["result"]}
                                  for k in sorted(old) if old[k]["result"] != new[k]["result"]],
              "groups": {k: {"baseline": baseline["groups"][k], "current": current["groups"][k]}
                         for k in sorted(baseline["groups"])}}
    write_json(args.output, report)
    print(json.dumps(report, sort_keys=True, indent=2))
    return 0 if baseline["passed"] and current["passed"] else 1


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    commands = parser.add_subparsers(dest="command", required=True)
    runner = commands.add_parser("run")
    runner.add_argument("--project", type=Path, required=True)
    runner.add_argument("--output", type=Path, required=True, help="Fresh directory; existing output is never overwritten")
    runner.add_argument("--godot", default=shutil.which("godot") or "godot")
    runner.add_argument("--seed-count", type=int, default=20)
    runner.add_argument("--seed-start", type=int, default=20261004)
    runner.add_argument("--jobs", type=int, default=2)
    runner.add_argument("--timeout", type=int, default=1800, help="Hard per-strategy timeout in seconds")
    runner.add_argument("--resume", action="store_true", help="Resume a stopped batch with matching source/harness/configuration")
    comparer = commands.add_parser("compare")
    comparer.add_argument("--baseline", type=Path, required=True)
    comparer.add_argument("--current", type=Path, required=True)
    comparer.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    if args.command == "run" and (args.seed_count < 1 or args.jobs < 1 or args.timeout < 1):
        parser.error("seed-count, jobs, and timeout must be positive")
    return run(args) if args.command == "run" else compare(args)


if __name__ == "__main__":
    sys.exit(main())
