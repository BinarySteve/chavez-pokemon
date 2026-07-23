#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from reference_pipeline.common import load_json, sha256_file
from reference_pipeline.encounters import (
    EncounterGuideError,
    validate_encounter_guide,
    write_encounter_guide,
)
from reference_pipeline.generation import (
    GenerationError,
    OfflineNetworkGuard,
    build_reference_data,
    validate_generated_output,
)
from reference_pipeline.snapshot import (
    SnapshotValidationError,
    validate_snapshot,
    write_validation_reports,
)

ROOT = Path(__file__).resolve().parents[1]
LOCK = ROOT / "third_party" / "source_snapshot.lock.json"


def _locked_snapshot() -> Path:
    if not LOCK.is_file():
        raise GenerationError(
            f"Snapshot lock is missing: {LOCK}. Pass --snapshot explicitly."
        )
    lock = load_json(LOCK)
    snapshot = ROOT / lock["relativeSnapshotPath"]
    metadata = snapshot / "snapshot.json"
    if not metadata.is_file():
        raise GenerationError(
            f"Locked snapshot metadata is missing: {metadata}. "
            "Restore the immutable snapshot from backup."
        )
    actual_hash = sha256_file(metadata)
    expected_hash = lock.get("snapshotMetadataSha256")
    if actual_hash != expected_hash:
        raise GenerationError(
            "Locked snapshot metadata checksum mismatch: "
            f"expected {expected_hash}; found {actual_hash}."
        )
    return snapshot


def _snapshot_arg(value: str | None) -> Path:
    return Path(value).resolve() if value else _locked_snapshot().resolve()


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(
        description="Validate snapshots and build Pokémon reference data offline."
    )
    commands = value.add_subparsers(dest="command", required=True)

    validate = commands.add_parser("validate-snapshot")
    validate.add_argument("--snapshot")
    validate.add_argument("--warnings-as-errors", action="store_true")

    build = commands.add_parser("build")
    build.add_argument("--snapshot")
    build.add_argument("--output", type=Path)
    build.add_argument("--dataset-version", type=int, default=4)
    build.add_argument("--content-schema", type=int, default=1)
    build.add_argument(
        "--display-name",
        default="National Pokédex Family Companion",
    )
    build.add_argument("--production-approved", action="store_true")
    build.add_argument("--replace-output", action="store_true")
    build.add_argument("--allow-snapshot-warnings", action="store_true")
    build.add_argument(
        "--compare-to",
        type=Path,
        default=ROOT / "assets" / "content" / "demo_reference.sqlite",
    )

    generated = commands.add_parser("validate-output")
    generated.add_argument("--output", type=Path, required=True)

    guide = commands.add_parser("build-guide")
    guide.add_argument("--snapshot")
    guide.add_argument("--output", type=Path)

    validate_guide = commands.add_parser("validate-guide")
    validate_guide.add_argument("--guide", type=Path, required=True)

    report = commands.add_parser("report-snapshot")
    report.add_argument("--snapshot")
    return value


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        if args.command == "validate-guide":
            facts = validate_encounter_guide(load_json(args.guide))
            print(json.dumps(facts, indent=2, ensure_ascii=False))
            return 0

        if args.command in {"validate-snapshot", "report-snapshot"}:
            snapshot = _snapshot_arg(args.snapshot)
            report = validate_snapshot(snapshot)
            write_validation_reports(
                report,
                ROOT
                / "build"
                / "reference-data"
                / "snapshot-reports"
                / snapshot.name,
            )
            print(json.dumps(report.to_dict(), indent=2, ensure_ascii=False))
            if args.command == "report-snapshot":
                print(report.to_markdown())
            if not report.valid:
                return 1
            if (
                args.command == "validate-snapshot"
                and args.warnings_as_errors
                and report.warnings
            ):
                return 2
            return 0

        if args.command == "validate-output":
            report = validate_generated_output(args.output)
            print(json.dumps(report.to_dict(), indent=2, ensure_ascii=False))
            return 0 if report.valid else 1

        snapshot = _snapshot_arg(args.snapshot)
        metadata = load_json(snapshot / "snapshot.json")
        if args.command == "build-guide":
            output = args.output or (
                ROOT
                / "build"
                / "reference-data"
                / metadata["snapshotId"]
                / "lets_go_encounters.json"
            )
            with OfflineNetworkGuard():
                facts = write_encounter_guide(
                    snapshot=snapshot,
                    progression_path=(
                        ROOT
                        / "tool"
                        / "reference_pipeline"
                        / "lets_go_progression.json"
                    ),
                    output=output,
                )
            print(json.dumps(facts, indent=2, ensure_ascii=False))
            print(f"Generated deterministic encounter guide: {output}")
            return 0

        output = args.output or (
            ROOT / "build" / "reference-data" / metadata["snapshotId"]
        )
        result, report, comparison = build_reference_data(
            root=ROOT,
            snapshot=snapshot,
            output=output,
            dataset_version=args.dataset_version,
            content_schema=args.content_schema,
            display_name=args.display_name,
            production_approved=args.production_approved,
            replace_output=args.replace_output,
            allow_snapshot_warnings=args.allow_snapshot_warnings,
            compare_to=args.compare_to,
        )
        print(json.dumps(report.to_dict(), indent=2, ensure_ascii=False))
        if comparison is not None:
            print(
                "Dataset comparison: "
                + (
                    "logically equivalent"
                    if comparison["logicallyEquivalent"]
                    else f"changed tables {comparison['changedTables']}"
                )
            )
        print(f"Generated validated candidate: {result}")
        return 0
    except (
        EncounterGuideError,
        GenerationError,
        SnapshotValidationError,
        OSError,
        ValueError,
        KeyError,
    ) as error:
        print(f"Reference-data command failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
