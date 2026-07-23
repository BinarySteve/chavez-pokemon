from __future__ import annotations

import base64
import json
import shutil
import sqlite3
import sys
import tempfile
import unittest
from pathlib import Path
from unittest import mock

TOOL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_ROOT))

from reference_pipeline import (  # noqa: E402
    ACQUISITION_TOOL_VERSION,
    GENERATOR_VERSION,
    SNAPSHOT_FORMAT_VERSION,
)
from reference_pipeline.acquisition import (  # noqa: E402
    AcquisitionError,
    CachedFetcher,
    acquire_snapshot,
)
from reference_pipeline.common import (  # noqa: E402
    condition,
    form_category,
    selected_move_detail,
    sha256_file,
    walk_chain,
    write_json,
)
from reference_pipeline.generation import (  # noqa: E402
    OfflineNetworkGuard,
    build_reference_data,
    logical_database_fingerprint,
    validate_generated_output,
)
from reference_pipeline.snapshot import (  # noqa: E402
    SnapshotValidationError,
    validate_snapshot,
)

API = "https://pokeapi.co/api/v2"
PNG = base64.b64decode(
    "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk"
    "/x8AAusB9Wl2nAAAAABJRU5ErkJggg=="
)


def _url(kind: str, identifier: int) -> str:
    return f"{API}/{kind}/{identifier}/"


def _stats(seed: int) -> list[dict[str, object]]:
    return [
        {"base_stat": seed + index, "stat": {"name": name}}
        for index, name in enumerate(
            (
                "hp",
                "attack",
                "defense",
                "special-attack",
                "special-defense",
                "speed",
            )
        )
    ]


def _move_item() -> dict[str, object]:
    return {
        "move": {"name": "tackle", "url": _url("move", 33)},
        "version_group_details": [
            {
                "level_learned_at": 1,
                "move_learn_method": {"name": "level-up"},
                "version_group": {
                    "name": "lets-go-pikachu-lets-go-eevee"
                },
            }
        ],
    }


def _pokemon(
    identifier: int,
    name: str,
    species_id: int,
    *,
    is_form: bool = False,
) -> dict[str, object]:
    return {
        "id": identifier,
        "name": name,
        "species": {
            "name": ("venusaur" if species_id == 3 else name),
            "url": _url("pokemon-species", species_id),
        },
        "height": 7 + species_id,
        "weight": 60 + species_id,
        "types": [
            {
                "slot": 1,
                "type": {"name": "grass", "url": _url("type", 12)},
            },
            {
                "slot": 2,
                "type": {"name": "poison", "url": _url("type", 4)},
            },
        ],
        "abilities": [
            {
                "slot": 1,
                "is_hidden": False,
                "ability": {
                    "name": "overgrow",
                    "url": _url("ability", 65),
                },
            }
        ],
        "stats": _stats(40 + species_id),
        "moves": [] if is_form else [_move_item()],
        "sprites": {
            "front_default": f"https://example.invalid/{name}.png",
            "other": {
                "official-artwork": {
                    "front_default": f"https://example.invalid/{name}.png"
                },
                "home": {"front_default": None},
            },
        },
    }


def _species(
    identifier: int,
    name: str,
    *,
    include_form: bool = False,
) -> dict[str, object]:
    varieties = [
        {
            "is_default": True,
            "pokemon": {"name": name, "url": _url("pokemon", identifier)},
        }
    ]
    if include_form:
        varieties.append(
            {
                "is_default": False,
                "pokemon": {
                    "name": "venusaur-mega",
                    "url": _url("pokemon", 10003),
                },
            }
        )
    return {
        "id": identifier,
        "name": name,
        "generation": {"name": "generation-i", "url": _url("generation", 1)},
        "evolution_chain": {"url": _url("evolution-chain", 1)},
        "genera": [
            {"genus": f"{name.title()} Pokémon", "language": {"name": "en"}}
        ],
        "flavor_text_entries": [
            {
                "flavor_text": f"A fixture description for {name}.",
                "language": {"name": "en"},
                "version": {"name": "lets-go-pikachu"},
            }
        ],
        "varieties": varieties,
    }


