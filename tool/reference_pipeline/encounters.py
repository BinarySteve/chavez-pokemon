from __future__ import annotations

import csv
import hashlib
import json
import shutil
import urllib.request
import uuid
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

from .common import LETS_GO_IDS, load_json, sha256_file, title, write_json

POKEAPI_COMMIT = "091f3a0599b1efb01f6b502232eeb7d8cbbb3e8f"
GUIDE_SCHEMA_VERSION = 1
GUIDE_VERSION = 1
PIKACHU_VERSION = "lets-go-pikachu"
EEVEE_VERSION = "lets-go-eevee"
VERSION_ORDER = {PIKACHU_VERSION: 0, EEVEE_VERSION: 1}
EXPECTED_DIRECT_SPECIES = 130
EXPECTED_AREA_COUNT = 65
EXPECTED_MISSING_SPECIES = {
    2,
    3,
    5,
    8,
    9,
    24,
    28,
    40,
    47,
    57,
    65,
    68,
    76,
    94,
    97,
    134,
    135,
    136,
    139,
    141,
    151,
    808,
    809,
}

CSV_FILES = (
    "encounters.csv",
    "encounter_slots.csv",
    "encounter_methods.csv",
    "encounter_method_prose.csv",
    "encounter_condition_value_map.csv",
    "encounter_condition_values.csv",
    "encounter_condition_value_prose.csv",
    "pokemon.csv",
    "versions.csv",
    "location_areas.csv",
    "location_area_prose.csv",
    "locations.csv",
    "languages.csv",
)

REQUIRED_HEADERS = {
    "encounters.csv": {
        "id",
        "version_id",
        "location_area_id",
        "encounter_slot_id",
        "pokemon_id",
        "min_level",
        "max_level",
    },
    "encounter_slots.csv": {
        "id",
        "version_group_id",
        "encounter_method_id",
        "slot",
        "rarity",
    },
    "encounter_methods.csv": {"id", "identifier", "order"},
    "encounter_method_prose.csv": {
        "encounter_method_id",
        "local_language_id",
        "name",
    },
    "encounter_condition_value_map.csv": {
        "encounter_id",
        "encounter_condition_value_id",
    },
    "encounter_condition_values.csv": {
        "id",
        "encounter_condition_id",
        "identifier",
        "is_default",
    },
    "encounter_condition_value_prose.csv": {
        "encounter_condition_value_id",
        "local_language_id",
        "name",
    },
    "pokemon.csv": {
        "id",
        "identifier",
        "species_id",
        "height",
        "weight",
        "base_experience",
        "order",
        "is_default",
    },
    "versions.csv": {"id", "version_group_id", "identifier"},
    "location_areas.csv": {"id", "location_id", "game_index", "identifier"},
    "location_area_prose.csv": {"location_area_id", "local_language_id", "name"},
    "locations.csv": {"id", "region_id", "identifier"},
    "languages.csv": {
        "id",
        "iso639",
        "iso3166",
        "identifier",
        "official",
        "order",
    },
}


class EncounterGuideError(RuntimeError):
    pass


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _canonical_hash(value: dict[str, Any]) -> str:
    encoded = json.dumps(
        value,
        ensure_ascii=False,
        separators=(",", ":"),
        sort_keys=True,
    ).encode("utf-8")
    return hashlib.sha256(encoded).hexdigest()


def _csv_rows(path: Path) -> list[dict[str, str]]:
    try:
        with path.open(encoding="utf-8", newline="") as source:
            reader = csv.DictReader(source)
            headers = set(reader.fieldnames or [])
            required = REQUIRED_HEADERS[path.name]
            if not required.issubset(headers):
                missing = sorted(required - headers)
                raise EncounterGuideError(
                    f"{path.name} lacks required columns: {missing}"
                )
            return list(reader)
    except (OSError, UnicodeDecodeError, csv.Error) as error:
        raise EncounterGuideError(f"Unable to read {path}: {error}") from error


