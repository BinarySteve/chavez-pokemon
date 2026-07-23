from __future__ import annotations

import json
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from . import SNAPSHOT_FORMAT_VERSION
from .common import (
    POKEMON_TYPES,
    form_category,
    is_png,
    load_json,
    safe_relative_path,
    selected_move_detail,
    sha256_file,
    stable_id_from_url,
)

METADATA_FILE = "snapshot.json"
COMPLETE_FILE = ".complete"


@dataclass(frozen=True)
class ValidationIssue:
    code: str
    message: str
    path: str | None = None

    def to_dict(self) -> dict[str, str]:
        value = {"code": self.code, "message": self.message}
        if self.path is not None:
            value["path"] = self.path
        return value


@dataclass
class ValidationReport:
    subject: str
    errors: list[ValidationIssue] = field(default_factory=list)
    warnings: list[ValidationIssue] = field(default_factory=list)
    facts: dict[str, Any] = field(default_factory=dict)

    @property
    def valid(self) -> bool:
        return not self.errors

    def error(self, code: str, message: str, path: str | None = None) -> None:
        self.errors.append(ValidationIssue(code, message, path))

    def warning(self, code: str, message: str, path: str | None = None) -> None:
        self.warnings.append(ValidationIssue(code, message, path))

    def to_dict(self) -> dict[str, Any]:
        return {
            "subject": self.subject,
            "valid": self.valid,
            "errors": [issue.to_dict() for issue in self.errors],
            "warnings": [issue.to_dict() for issue in self.warnings],
            "facts": self.facts,
        }

    def to_markdown(self) -> str:
        lines = [
            f"# Validation report: {self.subject}",
            "",
            f"Result: {'PASS' if self.valid else 'FAIL'}",
            "",
            f"Errors: {len(self.errors)}",
            f"Warnings: {len(self.warnings)}",
        ]
        if self.errors:
            lines.extend(["", "## Errors", ""])
            lines.extend(
                f"- `{issue.code}` {issue.message}"
                + (f" (`{issue.path}`)" if issue.path else "")
                for issue in self.errors
            )
        if self.warnings:
            lines.extend(["", "## Warnings", ""])
            lines.extend(
                f"- `{issue.code}` {issue.message}"
                + (f" (`{issue.path}`)" if issue.path else "")
                for issue in self.warnings
            )
        if self.facts:
            lines.extend(["", "## Facts", ""])
            lines.extend(
                f"- `{key}`: `{json.dumps(value, ensure_ascii=False, sort_keys=True)}`"
                for key, value in sorted(self.facts.items())
            )
        return "\n".join(lines) + "\n"


class SnapshotValidationError(RuntimeError):
    def __init__(self, report: ValidationReport):
        self.report = report
        super().__init__(
            f"Snapshot validation failed with {len(report.errors)} error(s)"
        )


def write_validation_reports(
    report: ValidationReport,
    output: Path,
) -> None:
    output.mkdir(parents=True, exist_ok=True)
    (output / "validation.json").write_text(
        json.dumps(report.to_dict(), ensure_ascii=False, indent=2, sort_keys=True)
        + "\n",
        encoding="utf-8",
    )
    (output / "validation.md").write_text(
        report.to_markdown(),
        encoding="utf-8",
    )


def read_snapshot_metadata(snapshot: Path) -> dict[str, Any]:
    return load_json(snapshot / METADATA_FILE)