def _evolution_detail(level: int) -> dict[str, object]:
    return {
        "trigger": {"name": "level-up"},
        "min_level": level,
        "min_happiness": None,
        "min_affection": None,
        "min_beauty": None,
        "time_of_day": "",
        "gender": None,
        "known_move": None,
        "known_move_type": None,
        "location": None,
        "held_item": None,
        "needs_overworld_rain": False,
        "party_species": None,
        "party_type": None,
        "turn_upside_down": False,
        "relative_physical_stats": None,
    }


def _chain_node(
    identifier: int,
    name: str,
    children: list[dict[str, object]],
    details: list[dict[str, object]] | None = None,
) -> dict[str, object]:
    return {
        "species": {"name": name, "url": _url("pokemon-species", identifier)},
        "evolution_details": details or [],
        "evolves_to": children,
    }


def _write_record(
    root: Path,
    relative: str,
    value: dict[str, object],
    *,
    kind: str,
    stable_id: int | None,
    manifest: list[dict[str, object]],
) -> None:
    path = root / relative
    write_json(path, value)
    entry: dict[str, object] = {
        "path": relative,
        "kind": kind,
        "required": True,
        "size": path.stat().st_size,
        "sha256": sha256_file(path),
    }
    if stable_id is not None:
        entry["stableId"] = stable_id
    manifest.append(entry)


def _seal(root: Path, metadata: dict[str, object]) -> None:
    write_json(root / "snapshot.json", metadata)
    write_json(
        root / ".complete",
        {"snapshotMetadataSha256": sha256_file(root / "snapshot.json")},
    )