def _source_paths(snapshot: Path, metadata: dict[str, Any]) -> dict[str, Path]:
    source = metadata.get("encounterGuideSource")
    if not isinstance(source, dict):
        raise EncounterGuideError("Snapshot has no encounterGuideSource metadata.")
    if source.get("repositoryCommit") != POKEAPI_COMMIT:
        raise EncounterGuideError(
            "Encounter source commit mismatch: "
            f"expected {POKEAPI_COMMIT}; found {source.get('repositoryCommit')}."
        )
    files = source.get("csvFiles")
    if not isinstance(files, dict):
        raise EncounterGuideError("encounterGuideSource.csvFiles must be an object.")
    missing = sorted(set(CSV_FILES) - set(files))
    if missing:
        raise EncounterGuideError(f"Encounter source paths missing: {missing}")
    return {name: snapshot / str(files[name]) for name in CSV_FILES}


def load_progression(path: Path) -> dict[int, int]:
    value = load_json(path)
    if value.get("schemaVersion") != 1:
        raise EncounterGuideError("Unsupported progression-map schema version.")
    areas = value.get("requiredBadgesByAreaId")
    if not isinstance(areas, dict):
        raise EncounterGuideError("Progression map must contain requiredBadgesByAreaId.")
    result: dict[int, int] = {}
    for raw_area, raw_badges in areas.items():
        try:
            area_id = int(raw_area)
            badges = int(raw_badges)
        except (TypeError, ValueError) as error:
            raise EncounterGuideError(
                f"Invalid progression entry {raw_area!r}: {raw_badges!r}"
            ) from error
        if badges < 0 or badges > 8:
            raise EncounterGuideError(
                f"Area {area_id} requiredBadges must be between 0 and 8."
            )
        result[area_id] = badges
    return result


def _raw_source(
    snapshot: Path,
    metadata: dict[str, Any],
) -> dict[str, list[dict[str, str]]]:
    paths = _source_paths(snapshot, metadata)
    return {name: _csv_rows(path) for name, path in paths.items()}


def encounter_source_facts(
    snapshot: Path,
    metadata: dict[str, Any],
    progression_path: Path,
) -> dict[str, Any]:
    source = _raw_source(snapshot, metadata)
    versions = {
        row["identifier"]: int(row["id"]) for row in source["versions.csv"]
    }
    try:
        target_versions = {versions[PIKACHU_VERSION], versions[EEVEE_VERSION]}
    except KeyError as error:
        raise EncounterGuideError(f"Missing Let’s Go version: {error}") from error
    pokemon = {
        int(row["id"]): int(row["species_id"]) for row in source["pokemon.csv"]
    }
    target_rows = [
        row
        for row in source["encounters.csv"]
        if int(row["version_id"]) in target_versions
    ]
    area_ids = {int(row["location_area_id"]) for row in target_rows}
    progression = load_progression(progression_path)
    if area_ids != set(progression):
        missing = sorted(area_ids - set(progression))
        extra = sorted(set(progression) - area_ids)
        raise EncounterGuideError(
            f"Progression map mismatch; missing areas {missing}, extra areas {extra}."
        )
    direct_species = {
        pokemon[int(row["pokemon_id"])]
        for row in target_rows
        if pokemon[int(row["pokemon_id"])] in LETS_GO_IDS
    }
    missing_species = LETS_GO_IDS - direct_species
    if len(area_ids) != EXPECTED_AREA_COUNT:
        raise EncounterGuideError(
            f"Expected {EXPECTED_AREA_COUNT} Let’s Go areas; found {len(area_ids)}."
        )
    if len(direct_species) != EXPECTED_DIRECT_SPECIES:
        raise EncounterGuideError(
            f"Expected {EXPECTED_DIRECT_SPECIES} directly encountered species; "
            f"found {len(direct_species)}."
        )
    if missing_species != EXPECTED_MISSING_SPECIES:
        raise EncounterGuideError(
            "Direct-encounter omission allowlist changed: "
            f"{sorted(missing_species)}."
        )
    return {
        "repositoryCommit": POKEAPI_COMMIT,
        "csvFiles": len(CSV_FILES),
        "letsGoAreas": len(area_ids),
        "directSpecies": len(direct_species),
        "missingSpeciesIds": sorted(missing_species),
    }


