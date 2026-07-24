from __future__ import annotations

import csv
import json
import sys
import tempfile
import unittest
from pathlib import Path

TOOL_ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(TOOL_ROOT))

from reference_pipeline.common import LETS_GO_IDS, write_json  # noqa: E402
from reference_pipeline.encounters import (  # noqa: E402
    CSV_FILES,
    EEVEE_VERSION,
    EXPECTED_MISSING_SPECIES,
    PIKACHU_VERSION,
    POKEAPI_COMMIT,
    EncounterGuideError,
    build_encounter_guide,
    encounter_source_facts,
    validate_encounter_guide,
)

PROGRESSION_SOURCE = (
    TOOL_ROOT / "reference_pipeline" / "lets_go_progression.json"
)


def _write_csv(
    path: Path,
    headers: list[str],
    rows: list[dict[str, object]],
) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8", newline="") as destination:
        writer = csv.DictWriter(destination, fieldnames=headers)
        writer.writeheader()
        writer.writerows(rows)


def _fixture(root: Path) -> tuple[Path, Path]:
    snapshot = root / "snapshot"
    records = snapshot / "records" / "encounters"
    records.mkdir(parents=True)
    progression = root / "progression.json"
    progression.write_text(
        PROGRESSION_SOURCE.read_text(encoding="utf-8"),
        encoding="utf-8",
    )
    progression_value = json.loads(progression.read_text(encoding="utf-8"))
    area_ids = [
        int(value)
        for value in progression_value["requiredBadgesByAreaId"].keys()
    ]
    direct_species = sorted(LETS_GO_IDS - EXPECTED_MISSING_SPECIES)

    _write_csv(
        records / "versions.csv",
        ["id", "version_group_id", "identifier"],
        [
            {"id": 31, "version_group_id": 18, "identifier": PIKACHU_VERSION},
            {"id": 32, "version_group_id": 18, "identifier": EEVEE_VERSION},
        ],
    )
    _write_csv(
        records / "pokemon.csv",
        [
            "id",
            "identifier",
            "species_id",
            "height",
            "weight",
            "base_experience",
            "order",
            "is_default",
        ],
        [
            {
                "id": species_id,
                "identifier": f"species-{species_id}",
                "species_id": species_id,
                "height": 1,
                "weight": 1,
                "base_experience": 1,
                "order": species_id,
                "is_default": 1,
            }
            for species_id in sorted(LETS_GO_IDS)
        ],
    )
    _write_csv(
        records / "encounter_methods.csv",
        ["id", "identifier", "order"],
        [{"id": 1, "identifier": "overworld", "order": 1}],
    )
    _write_csv(
        records / "encounter_method_prose.csv",
        ["encounter_method_id", "local_language_id", "name"],
        [{"encounter_method_id": 1, "local_language_id": 9, "name": "Walking"}],
    )
    _write_csv(
        records / "encounter_slots.csv",
        [
            "id",
            "version_group_id",
            "encounter_method_id",
            "slot",
            "rarity",
        ],
        [
            {
                "id": 1,
                "version_group_id": 18,
                "encounter_method_id": 1,
                "slot": 1,
                "rarity": 20,
            }
        ],
    )
    _write_csv(
        records / "locations.csv",
        ["id", "region_id", "identifier"],
        [
            {"id": index, "region_id": 1, "identifier": f"route-{index}"}
            for index in range(1, len(area_ids) + 1)
        ],
    )
    _write_csv(
        records / "location_areas.csv",
        ["id", "location_id", "game_index", "identifier"],
        [
            {
                "id": area_id,
                "location_id": index,
                "game_index": index,
                "identifier": "",
            }
            for index, area_id in enumerate(area_ids, start=1)
        ],
    )
    _write_csv(
        records / "location_area_prose.csv",
        ["location_area_id", "local_language_id", "name"],
        [
            {
                "location_area_id": area_id,
                "local_language_id": 9,
                "name": f"Route {index}",
            }
            for index, area_id in enumerate(area_ids, start=1)
        ],
    )
    _write_csv(
        records / "languages.csv",
        ["id", "iso639", "iso3166", "identifier", "official", "order"],
        [
            {
                "id": 9,
                "iso639": "en",
                "iso3166": "us",
                "identifier": "en",
                "official": 1,
                "order": 1,
            }
        ],
    )
    _write_csv(
        records / "encounter_condition_values.csv",
        ["id", "encounter_condition_id", "identifier", "is_default"],
        [],
    )
    _write_csv(
        records / "encounter_condition_value_map.csv",
        ["encounter_id", "encounter_condition_value_id"],
        [],
    )
    _write_csv(
        records / "encounter_condition_value_prose.csv",
        ["encounter_condition_value_id", "local_language_id", "name"],
        [],
    )

    encounters = []
    encounter_id = 1
    for index, species_id in enumerate(direct_species):
        area_id = area_ids[index % len(area_ids)]
        for version_id in (31, 32):
            encounters.append(
                {
                    "id": encounter_id,
                    "version_id": version_id,
                    "location_area_id": area_id,
                    "encounter_slot_id": 1,
                    "pokemon_id": species_id,
                    "min_level": 3,
                    "max_level": 6,
                }
            )
            encounter_id += 1
    _write_csv(
        records / "encounters.csv",
        [
            "id",
            "version_id",
            "location_area_id",
            "encounter_slot_id",
            "pokemon_id",
            "min_level",
            "max_level",
        ],
        encounters,
    )

    csv_files = {
        name: f"records/encounters/{name}" for name in CSV_FILES
    }
    write_json(
        snapshot / "snapshot.json",
        {
            "snapshotId": "fixture-r2",
            "parentSnapshotId": "fixture-r1",
            "encounterGuideSource": {
                "repositoryCommit": POKEAPI_COMMIT,
                "csvFiles": csv_files,
            },
        },
    )
    return snapshot, progression