def make_snapshot(parent: Path, name: str = "fixture-v1") -> Path:
    root = parent / name
    root.mkdir()
    manifest: list[dict[str, object]] = []
    records: dict[str, list[str]] = {
        "species": [],
        "defaultPokemon": [],
        "formPokemon": [],
        "moves": [],
        "evolutionChains": [],
    }

    names = {1: "bulbasaur", 2: "ivysaur", 3: "venusaur"}
    for identifier, name_value in names.items():
        relative = f"records/pokemon-species/{identifier}.json"
        _write_record(
            root,
            relative,
            _species(identifier, name_value, include_form=identifier == 3),
            kind="record-species-json",
            stable_id=identifier,
            manifest=manifest,
        )
        records["species"].append(relative)
        relative = f"records/pokemon/{identifier}.json"
        _write_record(
            root,
            relative,
            _pokemon(identifier, name_value, identifier),
            kind="record-default-pokemon-json",
            stable_id=identifier,
            manifest=manifest,
        )
        records["defaultPokemon"].append(relative)

    form_relative = "records/pokemon/10003.json"
    _write_record(
        root,
        form_relative,
        _pokemon(10003, "venusaur-mega", 3, is_form=True),
        kind="record-form-pokemon-json",
        stable_id=10003,
        manifest=manifest,
    )
    records["formPokemon"].append(form_relative)

    move_relative = "records/move/33.json"
    _write_record(
        root,
        move_relative,
        {
            "id": 33,
            "name": "tackle",
            "type": {"name": "normal", "url": _url("type", 1)},
        },
        kind="record-move-json",
        stable_id=33,
        manifest=manifest,
    )
    records["moves"].append(move_relative)

    venusaur = _chain_node(
        3,
        "venusaur",
        [],
        [_evolution_detail(32)],
    )
    ivysaur = _chain_node(2, "ivysaur", [], [_evolution_detail(16)])
    chain_relative = "records/evolution-chain/1.json"
    _write_record(
        root,
        chain_relative,
        {"id": 1, "chain": _chain_node(1, "bulbasaur", [ivysaur, venusaur])},
        kind="record-evolution-json",
        stable_id=1,
        manifest=manifest,
    )
    records["evolutionChains"].append(chain_relative)

    mappings: list[dict[str, object]] = []
    for identifier in names:
        relative = f"artwork/base/{identifier}.png"
        path = root / relative
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(PNG)
        manifest.append(
            {
                "path": relative,
                "kind": "artwork-base-png",
                "required": True,
                "size": path.stat().st_size,
                "sha256": sha256_file(path),
                "stableId": identifier,
            }
        )
        mappings.append(
            {
                "category": "base",
                "id": identifier,
                "snapshotPath": relative,
                "outputAsset": f"assets/artwork/{identifier}.png",
                "sourceUrl": f"https://example.invalid/{identifier}.png",
                "fallback": "official-artwork",
            }
        )
    form_art = "artwork/forms/venusaur-mega.png"
    form_path = root / form_art
    form_path.parent.mkdir(parents=True, exist_ok=True)
    form_path.write_bytes(PNG)
    manifest.append(
        {
            "path": form_art,
            "kind": "artwork-form-png",
            "required": True,
            "size": form_path.stat().st_size,
            "sha256": sha256_file(form_path),
            "stableId": 10003,
        }
    )
    mappings.append(
        {
            "category": "forms",
            "id": "venusaur-mega",
            "upstreamPokemonId": 10003,
            "speciesId": 3,
            "snapshotPath": form_art,
            "outputAsset": "assets/form_artwork/venusaur-mega.png",
            "sourceUrl": "https://example.invalid/venusaur-mega.png",
            "fallback": "official-artwork",
        }
    )
    mapping_relative = "mappings/artwork.json"
    _write_record(
        root,
        mapping_relative,
        {"mappings": mappings},
        kind="mapping-json",
        stable_id=None,
        manifest=manifest,
    )
    license_relative = "licenses/THIRD_PARTY_NOTICES.md"
    license_path = root / license_relative
    license_path.parent.mkdir(parents=True, exist_ok=True)
    license_path.write_text("Fixture notices.\n", encoding="utf-8")
    manifest.append(
        {
            "path": license_relative,
            "kind": "license",
            "required": True,
            "size": license_path.stat().st_size,
            "sha256": sha256_file(license_path),
        }
    )

    metadata: dict[str, object] = {
        "snapshotFormatVersion": SNAPSHOT_FORMAT_VERSION,
        "snapshotId": name,
        "createdAtUtc": "2026-01-02T03:04:05Z",
        "sourceAcquiredAtUtc": "2025-12-31T23:59:59Z",
        "acquisitionToolVersion": ACQUISITION_TOOL_VERSION,
        "sources": [
            {
                "name": "Fixture",
                "baseLocation": "local",
                "revision": "fixture-r1",
            }
        ],
        "catalog": {
            "highestNationalDexNumber": 3,
            "speciesCount": 3,
            "catalogSha256": "fixture",
        },
        "expectedCounts": {
            "species": 3,
            "defaultPokemon": 3,
            "pokemonRecords": 4,
            "forms": 1,
            "evolutionChains": 1,
            "moves": 1,
            "abilities": 1,
            "types": 2,
            "artwork": {"base": 3, "forms": 1},
        },
        "languages": ["en"],
        "records": records,
        "artworkMappingsFile": mapping_relative,
        "criticalRecords": {
            "speciesIds": [1, 3],
            "evolutionChainIds": [1],
            "types": ["grass", "poison"],
        },
        "knownOmissions": [],
        "manualCorrections": [],
        "licenses": [{"name": "Fixture", "path": license_relative}],
        "fileManifest": sorted(manifest, key=lambda item: str(item["path"])),
    }
    _seal(root, metadata)
    return root


def _metadata(root: Path) -> dict[str, object]:
    return json.loads((root / "snapshot.json").read_text(encoding="utf-8"))