def _display_location(
    *,
    location_slug: str,
    area_slug: str,
    area_prose: str,
) -> str:
    location = title(location_slug.removeprefix("kanto-").removeprefix("kanto-sea-"))
    if area_prose.startswith("Road "):
        area_prose = f"Route {area_prose.removeprefix('Road ')}"
    if location.startswith("Route "):
        location = location
    if not area_slug:
        return area_prose or location
    floor = area_slug.upper()
    if floor in {"1F", "2F", "3F", "4F", "5F", "6F", "B1F", "B2F", "B3F", "B4F"}:
        return f"{location} {floor}"
    if area_prose and area_prose != location:
        return area_prose
    return f"{location} ({title(area_slug)})"


def build_encounter_guide(
    *,
    snapshot: Path,
    progression_path: Path,
) -> dict[str, Any]:
    metadata = load_json(snapshot / "snapshot.json")
    facts = encounter_source_facts(snapshot, metadata, progression_path)
    source = _raw_source(snapshot, metadata)
    progression = load_progression(progression_path)

    languages = {
        row["identifier"]: int(row["id"]) for row in source["languages.csv"]
    }
    english_id = languages.get("en")
    if english_id is None:
        raise EncounterGuideError("English language identifier is missing.")

    versions = {
        int(row["id"]): row["identifier"] for row in source["versions.csv"]
    }
    target_version_ids = {
        identifier: version_id
        for version_id, identifier in versions.items()
        if identifier in VERSION_ORDER
    }
    if set(target_version_ids) != set(VERSION_ORDER):
        raise EncounterGuideError("Both Let’s Go versions are required.")

    pokemon_species = {
        int(row["id"]): int(row["species_id"]) for row in source["pokemon.csv"]
    }
    methods = {
        int(row["id"]): row["identifier"]
        for row in source["encounter_methods.csv"]
    }
    slots = {
        int(row["id"]): {
            "method": methods[int(row["encounter_method_id"])],
            "rarity": int(row["rarity"]),
        }
        for row in source["encounter_slots.csv"]
    }
    conditions = {
        int(row["id"]): row["identifier"]
        for row in source["encounter_condition_values.csv"]
    }
    conditions_by_encounter: dict[int, list[str]] = defaultdict(list)
    for row in source["encounter_condition_value_map.csv"]:
        conditions_by_encounter[int(row["encounter_id"])].append(
            conditions[int(row["encounter_condition_value_id"])]
        )

    locations = {
        int(row["id"]): row["identifier"] for row in source["locations.csv"]
    }
    area_rows = {
        int(row["id"]): row for row in source["location_areas.csv"]
    }
    area_prose = {
        int(row["location_area_id"]): row["name"]
        for row in source["location_area_prose.csv"]
        if int(row["local_language_id"]) == english_id and row["name"]
    }

    target_version_values = set(target_version_ids.values())
    target_rows = [
        row
        for row in source["encounters.csv"]
        if int(row["version_id"]) in target_version_values
    ]
    encounter_area_ids = sorted(
        {int(row["location_area_id"]) for row in target_rows}
    )
    areas = []
    for area_id in encounter_area_ids:
        row = area_rows[area_id]
        location_slug = locations[int(row["location_id"])]
        area_slug = row["identifier"]
        areas.append(
            {
                "id": area_id,
                "locationSlug": location_slug,
                "areaSlug": area_slug,
                "displayName": _display_location(
                    location_slug=location_slug,
                    area_slug=area_slug,
                    area_prose=area_prose.get(area_id, ""),
                ),
                "requiredBadges": progression[area_id],
            }
        )

    grouped: dict[
        tuple[int, int, str, int, int, int, tuple[str, ...]], set[str]
    ] = defaultdict(set)
    for row in target_rows:
        species_id = pokemon_species[int(row["pokemon_id"])]
        if species_id not in LETS_GO_IDS:
            continue
        slot = slots[int(row["encounter_slot_id"])]
        encounter_id = int(row["id"])
        key = (
            species_id,
            int(row["location_area_id"]),
            str(slot["method"]),
            int(row["min_level"]),
            int(row["max_level"]),
            int(slot["rarity"]),
            tuple(sorted(conditions_by_encounter.get(encounter_id, []))),
        )
        grouped[key].add(versions[int(row["version_id"])])

    encounters = []
    for key, encounter_versions in sorted(grouped.items()):
        (
            species_id,
            area_id,
            method,
            min_level,
            max_level,
            rarity,
            condition_values,
        ) = key
        encounters.append(
            {
                "speciesId": species_id,
                "areaId": area_id,
                "versions": sorted(
                    encounter_versions,
                    key=lambda value: VERSION_ORDER[value],
                ),
                "method": method,
                "minLevel": min_level,
                "maxLevel": max_level,
                "slotRarity": rarity,
                "conditions": list(condition_values),
            }
        )

    guide = {
        "guideSchemaVersion": GUIDE_SCHEMA_VERSION,
        "guideVersion": GUIDE_VERSION,
        "source": {
            "provider": "PokéAPI",
            "repositoryCommit": POKEAPI_COMMIT,
            "parentSnapshotId": metadata.get("parentSnapshotId"),
            "snapshotId": metadata["snapshotId"],
        },
        "facts": facts,
        "areas": areas,
        "encounters": encounters,
    }
    guide["logicalSha256"] = _canonical_hash(guide)
    validate_encounter_guide(guide)
    return guide


