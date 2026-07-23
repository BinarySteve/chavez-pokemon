#!/usr/bin/env python3
from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from reference_pipeline.acquisition import AcquisitionError, acquire_snapshot
from reference_pipeline.common import sha256_file, write_json
from reference_pipeline.snapshot import write_validation_reports

ROOT = Path(__file__).resolve().parents[1]


def parser() -> argparse.ArgumentParser:
    value = argparse.ArgumentParser(
        description="Acquire and seal one immutable Pokémon source snapshot."
    )
    value.add_argument("--snapshot-id", required=True)
    value.add_argument(
        "--output-root",
        type=Path,
        default=ROOT / "third_party" / "source_snapshots",
    )
    value.add_argument(
        "--cache-dir",
        type=Path,
        default=ROOT / "third_party" / "pokeapi-cache",
    )
    value.add_argument(
        "--artwork-cache-dir",
        type=Path,
        default=ROOT / "third_party" / "pokeapi-artwork-cache",
    )
    value.add_argument(
        "--cache-only",
        action="store_true",
        help="Seal only from existing caches and application artwork; never use HTTP.",
    )
    value.add_argument(
        "--refresh",
        action="store_true",
        help="Refresh all records and artwork from upstream.",
    )
    value.add_argument("--workers", type=int, default=20)
    value.add_argument(
        "--source-acquired-at-utc",
        help="Known source acquisition time for a legacy cache being sealed.",
    )
    value.add_argument(
        "--accept-warnings",
        action="store_true",
        help="Finalize after explicitly reviewing validation warnings.",
    )
    value.add_argument(
        "--write-lock",
        type=Path,
        help="Write a small repository lock record after finalization.",
    )
    return value


def main(argv: list[str] | None = None) -> int:
    args = parser().parse_args(argv)
    if args.cache_only and args.refresh:
        parser().error("--cache-only and --refresh cannot be combined")
    try:
        result = acquire_snapshot(
            snapshot_id=args.snapshot_id,
            output_root=args.output_root,
            cache_dir=args.cache_dir,
            artwork_cache_dir=args.artwork_cache_dir,
            existing_base_artwork=ROOT / "assets" / "artwork",
            existing_form_artwork=ROOT / "assets" / "form_artwork",
            third_party_notices=ROOT / "THIRD_PARTY_NOTICES.md",
            cache_only=args.cache_only,
            refresh=args.refresh,
            workers=args.workers,
            source_acquired_at_utc=args.source_acquired_at_utc,
            accept_warnings=args.accept_warnings,
        )
    except (AcquisitionError, OSError, ValueError) as error:
        print(f"Acquisition failed: {error}", file=sys.stderr)
        return 1

    if args.write_lock:
        metadata_path = result.path / "snapshot.json"
        try:
            locked_path = result.path.relative_to(ROOT).as_posix()
        except ValueError:
            locked_path = str(result.path)
        write_json(
            args.write_lock,
            {
                "snapshotId": result.metadata["snapshotId"],
                "snapshotFormatVersion": result.metadata["snapshotFormatVersion"],
                "snapshotMetadataSha256": sha256_file(metadata_path),
                "relativeSnapshotPath": locked_path,
                "createdAtUtc": result.metadata["createdAtUtc"],
                "sourceAcquiredAtUtc": result.metadata["sourceAcquiredAtUtc"],
                "acquisitionToolVersion": result.metadata[
                    "acquisitionToolVersion"
                ],
                "sources": result.metadata["sources"],
                "languages": result.metadata["languages"],
                "knownOmissions": result.metadata["knownOmissions"],
                "manualCorrections": result.metadata["manualCorrections"],
                "licenses": result.metadata["licenses"],
                "expectedCounts": result.metadata["expectedCounts"],
                "highestNationalDexNumber": result.metadata["catalog"][
                    "highestNationalDexNumber"
                ],
                "storagePolicy": (
                    "Snapshot directory is ignored by Git and must be archived "
                    "to the private homelab plus a second backup."
                ),
            },
        )
    write_validation_reports(
        result.report,
        ROOT
        / "build"
        / "reference-data"
        / "snapshot-reports"
        / result.metadata["snapshotId"],
    )
    print(json.dumps(result.report.to_dict(), indent=2, ensure_ascii=False))
    print(f"Finalized immutable snapshot: {result.path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