def _error_codes(root: Path) -> set[str]:
    return {issue.code for issue in validate_snapshot(root).errors}


class SnapshotValidationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.parent = Path(self.temporary.name)
        self.snapshot = make_snapshot(self.parent)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_valid_snapshot_reports_expected_facts(self) -> None:
        report = validate_snapshot(self.snapshot)
        self.assertTrue(report.valid, report.to_markdown())
        self.assertFalse(report.warnings)
        self.assertEqual(report.facts["species"], 3)
        self.assertEqual(report.facts["forms"], 1)
        self.assertEqual(report.facts["artwork"], {"base": 3, "forms": 1})

    def test_rejects_wrong_format_and_completion_checksum(self) -> None:
        metadata = _metadata(self.snapshot)
        metadata["snapshotFormatVersion"] = 999
        write_json(self.snapshot / "snapshot.json", metadata)
        codes = _error_codes(self.snapshot)
        self.assertIn("unsupported_snapshot_format", codes)
        self.assertIn("completion_checksum_mismatch", codes)

    def test_rejects_missing_completion_marker(self) -> None:
        (self.snapshot / ".complete").unlink()
        self.assertIn("snapshot_incomplete", _error_codes(self.snapshot))

    def test_rejects_missing_required_record_categories(self) -> None:
        missing_records = (
            "records/pokemon-species/1.json",
            "records/pokemon/10003.json",
            "records/evolution-chain/1.json",
            "records/move/33.json",
        )
        for index, relative in enumerate(missing_records, start=2):
            with self.subTest(relative=relative):
                snapshot = make_snapshot(self.parent, f"fixture-v{index}")
                (snapshot / relative).unlink()
                self.assertIn("required_file_missing", _error_codes(snapshot))

    def test_rejects_checksum_changed_file(self) -> None:
        second = make_snapshot(self.parent, "fixture-checksum")
        artwork = second / "artwork" / "base" / "1.png"
        artwork.write_bytes(PNG + b"changed")
        codes = _error_codes(second)
        self.assertIn("file_size_mismatch", codes)
        self.assertIn("file_checksum_mismatch", codes)

    def test_rejects_malformed_json_even_with_updated_checksum(self) -> None:
        relative = "records/move/33.json"
        path = self.snapshot / relative
        path.write_text("{broken", encoding="utf-8")
        metadata = _metadata(self.snapshot)
        entry = next(
            item for item in metadata["fileManifest"] if item["path"] == relative
        )
        entry["size"] = path.stat().st_size
        entry["sha256"] = sha256_file(path)
        _seal(self.snapshot, metadata)
        self.assertIn("json_invalid", _error_codes(self.snapshot))

    def test_rejects_non_numeric_record_identifier_without_crashing(self) -> None:
        relative = "records/move/33.json"
        path = self.snapshot / relative
        value = json.loads(path.read_text(encoding="utf-8"))
        value["id"] = "not-a-number"
        write_json(path, value)
        metadata = _metadata(self.snapshot)
        entry = next(
            item for item in metadata["fileManifest"] if item["path"] == relative
        )
        entry["size"] = path.stat().st_size
        entry["sha256"] = sha256_file(path)
        _seal(self.snapshot, metadata)
        self.assertIn("record_id_invalid", _error_codes(self.snapshot))

    def test_rejects_duplicate_stable_identifier(self) -> None:
        source = self.snapshot / "records" / "move" / "33.json"
        relative = "records/move/duplicate-33.json"
        target = self.snapshot / relative
        shutil.copyfile(source, target)
        metadata = _metadata(self.snapshot)
        metadata["fileManifest"].append(
            {
                "path": relative,
                "kind": "record-move-json",
                "required": True,
                "size": target.stat().st_size,
                "sha256": sha256_file(target),
                "stableId": 33,
            }
        )
        _seal(self.snapshot, metadata)
        self.assertIn("duplicate_stable_id", _error_codes(self.snapshot))

    def test_rejects_invalid_mapped_artwork(self) -> None:
        relative = "artwork/forms/venusaur-mega.png"
        path = self.snapshot / relative
        path.write_bytes(b"not-png")
        metadata = _metadata(self.snapshot)
        entry = next(
            item for item in metadata["fileManifest"] if item["path"] == relative
        )
        entry["size"] = path.stat().st_size
        entry["sha256"] = sha256_file(path)
        _seal(self.snapshot, metadata)
        self.assertIn("artwork_invalid", _error_codes(self.snapshot))

    def test_rejects_missing_mapped_artwork_and_count_mismatch(self) -> None:
        (self.snapshot / "artwork" / "forms" / "venusaur-mega.png").unlink()
        metadata = _metadata(self.snapshot)
        metadata["expectedCounts"]["forms"] = 2
        _seal(self.snapshot, metadata)
        codes = _error_codes(self.snapshot)
        self.assertIn("artwork_missing", codes)
        self.assertIn("semantic_count_mismatch", codes)


class AcquisitionSafetyTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.parent = Path(self.temporary.name)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def test_cache_only_rejects_missing_and_malformed_json(self) -> None:
        fetcher = CachedFetcher(
            self.parent / "cache",
            cache_only=True,
            refresh=False,
        )
        url = f"{API}/pokemon/1"
        with self.assertRaisesRegex(AcquisitionError, "missing"):
            fetcher.json(url)
        cached = self.parent / "cache" / "pokemon-1.json"
        cached.write_text("{broken", encoding="utf-8")
        with self.assertRaisesRegex(AcquisitionError, "malformed"):
            fetcher.json(url)

    def test_finalized_snapshot_identifier_is_immutable(self) -> None:
        output = self.parent / "snapshots"
        final = output / "already-final"
        final.mkdir(parents=True)
        with self.assertRaisesRegex(AcquisitionError, "immutable"):
            acquire_snapshot(
                snapshot_id="already-final",
                output_root=output,
                cache_dir=self.parent / "cache",
                artwork_cache_dir=self.parent / "art-cache",
                existing_base_artwork=self.parent / "base",
                existing_form_artwork=self.parent / "forms",
                third_party_notices=self.parent / "notices.md",
                cache_only=True,
            )


class GenerationTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.parent = Path(self.temporary.name)
        self.snapshot = make_snapshot(self.parent)

    def tearDown(self) -> None:
        self.temporary.cleanup()

    def _build(self, output: Path):
        return build_reference_data(
            root=Path(__file__).resolve().parents[2],
            snapshot=self.snapshot,
            output=output,
            dataset_version=4,
            content_schema=1,
            display_name="Fixture companion",
            production_approved=False,
        )

    def test_offline_build_validates_schema_counts_forms_and_evolutions(self) -> None:
        output = self.parent / "candidate"
        with mock.patch(
            "urllib.request.urlopen",
            side_effect=AssertionError("network must not be used"),
        ):
            result, report, _ = self._build(output)
        self.assertEqual(result, output)
        self.assertTrue(report.valid, report.to_markdown())
        self.assertTrue(validate_generated_output(output).valid)

        database = sqlite3.connect(output / "content" / "demo_reference.sqlite")
        try:
            self.assertEqual(
                database.execute("PRAGMA integrity_check").fetchone()[0], "ok"
            )
            self.assertEqual(database.execute("PRAGMA foreign_key_check").fetchall(), [])
            self.assertEqual(
                database.execute("SELECT COUNT(*) FROM species").fetchone()[0], 3
            )
            self.assertEqual(
                database.execute("SELECT COUNT(*) FROM forms").fetchone()[0], 1
            )
            self.assertEqual(
                database.execute(
                    "SELECT artwork_asset FROM forms WHERE id='venusaur-mega'"
                ).fetchone()[0],
                "assets/form_artwork/venusaur-mega.png",
            )
            self.assertEqual(
                database.execute("SELECT COUNT(*) FROM evolution_edges").fetchone()[0],
                2,
            )
            self.assertEqual(
                database.execute("SELECT COUNT(*) FROM species_moves").fetchone()[0],
                3,
            )
            metadata = dict(database.execute("SELECT key,value FROM metadata"))
            self.assertEqual(metadata["source_snapshot_id"], "fixture-v1")
            self.assertEqual(metadata["generator_version"], GENERATOR_VERSION)
        finally:
            database.close()

    def test_same_snapshot_has_same_logical_database(self) -> None:
        first = self.parent / "first"
        second = self.parent / "second"
        self._build(first)
        self._build(second)
        first_db = first / "content" / "demo_reference.sqlite"
        second_db = second / "content" / "demo_reference.sqlite"
        self.assertEqual(
            logical_database_fingerprint(first_db),
            logical_database_fingerprint(second_db),
        )
        self.assertEqual(sha256_file(first_db), sha256_file(second_db))
        self.assertEqual(
            sha256_file(first / "artwork" / "1.png"),
            sha256_file(second / "artwork" / "1.png"),
        )

    def test_failed_validation_preserves_existing_output(self) -> None:
        output = self.parent / "existing"
        output.mkdir()
        marker = output / "keep.txt"
        marker.write_text("last known good", encoding="utf-8")
        (self.snapshot / ".complete").unlink()
        with self.assertRaises(SnapshotValidationError):
            build_reference_data(
                root=Path(__file__).resolve().parents[2],
                snapshot=self.snapshot,
                output=output,
                dataset_version=4,
                content_schema=1,
                display_name="Fixture",
                production_approved=False,
                replace_output=True,
            )
        self.assertEqual(marker.read_text(encoding="utf-8"), "last known good")

    def test_corrupt_generated_database_returns_validation_error(self) -> None:
        output = self.parent / "candidate"
        self._build(output)
        database = output / "content" / "demo_reference.sqlite"
        database.write_bytes(b"not a database")
        report = validate_generated_output(output)
        self.assertFalse(report.valid)
        self.assertIn("sqlite_unreadable", {issue.code for issue in report.errors})

    def test_network_guard_fails_closed(self) -> None:
        with OfflineNetworkGuard():
            with self.assertRaisesRegex(Exception, "Network access attempted"):
                import socket

                socket.create_connection(("127.0.0.1", 9))


