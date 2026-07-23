#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from reference_pipeline.common import load_json, sha256_file, write_json
from reference_pipeline.encounters import (
    EncounterGuideError,
    encounter_source_facts,
    extend_snapshot_with_encounters,
)
from reference_pipeline.snapshot import validate_snapshot, write_validation_reports

ROOT = Path(__file__).resolve().parents[1]
PROGRESSION = ROOT / "tool" / "reference_pipeline" / "lets_go_progression.json"


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(
        description="Extend one immutable source snapshot with pinned encounter CSVs."
    )
    value.add_argument("--snapshot-id", required=True)
    value.add_argument(
        "--base-snapshot",
        type=Path,
        default=(
            ROOT
            / "third_party"
            / "source_snapshots"
            / "2026-07-23-pokeapi-r1"
        ),
    )
    value.add_argument(
        "--output-root",
        type=Path,
        default=ROOT / "third_party" / "source_snapshots",
    )
    value.add_argument(
        "--write-lock",
        type=Path,
        default=ROOT / "third_party" / "source_snapshot.lock.json",
    )
    return value


def _write_lock(snapshot: Path, destination: Path) -> None:
    metadata = load_json(snapshot / "snapshot.json")
    write_json(
        destination,
        {
            "snapshotId": metadata["snapshotId"],
            "snapshotFormatVersion": metadata["snapshotFormatVersion"],
            "snapshotMetadataSha256": sha256_file(snapshot / "snapshot.json"),
            "relativeSnapshotPath": snapshot.relative_to(ROOT).as_posix(),
            "createdAtUtc": metadata["createdAtUtc"],
            "sourceAcquiredAtUtc": metadata["sourceAcquiredAtUtc"],
            "acquisitionToolVersion": metadata["acquisitionToolVersion"],
            "sources": metadata["sources"],
            "languages": metadata["languages"],
            "knownOmissions": metadata["knownOmissions"],
            "manualCorrections": metadata["manualCorrections"],
            "licenses": metadata["licenses"],
            "expectedCounts": metadata["expectedCounts"],
            "highestNationalDexNumber": metadata["catalog"][
                "highestNationalDexNumber"
            ],
            "parentSnapshotId": metadata["parentSnapshotId"],
            "encounterGuideSource": metadata["encounterGuideSource"],
            "storagePolicy": (
                "Snapshot directory is ignored by Git and must be archived "
                "to the private homelab plus a second backup."
            ),
        },
    )


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    try:
        result = extend_snapshot_with_encounters(
            base_snapshot=args.base_snapshot,
            output_root=args.output_root,
            snapshot_id=args.snapshot_id,
            third_party_notices=ROOT / "THIRD_PARTY_NOTICES.md",
        )
        metadata = load_json(result / "snapshot.json")
        facts = encounter_source_facts(result, metadata, PROGRESSION)
        report = validate_snapshot(result)
        report.facts["encounterGuide"] = facts
        write_validation_reports(
            report,
            ROOT
            / "build"
            / "reference-data"
            / "snapshot-reports"
            / args.snapshot_id,
        )
        if not report.valid:
            raise EncounterGuideError(
                f"Extended snapshot failed with {len(report.errors)} errors."
            )
        _write_lock(result, args.write_lock)
        print(json.dumps(report.to_dict(), indent=2, ensure_ascii=False))
        print(f"Finalized immutable snapshot: {result}")
        return 0
    except (EncounterGuideError, OSError, ValueError, KeyError) as error:
        print(f"Encounter snapshot acquisition failed: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