class EncounterGuideTests(unittest.TestCase):
    def test_valid_source_has_locked_counts_and_omissions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            snapshot, progression = _fixture(Path(directory))
            metadata = json.loads(
                (snapshot / "snapshot.json").read_text(encoding="utf-8")
            )

            facts = encounter_source_facts(snapshot, metadata, progression)

            self.assertEqual(facts["repositoryCommit"], POKEAPI_COMMIT)
            self.assertEqual(facts["letsGoAreas"], 65)
            self.assertEqual(facts["directSpecies"], 130)
            self.assertEqual(
                set(facts["missingSpeciesIds"]),
                EXPECTED_MISSING_SPECIES,
            )

    def test_generation_is_deterministic_and_combines_versions(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            snapshot, progression = _fixture(Path(directory))

            first = build_encounter_guide(
                snapshot=snapshot,
                progression_path=progression,
            )
            second = build_encounter_guide(
                snapshot=snapshot,
                progression_path=progression,
            )

            self.assertEqual(first, second)
            self.assertEqual(
                first["logicalSha256"],
                validate_encounter_guide(first)["logicalSha256"],
            )
            self.assertEqual(
                first["encounters"][0]["versions"],
                [PIKACHU_VERSION, EEVEE_VERSION],
            )

    def test_missing_csv_and_corrupt_header_fail_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            snapshot, progression = _fixture(Path(directory))
            (snapshot / "records" / "encounters" / "versions.csv").unlink()
            metadata = json.loads(
                (snapshot / "snapshot.json").read_text(encoding="utf-8")
            )
            with self.assertRaises(EncounterGuideError):
                encounter_source_facts(snapshot, metadata, progression)

        with tempfile.TemporaryDirectory() as directory:
            snapshot, progression = _fixture(Path(directory))
            (snapshot / "records" / "encounters" / "encounters.csv").write_text(
                "id,wrong\n1,value\n",
                encoding="utf-8",
            )
            metadata = json.loads(
                (snapshot / "snapshot.json").read_text(encoding="utf-8")
            )
            with self.assertRaises(EncounterGuideError):
                encounter_source_facts(snapshot, metadata, progression)

    def test_unmapped_area_fails_closed(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            snapshot, progression = _fixture(Path(directory))
            value = json.loads(progression.read_text(encoding="utf-8"))
            value["requiredBadgesByAreaId"].pop(next(iter(value["requiredBadgesByAreaId"])))
            progression.write_text(json.dumps(value), encoding="utf-8")
            metadata = json.loads(
                (snapshot / "snapshot.json").read_text(encoding="utf-8")
            )

            with self.assertRaises(EncounterGuideError):
                encounter_source_facts(snapshot, metadata, progression)


if __name__ == "__main__":
    unittest.main()