class TransformationRuleTests(unittest.TestCase):
    def test_form_categories(self) -> None:
        self.assertEqual(form_category("venusaur-mega")[0], "Mega Evolution")
        self.assertEqual(form_category("raichu-alola")[0], "Alolan Form")
        self.assertIsNone(form_category("pikachu-rock-star"))

    def test_move_selection_prefers_lets_go_and_excludes_missing_lets_go(self) -> None:
        lets_go = _move_item()
        self.assertEqual(selected_move_detail(1, lets_go)["level_learned_at"], 1)
        other = {
            "version_group_details": [
                {
                    "level_learned_at": 99,
                    "move_learn_method": {"name": "level-up"},
                    "version_group": {"name": "scarlet-violet"},
                }
            ]
        }
        self.assertIsNone(selected_move_detail(1, other))
        self.assertEqual(selected_move_detail(906, other)["level_learned_at"], 99)

    def test_evolution_condition_and_branch_order(self) -> None:
        self.assertEqual(condition(_evolution_detail(16)), "Level up at level 16")
        child_a = _chain_node(2, "ivysaur", [], [_evolution_detail(16)])
        child_b = _chain_node(3, "venusaur", [], [_evolution_detail(32)])
        edges: list[tuple[str, int, int, str, int]] = []
        walk_chain(_chain_node(1, "bulbasaur", [child_a, child_b]), "family", edges)
        self.assertEqual([edge[4] for edge in edges], [0, 1])
        self.assertEqual([edge[2] for edge in edges], [2, 3])


if __name__ == "__main__":
    unittest.main()