def validate_encounter_guide(guide: dict[str, Any]) -> dict[str, Any]:
    if guide.get("guideSchemaVersion") != GUIDE_SCHEMA_VERSION:
        raise EncounterGuideError("Unsupported encounter-guide schema version.")
    if guide.get("guideVersion") != GUIDE_VERSION:
        raise EncounterGuideError("Unsupported encounter-guide version.")
    expected_hash = guide.get("logicalSha256")
    without_hash = dict(guide)
    without_hash.pop("logicalSha256", None)
    actual_hash = _canonical_hash(without_hash)
    if expected_hash != actual_hash:
        raise EncounterGuideError(
            f"Encounter-guide logical hash mismatch: {expected_hash} != {actual_hash}."
        )
    areas = guide.get("areas")
    encounters = guide.get("encounters")
    if not isinstance(areas, list) or not isinstance(encounters, list):
        raise EncounterGuideError("Encounter guide areas and encounters must be lists.")
    area_ids = {int(area["id"]) for area in areas}
    if len(area_ids) != EXPECTED_AREA_COUNT:
        raise EncounterGuideError(
            f"Expected {EXPECTED_AREA_COUNT} guide areas; found {len(area_ids)}."
        )
    for area in areas:
        badges = int(area["requiredBadges"])
        if badges < 0 or badges > 8:
            raise EncounterGuideError(
                f"Area {area['id']} has invalid requiredBadges {badges}."
            )
    direct_species = {int(row["speciesId"]) for row in encounters}
    if len(direct_species) != EXPECTED_DIRECT_SPECIES:
        raise EncounterGuideError(
            f"Expected {EXPECTED_DIRECT_SPECIES} guide species; "
            f"found {len(direct_species)}."
        )
    for row in encounters:
        if int(row["areaId"]) not in area_ids:
            raise EncounterGuideError(
                f"Encounter references unknown area {row['areaId']}."
            )
        if not set(row["versions"]).issubset(VERSION_ORDER):
            raise EncounterGuideError(
                f"Encounter has invalid versions {row['versions']}."
            )
    return {
        "areas": len(areas),
        "encounters": len(encounters),
        "directSpecies": len(direct_species),
        "logicalSha256": expected_hash,
    }


def write_encounter_guide(
    *,
    snapshot: Path,
    progression_path: Path,
    output: Path,
) -> dict[str, Any]:
    guide = build_encounter_guide(
        snapshot=snapshot,
        progression_path=progression_path,
    )
    write_json(output, guide)
    return validate_encounter_guide(guide)