def validate_snapshot(
    snapshot: Path,
    *,
    require_directory_name: bool = True,
) -> ValidationReport:
    snapshot = snapshot.resolve()
    report = ValidationReport(subject=str(snapshot))
    metadata_path = snapshot / METADATA_FILE
    complete_path = snapshot / COMPLETE_FILE

    if not snapshot.is_dir():
        report.error("snapshot_missing", "Snapshot directory does not exist.")
        return report
    if not metadata_path.is_file():
        report.error(
            "metadata_missing",
            f"Required {METADATA_FILE} is missing.",
            METADATA_FILE,
        )
        return report
    try:
        metadata = load_json(metadata_path)
    except (OSError, UnicodeDecodeError, json.JSONDecodeError, ValueError) as error:
        report.error("metadata_invalid", str(error), METADATA_FILE)
        return report

    if metadata.get("snapshotFormatVersion") != SNAPSHOT_FORMAT_VERSION:
        report.error(
            "unsupported_snapshot_format",
            "Snapshot format "
            f"{metadata.get('snapshotFormatVersion')!r} is unsupported; "
            f"expected {SNAPSHOT_FORMAT_VERSION}.",
            METADATA_FILE,
        )
    snapshot_id = metadata.get("snapshotId")
    if not isinstance(snapshot_id, str) or not snapshot_id:
        report.error(
            "snapshot_id_missing",
            "Snapshot identifier is missing or invalid.",
            METADATA_FILE,
        )
    elif require_directory_name and snapshot.name != snapshot_id:
        report.error(
            "snapshot_id_mismatch",
            f"Directory name {snapshot.name!r} does not match {snapshot_id!r}.",
            METADATA_FILE,
        )

    if not complete_path.is_file():
        report.error(
            "snapshot_incomplete",
            f"Completion marker {COMPLETE_FILE} is missing.",
            COMPLETE_FILE,
        )
    else:
        try:
            complete = load_json(complete_path)
            expected_metadata_hash = complete["snapshotMetadataSha256"]
            actual_metadata_hash = sha256_file(metadata_path)
            if expected_metadata_hash != actual_metadata_hash:
                report.error(
                    "completion_checksum_mismatch",
                    "Completion marker does not match snapshot metadata.",
                    COMPLETE_FILE,
                )
        except (
            OSError,
            KeyError,
            UnicodeDecodeError,
            json.JSONDecodeError,
            ValueError,
        ) as error:
            report.error("completion_marker_invalid", str(error), COMPLETE_FILE)

    manifest = metadata.get("fileManifest")
    if not isinstance(manifest, list):
        report.error(
            "file_manifest_invalid",
            "fileManifest must be a list.",
            METADATA_FILE,
        )
        return report

    declared_paths: set[str] = set()
    parsed_json: dict[str, dict[str, Any]] = {}
    stable_ids: dict[str, set[int]] = {}
    for entry in manifest:
        if not isinstance(entry, dict):
            report.error(
                "file_manifest_entry_invalid",
                "Every file manifest entry must be an object.",
                METADATA_FILE,
            )
            continue
        relative = entry.get("path")
        if not isinstance(relative, str) or not safe_relative_path(relative):
            report.error(
                "unsafe_manifest_path",
                f"Unsafe file path {relative!r}.",
                METADATA_FILE,
            )
            continue
        if relative in declared_paths:
            report.error(
                "duplicate_manifest_path",
                "File appears more than once in the manifest.",
                relative,
            )
            continue
        declared_paths.add(relative)
        path = snapshot / relative
        required = entry.get("required", True)
        if not path.is_file():
            if required:
                report.error("required_file_missing", "Required file is missing.", relative)
            continue
        expected_size = entry.get("size")
        if expected_size != path.stat().st_size:
            report.error(
                "file_size_mismatch",
                f"Expected {expected_size} bytes; found {path.stat().st_size}.",
                relative,
            )
        expected_hash = entry.get("sha256")
        actual_hash = sha256_file(path)
        if expected_hash != actual_hash:
            report.error(
                "file_checksum_mismatch",
                f"Expected SHA-256 {expected_hash}; found {actual_hash}.",
                relative,
            )
        kind = entry.get("kind", "")
        if kind.endswith("-json") or relative.endswith(".json"):
            try:
                parsed_json[relative] = load_json(path)
            except (
                OSError,
                UnicodeDecodeError,
                json.JSONDecodeError,
                ValueError,
            ) as error:
                report.error("json_invalid", str(error), relative)
                continue
        stable_id = entry.get("stableId")
        if stable_id is not None:
            try:
                numeric_id = int(stable_id)
            except (TypeError, ValueError):
                report.error(
                    "stable_id_invalid",
                    f"Stable identifier {stable_id!r} is not numeric.",
                    relative,
                )
                continue
            seen = stable_ids.setdefault(str(kind), set())
            if numeric_id in seen:
                report.error(
                    "duplicate_stable_id",
                    f"Stable identifier {numeric_id} is duplicated for {kind}.",
                    relative,
                )
            seen.add(numeric_id)
            record = parsed_json.get(relative)
            if record is not None:
                try:
                    record_id = int(record.get("id", -1))
                except (TypeError, ValueError):
                    report.error(
                        "record_id_invalid",
                        f"Record id {record.get('id')!r} is not numeric.",
                        relative,
                    )
                else:
                    if record_id != numeric_id:
                        report.error(
                            "record_id_mismatch",
                            f"Record id {record.get('id')!r} does not match "
                            f"{numeric_id}.",
                            relative,
                        )

    actual_paths = {
        path.relative_to(snapshot).as_posix()
        for path in snapshot.rglob("*")
        if path.is_file()
    }
    expected_special = {METADATA_FILE, COMPLETE_FILE}
    for relative in sorted(actual_paths - declared_paths - expected_special):
        report.warning(
            "unknown_extra_file",
            "File is not declared by the snapshot manifest.",
            relative,
        )

    records = metadata.get("records", {})
    if not isinstance(records, dict):
        report.error("record_index_invalid", "records must be an object.")
        return report
    expected_counts = metadata.get("expectedCounts", {})
    if not isinstance(expected_counts, dict):
        report.error("expected_counts_invalid", "expectedCounts must be an object.")
        return report

    categories = {
        "species": "species",
        "defaultPokemon": "defaultPokemon",
        "formPokemon": "forms",
        "moves": "moves",
        "evolutionChains": "evolutionChains",
    }
    loaded: dict[str, list[dict[str, Any]]] = {}
    for category, count_key in categories.items():
        paths = records.get(category)
        if not isinstance(paths, list):
            report.error(
                "record_index_missing",
                f"records.{category} must be a list.",
                METADATA_FILE,
            )
            continue
        loaded[category] = [
            parsed_json[path]
            for path in paths
            if isinstance(path, str) and path in parsed_json
        ]
        expected = expected_counts.get(count_key)
        if expected != len(paths):
            report.error(
                "semantic_count_mismatch",
                f"{category} expected {expected}; index contains {len(paths)}.",
                METADATA_FILE,
            )
        if len(loaded[category]) != len(paths):
            report.error(
                "record_parse_incomplete",
                f"{category} has unreadable or undeclared records.",
                METADATA_FILE,
            )

    species_records = loaded.get("species", [])
    default_records = loaded.get("defaultPokemon", [])
    form_records = loaded.get("formPokemon", [])
    expected_pokemon_records = expected_counts.get("pokemonRecords")
    actual_pokemon_records = len(default_records) + len(form_records)
    if expected_pokemon_records != actual_pokemon_records:
        report.error(
            "pokemon_record_count_mismatch",
            f"Expected {expected_pokemon_records} Pokémon records; found "
            f"{actual_pokemon_records}.",
        )
    species_ids: set[int] = set()
    for record in species_records:
        try:
            species_ids.add(int(record.get("id", -1)))
        except (TypeError, ValueError):
            report.error(
                "species_id_invalid",
                f"Species id {record.get('id')!r} is not numeric.",
            )
    catalog = metadata.get("catalog", {})
    if not isinstance(catalog, dict):
        report.error("catalog_invalid", "catalog must be an object.")
        catalog = {}
    if catalog.get("speciesCount") != len(species_ids):
        report.error(
            "catalog_species_count_mismatch",
            f"Catalog expected {catalog.get('speciesCount')} species; found "
            f"{len(species_ids)}.",
        )
    if species_ids and catalog.get("highestNationalDexNumber") != max(species_ids):
        report.error(
            "catalog_highest_id_mismatch",
            "Catalog highest National Pokédex number does not match records.",
        )
    default_species_ids: set[int] = set()
    for record in default_records:
        try:
            default_species_ids.add(stable_id_from_url(record["species"]["url"]))
            for key in ("name", "types", "abilities", "moves", "sprites"):
                if key not in record:
                    raise KeyError(key)
        except (KeyError, TypeError, ValueError) as error:
            report.error(
                "pokemon_record_invalid",
                f"Default Pokémon record lacks required data: {error}.",
            )
    missing_defaults = sorted(species_ids - default_species_ids)
    if missing_defaults:
        report.error(
            "species_default_missing",
            f"Species lack default Pokémon records: {missing_defaults[:10]}.",
        )
    unexpected_defaults = sorted(default_species_ids - species_ids)
    if unexpected_defaults:
        report.error(
            "pokemon_species_missing",
            f"Default Pokémon records lack species records: "
            f"{unexpected_defaults[:10]}.",
        )

    for record in species_records:
        try:
            stable_id_from_url(record["evolution_chain"]["url"])
            if not record["varieties"]:
                raise ValueError("varieties is empty")
        except (KeyError, TypeError, ValueError) as error:
            report.error(
                "species_record_invalid",
                f"Species {record.get('id')!r} lacks required data: {error}.",
            )

    ability_ids: set[int] = set()
    type_names: set[str] = set()
    for record in default_records + form_records:
        for ability in record.get("abilities", []):
            try:
                ability_ids.add(stable_id_from_url(ability["ability"]["url"]))
            except (KeyError, TypeError, ValueError):
                report.error(
                    "ability_reference_invalid",
                    f"Pokémon {record.get('id')!r} has an invalid ability reference.",
                )
        for item in record.get("types", []):
            try:
                type_names.add(item["type"]["name"])
            except (KeyError, TypeError):
                report.error(
                    "type_reference_invalid",
                    f"Pokémon {record.get('id')!r} has an invalid type reference.",
                )
    if expected_counts.get("abilities") != len(ability_ids):
        report.error(
            "ability_count_mismatch",
            f"Expected {expected_counts.get('abilities')} abilities; found "
            f"{len(ability_ids)}.",
        )
    if expected_counts.get("types") != len(type_names):
        report.error(
            "type_count_mismatch",
            f"Expected {expected_counts.get('types')} types; found {len(type_names)}.",
        )

    critical = metadata.get("criticalRecords", {})
    if not isinstance(critical, dict):
        report.error(
            "critical_records_invalid",
            "criticalRecords must be an object.",
        )
        critical = {}
    critical_species = set(critical.get("speciesIds", []))
    if not critical_species.issubset(species_ids):
        report.error(
            "critical_species_missing",
            f"Missing critical species: {sorted(critical_species - species_ids)}.",
        )
    evolution_ids: set[int] = set()
    for record in loaded.get("evolutionChains", []):
        try:
            evolution_ids.add(int(record.get("id", -1)))
        except (TypeError, ValueError):
            report.error(
                "evolution_id_invalid",
                f"Evolution-chain id {record.get('id')!r} is not numeric.",
            )
    required_evolution_ids: set[int] = set()
    for record in species_records:
        try:
            required_evolution_ids.add(
                stable_id_from_url(record["evolution_chain"]["url"])
            )
        except (KeyError, TypeError, ValueError):
            continue
    missing_evolutions = sorted(required_evolution_ids - evolution_ids)
    if missing_evolutions:
        report.error(
            "required_evolution_missing",
            f"Species reference missing evolution chains: "
            f"{missing_evolutions[:10]}.",
        )
    critical_evolutions = set(critical.get("evolutionChainIds", []))
    if not critical_evolutions.issubset(evolution_ids):
        report.error(
            "critical_evolution_missing",
            "Missing critical evolution chains: "
            f"{sorted(critical_evolutions - evolution_ids)}.",
        )
    critical_types = set(critical.get("types", []))
    if not critical_types.issubset(type_names):
        report.error(
            "critical_type_missing",
            f"Missing critical types: {sorted(critical_types - type_names)}.",
        )
    if critical_types == POKEMON_TYPES and len(type_names) != len(POKEMON_TYPES):
        report.error("type_catalog_incomplete", "Full Pokémon type set is incomplete.")

    form_names = {
        str(record.get("name"))
        for record in form_records
        if record.get("name") is not None
    }
    required_form_names = {
        variety["pokemon"]["name"]
        for record in species_records
        for variety in record.get("varieties", [])
        if isinstance(variety, dict)
        and isinstance(variety.get("pokemon"), dict)
        and form_category(str(variety["pokemon"].get("name", ""))) is not None
    }
    missing_forms = sorted(required_form_names - form_names)
    if missing_forms:
        report.error(
            "required_form_missing",
            f"Species reference missing form records: {missing_forms[:10]}.",
        )

    move_ids: set[int] = set()
    for record in loaded.get("moves", []):
        try:
            move_ids.add(int(record["id"]))
        except (KeyError, TypeError, ValueError):
            report.error(
                "move_id_invalid",
                f"Move id {record.get('id')!r} is not numeric.",
            )
    required_move_ids: set[int] = set()
    for record in default_records:
        try:
            species_id = stable_id_from_url(record["species"]["url"])
        except (KeyError, TypeError, ValueError):
            continue
        for move in record["moves"]:
            try:
                if selected_move_detail(species_id, move) is not None:
                    required_move_ids.add(stable_id_from_url(move["move"]["url"]))
            except (KeyError, TypeError, ValueError):
                report.error(
                    "move_reference_invalid",
                    f"Pokémon {record.get('id')!r} has an invalid move reference.",
                )
    missing_moves = sorted(required_move_ids - move_ids)
    if missing_moves:
        report.error(
            "required_move_missing",
            f"Pokémon reference missing move records: {missing_moves[:10]}.",
        )

    mapping_relative = metadata.get("artworkMappingsFile")
    mappings: list[dict[str, Any]] = []
    if not isinstance(mapping_relative, str) or mapping_relative not in parsed_json:
        report.error(
            "artwork_mapping_missing",
            "Artwork mapping file is missing or unreadable.",
        )
    else:
        mapping_value = parsed_json[mapping_relative].get("mappings")
        if not isinstance(mapping_value, list):
            report.error(
                "artwork_mapping_invalid",
                "Artwork mapping must contain a mappings list.",
                mapping_relative,
            )
        else:
            mappings = mapping_value

    artwork_counts = {"base": 0, "forms": 0}
    mapping_keys: set[tuple[str, str]] = set()
    for mapping in mappings:
        try:
            category = mapping["category"]
            identifier = str(mapping["id"])
            source_path = mapping["snapshotPath"]
            output_asset = mapping["outputAsset"]
        except (KeyError, TypeError) as error:
            report.error(
                "artwork_mapping_invalid",
                f"Artwork mapping lacks {error}.",
                mapping_relative if isinstance(mapping_relative, str) else None,
            )
            continue
        key = (category, identifier)
        if key in mapping_keys:
            report.error(
                "duplicate_artwork_mapping",
                f"Artwork mapping {key} is duplicated.",
                mapping_relative,
            )
        mapping_keys.add(key)
        if category not in artwork_counts:
            report.error(
                "artwork_category_invalid",
                f"Unknown artwork category {category!r}.",
                mapping_relative,
            )
            continue
        artwork_counts[category] += 1
        if not isinstance(source_path, str) or not safe_relative_path(source_path):
            report.error(
                "artwork_path_invalid",
                f"Unsafe artwork path {source_path!r}.",
                mapping_relative,
            )
            continue
        artwork = snapshot / source_path
        if not artwork.is_file():
            report.error(
                "artwork_missing",
                f"Mapped artwork for {key} is missing.",
                source_path,
            )
        elif not is_png(artwork):
            report.error(
                "artwork_invalid",
                f"Mapped artwork for {key} is not a readable PNG.",
                source_path,
            )
        if not isinstance(output_asset, str) or not output_asset.startswith("assets/"):
            report.error(
                "output_asset_invalid",
                f"Invalid application asset path {output_asset!r}.",
                mapping_relative,
            )

    expected_artwork = expected_counts.get("artwork", {})
    if not isinstance(expected_artwork, dict):
        report.error(
            "expected_artwork_counts_invalid",
            "expectedCounts.artwork must be an object.",
        )
        expected_artwork = {}
    for category, actual in artwork_counts.items():
        if expected_artwork.get(category) != actual:
            report.error(
                "artwork_count_mismatch",
                f"{category} artwork expected {expected_artwork.get(category)}; "
                f"found {actual}.",
            )

    for omission in metadata.get("knownOmissions", []):
        report.warning("known_omission", str(omission))
    for correction in metadata.get("manualCorrections", []):
        report.warning("manual_correction", str(correction))
    for source in metadata.get("sources", []):
        if not isinstance(source, dict):
            report.warning(
                "source_metadata_invalid",
                "Source metadata entry is not an object.",
            )
        elif not source.get("revision"):
            report.warning(
                "source_revision_unavailable",
                f"No immutable upstream revision recorded for {source.get('name')}.",
            )

    if metadata.get("encounterGuideSource") is not None:
        try:
            from .encounters import encounter_source_facts

            report.facts["encounterGuide"] = encounter_source_facts(
                snapshot,
                metadata,
                Path(__file__).with_name("lets_go_progression.json"),
            )
        except (OSError, KeyError, TypeError, ValueError, RuntimeError) as error:
            report.error("encounter_source_invalid", str(error))

    report.facts.update(
        {
            "snapshotId": snapshot_id,
            "snapshotFormatVersion": metadata.get("snapshotFormatVersion"),
            "declaredFiles": len(declared_paths),
            "species": len(species_records),
            "defaultPokemon": len(default_records),
            "forms": len(loaded.get("formPokemon", [])),
            "moves": len(loaded.get("moves", [])),
            "evolutionChains": len(loaded.get("evolutionChains", [])),
            "abilities": len(ability_ids),
            "types": sorted(type_names),
            "artwork": artwork_counts,
        }
    )
    return report


def require_valid_snapshot(snapshot: Path) -> tuple[dict[str, Any], ValidationReport]:
    report = validate_snapshot(snapshot)
    if not report.valid:
        raise SnapshotValidationError(report)
    return read_snapshot_metadata(snapshot), report