def extend_snapshot_with_encounters(
    *,
    base_snapshot: Path,
    output_root: Path,
    snapshot_id: str,
    third_party_notices: Path,
) -> Path:
    if not snapshot_id or "/" in snapshot_id or "\\" in snapshot_id:
        raise EncounterGuideError("Snapshot identifier must be one directory name.")
    base_snapshot = base_snapshot.resolve()
    output_root = output_root.resolve()
    final = output_root / snapshot_id
    if final.exists():
        raise EncounterGuideError(f"Finalized snapshot already exists: {final}")
    if not (base_snapshot / ".complete").is_file():
        raise EncounterGuideError("Base snapshot is not finalized.")

    output_root.mkdir(parents=True, exist_ok=True)
    temporary = output_root / f".{snapshot_id}.incomplete-{uuid.uuid4().hex}"
    try:
        shutil.copytree(base_snapshot, temporary)
        (temporary / ".complete").unlink(missing_ok=True)
        metadata = load_json(temporary / "snapshot.json")
        parent_id = metadata["snapshotId"]
        csv_paths: dict[str, str] = {}
        manifest = list(metadata["fileManifest"])
        for name in CSV_FILES:
            relative = f"records/encounters/{name}"
            destination = temporary / relative
            destination.parent.mkdir(parents=True, exist_ok=True)
            url = (
                "https://raw.githubusercontent.com/PokeAPI/pokeapi/"
                f"{POKEAPI_COMMIT}/data/v2/csv/{name}"
            )
            request = urllib.request.Request(
                url,
                headers={"User-Agent": "PokemonAdventureReferencePipeline/1.1"},
            )
            try:
                with urllib.request.urlopen(request, timeout=60) as response:
                    payload = response.read()
            except OSError as error:
                raise EncounterGuideError(f"Failed to acquire {url}: {error}") from error
            destination.write_bytes(payload)
            csv_paths[name] = relative
            manifest.append(
                {
                    "path": relative,
                    "kind": "encounter-source-csv",
                    "required": True,
                    "size": len(payload),
                    "sha256": hashlib.sha256(payload).hexdigest(),
                }
            )

        notices_relative = "licenses/THIRD_PARTY_NOTICES.md"
        notices_target = temporary / notices_relative
        shutil.copyfile(third_party_notices, notices_target)
        for entry in manifest:
            if entry["path"] == notices_relative:
                entry["size"] = notices_target.stat().st_size
                entry["sha256"] = sha256_file(notices_target)

        metadata["snapshotId"] = snapshot_id
        metadata["parentSnapshotId"] = parent_id
        metadata["createdAtUtc"] = _utc_now()
        metadata["sourceAcquiredAtUtc"] = metadata["createdAtUtc"]
        metadata["acquisitionToolVersion"] = "1.1.0"
        metadata["encounterGuideSource"] = {
            "provider": "PokéAPI repository CSV",
            "repositoryCommit": POKEAPI_COMMIT,
            "csvFiles": csv_paths,
        }
        metadata["sources"] = [
            *metadata.get("sources", []),
            {
                "name": "PokéAPI encounter CSV data",
                "baseLocation": (
                    "https://github.com/PokeAPI/pokeapi/tree/"
                    f"{POKEAPI_COMMIT}/data/v2/csv"
                ),
                "revision": POKEAPI_COMMIT,
            },
        ]
        metadata["fileManifest"] = sorted(manifest, key=lambda entry: entry["path"])
        metadata["expectedCounts"] = {
            **metadata.get("expectedCounts", {}),
            "letsGoEncounterAreas": EXPECTED_AREA_COUNT,
            "letsGoDirectEncounterSpecies": EXPECTED_DIRECT_SPECIES,
        }
        write_json(temporary / "snapshot.json", metadata)
        write_json(
            temporary / ".complete",
            {
                "snapshotId": snapshot_id,
                "snapshotMetadataSha256": sha256_file(temporary / "snapshot.json"),
            },
        )
        final.mkdir()
        try:
            for child in sorted(
                (
                    path
                    for path in temporary.iterdir()
                    if path.name != ".complete"
                ),
                key=lambda path: path.name,
            ):
                shutil.move(str(child), str(final / child.name))
            shutil.move(
                str(temporary / ".complete"),
                str(final / ".complete"),
            )
            temporary.rmdir()
        except BaseException:
            shutil.rmtree(final, ignore_errors=True)
            raise
        return final
    except BaseException:
        if temporary.exists():
            shutil.rmtree(temporary)
        raise
