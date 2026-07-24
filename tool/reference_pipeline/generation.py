from __future__ import annotations

import hashlib
import json
import os
import shutil
import socket
import sqlite3
import subprocess
import uuid
from contextlib import AbstractContextManager
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

from . import GENERATOR_VERSION
from .common import (
    english,
    form_category,
    is_png,
    load_json,
    safe_relative_path,
    selected_move_detail,
    sha256_file,
    stable_id_from_url,
    title,
    walk_chain,
    write_json,
)
from .snapshot import (
    SnapshotValidationError,
    ValidationReport,
    read_snapshot_metadata,
    require_valid_snapshot,
)

CONTENT_TABLES = (
    "species",
    "species_types",
    "species_abilities",
    "species_stats",
    "species_moves",
    "forms",
    "form_types",
    "evolution_edges",
)
EXPECTED_TABLES = ("metadata", *CONTENT_TABLES)
EXPECTED_COLUMNS = {
    "metadata": {"key", "value"},
    "species": {
        "id",
        "dex_number",
        "name",
        "classification",
        "description",
        "height_m",
        "weight_kg",
        "generation",
    },
    "species_types": {"species_id", "slot", "type_name"},
    "species_abilities": {"species_id", "slot", "ability_name"},
    "species_stats": {"species_id", "stat_name", "base_value"},
    "species_moves": {
        "species_id",
        "move_name",
        "move_type",
        "learn_method",
        "level_learned",
    },
    "forms": {
        "id",
        "species_id",
        "name",
        "category",
        "note",
        "is_battle_only",
        "artwork_asset",
    },
    "form_types": {"form_id", "slot", "type_name"},
    "evolution_edges": {
        "id",
        "family_id",
        "from_species_id",
        "to_species_id",
        "condition_text",
        "sort_order",
    },
}


class GenerationError(RuntimeError):
    pass


class OfflineNetworkGuard(AbstractContextManager["OfflineNetworkGuard"]):
    def __init__(self) -> None:
        self._connect = socket.socket.connect
        self._connect_ex = socket.socket.connect_ex
        self._create_connection = socket.create_connection

    @staticmethod
    def _blocked(*_: Any, **__: Any) -> Any:
        raise GenerationError(
            "Network access attempted during deterministic offline generation."
        )

    def __enter__(self) -> "OfflineNetworkGuard":
        socket.socket.connect = self._blocked
        socket.socket.connect_ex = self._blocked
        socket.create_connection = self._blocked
        os.environ["POKEMON_REFERENCE_OFFLINE"] = "1"
        return self

    def __exit__(self, *args: Any) -> None:
        socket.socket.connect = self._connect
        socket.socket.connect_ex = self._connect_ex
        socket.create_connection = self._create_connection
        os.environ.pop("POKEMON_REFERENCE_OFFLINE", None)


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _load_record_index(
    snapshot: Path,
    metadata: dict[str, Any],
    category: str,
) -> list[dict[str, Any]]:
    return [load_json(snapshot / path) for path in metadata["records"][category]]


def _database_schema(database: sqlite3.Connection) -> None:
    database.executescript(
        """
        PRAGMA foreign_keys=ON;
        CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
        CREATE TABLE species (
          id INTEGER PRIMARY KEY,
          dex_number INTEGER NOT NULL UNIQUE,
          name TEXT NOT NULL,
          classification TEXT NOT NULL,
          description TEXT NOT NULL,
          height_m REAL NOT NULL,
          weight_kg REAL NOT NULL,
          generation INTEGER NOT NULL
        );
        CREATE TABLE species_types (
          species_id INTEGER NOT NULL,
          slot INTEGER NOT NULL,
          type_name TEXT NOT NULL,
          PRIMARY KEY(species_id,slot),
          FOREIGN KEY(species_id) REFERENCES species(id)
        );
        CREATE TABLE species_abilities (
          species_id INTEGER NOT NULL,
          slot INTEGER NOT NULL,
          ability_name TEXT NOT NULL,
          PRIMARY KEY(species_id,slot),
          FOREIGN KEY(species_id) REFERENCES species(id)
        );
        CREATE TABLE species_stats (
          species_id INTEGER NOT NULL,
          stat_name TEXT NOT NULL,
          base_value INTEGER NOT NULL,
          PRIMARY KEY(species_id,stat_name),
          FOREIGN KEY(species_id) REFERENCES species(id)
        );
        CREATE TABLE species_moves (
          species_id INTEGER NOT NULL,
          move_name TEXT NOT NULL,
          move_type TEXT NOT NULL,
          learn_method TEXT NOT NULL,
          level_learned INTEGER NOT NULL,
          PRIMARY KEY(species_id,move_name,learn_method),
          FOREIGN KEY(species_id) REFERENCES species(id)
        );
        CREATE TABLE forms (
          id TEXT PRIMARY KEY,
          species_id INTEGER NOT NULL,
          name TEXT NOT NULL,
          category TEXT NOT NULL,
          note TEXT NOT NULL,
          is_battle_only INTEGER NOT NULL DEFAULT 0,
          artwork_asset TEXT NOT NULL,
          FOREIGN KEY(species_id) REFERENCES species(id)
        );
        CREATE TABLE form_types (
          form_id TEXT NOT NULL,
          slot INTEGER NOT NULL,
          type_name TEXT NOT NULL,
          PRIMARY KEY(form_id,slot),
          FOREIGN KEY(form_id) REFERENCES forms(id)
        );
        CREATE TABLE evolution_edges (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          family_id TEXT NOT NULL,
          from_species_id INTEGER NOT NULL,
          to_species_id INTEGER NOT NULL,
          condition_text TEXT NOT NULL,
          sort_order INTEGER NOT NULL,
          FOREIGN KEY(from_species_id) REFERENCES species(id),
          FOREIGN KEY(to_species_id) REFERENCES species(id)
        );
        """
    )


def _build_database(
    *,
    snapshot: Path,
    metadata: dict[str, Any],
    database_path: Path,
    dataset_version: int,
    content_schema: int,
    display_name: str,
    production_approved: bool,
) -> dict[str, int]:
    species_records = sorted(
        _load_record_index(snapshot, metadata, "species"),
        key=lambda record: int(record["id"]),
    )
    default_records = {
        stable_id_from_url(record["species"]["url"]): record
        for record in _load_record_index(snapshot, metadata, "defaultPokemon")
    }
    form_records = {
        record["name"]: record
        for record in _load_record_index(snapshot, metadata, "formPokemon")
    }
    move_records = {
        int(record["id"]): record
        for record in _load_record_index(snapshot, metadata, "moves")
    }
    evolution_records = {
        int(record["id"]): record
        for record in _load_record_index(snapshot, metadata, "evolutionChains")
    }
    artwork_mapping = load_json(
        snapshot / metadata["artworkMappingsFile"]
    )["mappings"]
    form_artwork = {
        mapping["id"]: mapping["outputAsset"]
        for mapping in artwork_mapping
        if mapping["category"] == "forms"
    }

    species_rows: list[tuple[Any, ...]] = []
    type_rows: list[tuple[Any, ...]] = []
    ability_rows: list[tuple[Any, ...]] = []
    stat_rows: list[tuple[Any, ...]] = []
    move_rows: list[tuple[Any, ...]] = []
    form_rows: list[tuple[Any, ...]] = []
    form_type_rows: list[tuple[Any, ...]] = []
    evolution_by_url: dict[str, str] = {}

    for species in species_records:
        species_id = int(species["id"])
        pokemon = default_records[species_id]
        genus = english(species["genera"], "genus")
        description = english(
            species["flavor_text_entries"],
            "flavor_text",
            "lets-go-pikachu",
        )
        if not description:
            description = english(species["flavor_text_entries"], "flavor_text")
        species_rows.append(
            (
                species_id,
                species_id,
                title(species["name"]),
                genus,
                description,
                pokemon["height"] / 10,
                pokemon["weight"] / 10,
                stable_id_from_url(species["generation"]["url"]),
            )
        )
        for item in pokemon["types"]:
            type_rows.append(
                (species_id, item["slot"], title(item["type"]["name"]))
            )
        for item in pokemon["abilities"]:
            ability_rows.append(
                (species_id, item["slot"], title(item["ability"]["name"]))
            )
        for item in pokemon["stats"]:
            stat_rows.append(
                (species_id, item["stat"]["name"], item["base_stat"])
            )
        for item in pokemon["moves"]:
            detail = selected_move_detail(species_id, item)
            if detail is None:
                continue
            move_id = stable_id_from_url(item["move"]["url"])
            move_record = move_records[move_id]
            move_rows.append(
                (
                    species_id,
                    title(item["move"]["name"]),
                    title(move_record["type"]["name"]),
                    detail["move_learn_method"]["name"],
                    detail["level_learned_at"],
                )
            )
        evolution_by_url[species["evolution_chain"]["url"]] = (
            f"family-{species_id}"
        )
        for variety in species["varieties"]:
            name = variety["pokemon"]["name"]
            category_details = form_category(name)
            if category_details is None:
                continue
            form = form_records[name]
            category, note, battle_only = category_details
            form_rows.append(
                (
                    name,
                    species_id,
                    title(name),
                    category,
                    note,
                    int(battle_only),
                    form_artwork[name],
                )
            )
            for item in form["types"]:
                form_type_rows.append(
                    (name, item["slot"], title(item["type"]["name"]))
                )

    edges: list[tuple[str, int, int, str, int]] = []
    for url, family in evolution_by_url.items():
        chain_id = stable_id_from_url(url)
        walk_chain(evolution_records[chain_id]["chain"], family, edges)
    valid_species = {int(record["id"]) for record in species_records}
    edges = [
        edge
        for edge in edges
        if edge[1] in valid_species and edge[2] in valid_species
    ]

    counts = {
        "species": len(species_rows),
        "forms": len(form_rows),
        "evolutionEdges": len(edges),
        "moveLearningLinks": len(move_rows),
        "baseArtwork": metadata["expectedCounts"]["artwork"]["base"],
        "formArtwork": metadata["expectedCounts"]["artwork"]["forms"],
        "highestNationalDexNumber": max(valid_species),
    }
    database_metadata = {
        "dataset_version": str(dataset_version),
        "content_schema": str(content_schema),
        "display_name": display_name,
        "production_approved": str(production_approved).lower(),
        "game": "National Pokédex with a dedicated Let's Go guide",
        "structured_data_source": "PokeAPI (BSD-3-Clause)",
        "artwork_notice": (
            "Artwork © The Pokémon Company. Private family use only."
        ),
        "retrieved_at": metadata["sourceAcquiredAtUtc"],
        "source_snapshot_id": metadata["snapshotId"],
        "generation_timestamp": metadata["createdAtUtc"],
        "generator_version": GENERATOR_VERSION,
        "species_count": str(counts["species"]),
        "form_count": str(counts["forms"]),
        "evolution_edge_count": str(counts["evolutionEdges"]),
        "move_learning_link_count": str(counts["moveLearningLinks"]),
        "base_artwork_count": str(counts["baseArtwork"]),
        "form_artwork_count": str(counts["formArtwork"]),
        "highest_national_dex_number": str(
            counts["highestNationalDexNumber"]
        ),
        "languages": ",".join(metadata["languages"]),
    }

    database_path.parent.mkdir(parents=True, exist_ok=True)
    database = sqlite3.connect(database_path)
    try:
        _database_schema(database)
        database.executemany("INSERT INTO metadata VALUES (?,?)", database_metadata.items())
        database.executemany("INSERT INTO species VALUES (?,?,?,?,?,?,?,?)", species_rows)
        database.executemany("INSERT INTO species_types VALUES (?,?,?)", type_rows)
        database.executemany(
            "INSERT INTO species_abilities VALUES (?,?,?)", ability_rows
        )
        database.executemany("INSERT INTO species_stats VALUES (?,?,?)", stat_rows)
        database.executemany("INSERT INTO species_moves VALUES (?,?,?,?,?)", move_rows)
        database.executemany("INSERT INTO forms VALUES (?,?,?,?,?,?,?)", form_rows)
        database.executemany("INSERT INTO form_types VALUES (?,?,?)", form_type_rows)
        database.executemany(
            """
            INSERT INTO evolution_edges(
              family_id,from_species_id,to_species_id,condition_text,sort_order
            ) VALUES (?,?,?,?,?)
            """,
            edges,
        )
        database.commit()
    finally:
        database.close()
    return counts


def _copy_artwork(
    snapshot: Path,
    metadata: dict[str, Any],
    output: Path,
) -> None:
    mappings = load_json(snapshot / metadata["artworkMappingsFile"])["mappings"]
    copied: set[str] = set()
    for mapping in mappings:
        output_asset = mapping["outputAsset"]
        if output_asset in copied:
            continue
        copied.add(output_asset)
        if output_asset.startswith("assets/artwork/"):
            target = output / "artwork" / Path(output_asset).name
        elif output_asset.startswith("assets/form_artwork/"):
            target = output / "form_artwork" / Path(output_asset).name
        else:
            raise GenerationError(f"Unsupported output artwork path: {output_asset}")
        source = snapshot / mapping["snapshotPath"]
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)


def _database_rows(
    database: sqlite3.Connection,
    table: str,
) -> tuple[list[str], list[list[Any]]]:
    columns = [
        row[1]
        for row in database.execute(f"PRAGMA table_info({table})").fetchall()
    ]
    logical_columns = [
        column
        for column in columns
        if not (table == "evolution_edges" and column == "id")
    ]
    select = ",".join(f'"{column}"' for column in logical_columns)
    rows = [list(row) for row in database.execute(f"SELECT {select} FROM {table}")]
    rows.sort(key=lambda row: json.dumps(row, ensure_ascii=False, sort_keys=True))
    return logical_columns, rows


def logical_database_fingerprint(database_path: Path) -> dict[str, Any]:
    database = sqlite3.connect(f"file:{database_path.as_posix()}?mode=ro", uri=True)
    try:
        tables: dict[str, Any] = {}
        overall = hashlib.sha256()
        for table in CONTENT_TABLES:
            columns, rows = _database_rows(database, table)
            payload = json.dumps(
                {"columns": columns, "rows": rows},
                ensure_ascii=False,
                sort_keys=True,
                separators=(",", ":"),
            ).encode()
            digest = hashlib.sha256(payload).hexdigest()
            overall.update(table.encode())
            overall.update(digest.encode())
            tables[table] = {"rows": len(rows), "sha256": digest}
        return {"sha256": overall.hexdigest(), "tables": tables}
    finally:
        database.close()


def compare_databases(candidate: Path, existing: Path) -> dict[str, Any]:
    candidate_value = logical_database_fingerprint(candidate)
    existing_value = logical_database_fingerprint(existing)
    table_comparison: dict[str, Any] = {}
    changed_tables: list[str] = []
    for table in CONTENT_TABLES:
        candidate_table = candidate_value["tables"][table]
        existing_table = existing_value["tables"][table]
        changed = candidate_table != existing_table
        if changed:
            changed_tables.append(table)
        table_comparison[table] = {
            "changed": changed,
            "existingRows": existing_table["rows"],
            "candidateRows": candidate_table["rows"],
            "rowDifference": candidate_table["rows"] - existing_table["rows"],
            "existingSha256": existing_table["sha256"],
            "candidateSha256": candidate_table["sha256"],
        }
    return {
        "comparisonScope": "ordered logical content rows",
        "excludedTables": ["metadata"],
        "logicallyEquivalent": not changed_tables,
        "changedTables": changed_tables,
        "existingLogicalSha256": existing_value["sha256"],
        "candidateLogicalSha256": candidate_value["sha256"],
        "tables": table_comparison,
    }


def comparison_markdown(comparison: dict[str, Any]) -> str:
    lines = [
        "# Reference dataset comparison",
        "",
        "Result: "
        + (
            "LOGICALLY EQUIVALENT"
            if comparison["logicallyEquivalent"]
            else "CONTENT CHANGED"
        ),
        "",
        f"Existing logical SHA-256: `{comparison['existingLogicalSha256']}`",
        f"Candidate logical SHA-256: `{comparison['candidateLogicalSha256']}`",
        "Excluded table: `metadata` (provenance fields intentionally differ)",
        "",
        "| Table | Existing | Candidate | Difference | Changed |",
        "| --- | ---: | ---: | ---: | --- |",
    ]
    for table, value in comparison["tables"].items():
        lines.append(
            f"| `{table}` | {value['existingRows']} | "
            f"{value['candidateRows']} | {value['rowDifference']} | "
            f"{'yes' if value['changed'] else 'no'} |"
        )
    return "\n".join(lines) + "\n"


def _row_count(database: sqlite3.Connection, table: str) -> int:
    return int(database.execute(f"SELECT COUNT(*) FROM {table}").fetchone()[0])


def validate_generated_output(output: Path) -> ValidationReport:
    output = output.resolve()
    report = ValidationReport(subject=str(output))
    database_path = output / "content" / "demo_reference.sqlite"
    manifest_path = output / "content" / "demo_manifest.json"
    complete_path = output / ".complete"
    checksums_path = output / "reports" / "checksums.json"
    for path, code in (
        (database_path, "database_missing"),
        (manifest_path, "manifest_missing"),
        (complete_path, "output_incomplete"),
        (checksums_path, "checksums_missing"),
    ):
        if not path.is_file():
            report.error(code, f"Required generated file is missing: {path.name}")
    if report.errors:
        return report

    try:
        manifest = load_json(manifest_path)
        complete = load_json(complete_path)
        checksums = load_json(checksums_path)
    except (OSError, ValueError, json.JSONDecodeError) as error:
        report.error("generated_json_invalid", str(error))
        return report

    if complete.get("manifestSha256") != sha256_file(manifest_path):
        report.error(
            "generated_manifest_checksum_mismatch",
            "Completion marker does not match generated manifest.",
        )
    if complete.get("databaseSha256") != sha256_file(database_path):
        report.error(
            "generated_database_checksum_mismatch",
            "Completion marker does not match generated database.",
        )
    if manifest.get("databaseSha256") != sha256_file(database_path):
        report.error(
            "generated_manifest_database_checksum_mismatch",
            "Generated manifest does not match generated database.",
        )
    checksum_entries = checksums.get("files", [])
    if not isinstance(checksum_entries, list):
        report.error(
            "generated_checksum_inventory_invalid",
            "Generated checksum inventory must contain a files list.",
        )
        return report
    declared_files: set[str] = set()
    for entry in checksum_entries:
        if not isinstance(entry, dict):
            report.error(
                "generated_checksum_entry_invalid",
                "Generated checksum entry must be an object.",
            )
            continue
        relative = entry.get("path")
        if not isinstance(relative, str) or not safe_relative_path(relative):
            report.error("generated_checksum_entry_invalid", "Invalid checksum path.")
            continue
        if relative in declared_files:
            report.error(
                "generated_checksum_entry_duplicate",
                "Generated checksum path is duplicated.",
                relative,
            )
            continue
        declared_files.add(relative)
        path = output / relative
        if not path.is_file():
            report.error("generated_file_missing", "Checksummed file is missing.", relative)
        elif path.stat().st_size != entry.get("size"):
            report.error(
                "generated_file_size_mismatch",
                "Generated file size does not match checksum inventory.",
                relative,
            )
        elif sha256_file(path) != entry.get("sha256"):
            report.error(
                "generated_file_checksum_mismatch",
                "Generated file checksum mismatch.",
                relative,
            )
    actual_files = {
        path.relative_to(output).as_posix()
        for path in output.rglob("*")
        if path.is_file()
    } - {".complete", "reports/checksums.json"}
    unchecksummed = actual_files - declared_files
    if unchecksummed:
        report.error(
            "generated_files_unchecksummed",
            f"Generated files are absent from checksum inventory: "
            f"{sorted(unchecksummed)[:10]}.",
        )

    database = sqlite3.connect(f"file:{database_path.as_posix()}?mode=ro", uri=True)
    try:
        integrity = database.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            report.error("sqlite_integrity_failed", str(integrity))
        foreign_keys = database.execute("PRAGMA foreign_key_check").fetchall()
        if foreign_keys:
            report.error(
                "sqlite_foreign_keys_failed",
                f"Foreign-key check returned {len(foreign_keys)} row(s).",
            )
        actual_tables = {
            row[0]
            for row in database.execute(
                "SELECT name FROM sqlite_master WHERE type='table'"
            )
            if not row[0].startswith("sqlite_")
        }
        missing_tables = set(EXPECTED_TABLES) - actual_tables
        if missing_tables:
            report.error(
                "generated_tables_missing",
                f"Missing tables: {sorted(missing_tables)}.",
            )
            return report
        missing_columns = {}
        for table, expected in EXPECTED_COLUMNS.items():
            actual = {
                row[1]
                for row in database.execute(f"PRAGMA table_info({table})")
            }
            missing = expected - actual
            if missing:
                missing_columns[table] = sorted(missing)
        if missing_columns:
            report.error(
                "generated_columns_missing",
                f"Missing required columns: {missing_columns}.",
            )
            return report
        counts = {
            "species": _row_count(database, "species"),
            "forms": _row_count(database, "forms"),
            "evolutionEdges": _row_count(database, "evolution_edges"),
            "moveLearningLinks": _row_count(database, "species_moves"),
            "baseArtwork": len(list((output / "artwork").glob("*.png"))),
            "formArtwork": len(list((output / "form_artwork").glob("*.png"))),
        }
        manifest_counts = manifest.get("semanticCounts", {})
        for key, actual in counts.items():
            if manifest_counts.get(key) != actual:
                report.error(
                    "generated_count_mismatch",
                    f"{key} manifest value {manifest_counts.get(key)} != {actual}.",
                )
        db_metadata = dict(database.execute("SELECT key,value FROM metadata"))
        for manifest_key, database_key in (
            ("datasetVersion", "dataset_version"),
            ("contentSchema", "content_schema"),
            ("sourceSnapshotId", "source_snapshot_id"),
            ("generatorVersion", "generator_version"),
        ):
            if str(manifest.get(manifest_key)) != db_metadata.get(database_key):
                report.error(
                    "generated_metadata_mismatch",
                    f"{manifest_key} does not match database {database_key}.",
                )
        invalid_base = [
            row[0]
            for row in database.execute("SELECT dex_number FROM species")
            if not is_png(output / "artwork" / f"{row[0]}.png")
        ]
        if invalid_base:
            report.error(
                "generated_base_artwork_invalid",
                f"Missing or invalid base artwork: {invalid_base[:10]}.",
            )
        missing_forms = []
        for (asset,) in database.execute("SELECT artwork_asset FROM forms"):
            if asset.startswith("assets/form_artwork/"):
                artwork = output / "form_artwork" / Path(asset).name
            else:
                artwork = output / "artwork" / Path(asset).name
            if not artwork.is_file() or not is_png(artwork):
                missing_forms.append(asset)
        if missing_forms:
            report.error(
                "generated_form_artwork_invalid",
                f"Missing or invalid form artwork: {missing_forms[:10]}.",
            )
    except sqlite3.DatabaseError as error:
        report.error("sqlite_unreadable", str(error))
        return report
    finally:
        database.close()

    report.facts.update(
        {
            "databaseSha256": sha256_file(database_path),
            "logicalDatabase": logical_database_fingerprint(database_path),
            "semanticCounts": manifest.get("semanticCounts"),
            "sourceSnapshotId": manifest.get("sourceSnapshotId"),
            "generatorVersion": manifest.get("generatorVersion"),
        }
    )
    return report


def _repo_revision(root: Path) -> str | None:
    try:
        return subprocess.run(
            ["git", "rev-parse", "HEAD"],
            cwd=root,
            check=True,
            capture_output=True,
            text=True,
        ).stdout.strip()
    except (OSError, subprocess.CalledProcessError):
        return None


def _write_checksums(output: Path) -> None:
    excluded = {
        "reports/checksums.json",
        ".complete",
    }
    files = []
    for path in sorted(output.rglob("*")):
        if not path.is_file():
            continue
        relative = path.relative_to(output).as_posix()
        if relative in excluded:
            continue
        files.append(
            {
                "path": relative,
                "size": path.stat().st_size,
                "sha256": sha256_file(path),
            }
        )
    write_json(output / "reports" / "checksums.json", {"files": files})


def build_reference_data(
    *,
    root: Path,
    snapshot: Path,
    output: Path,
    dataset_version: int,
    content_schema: int,
    display_name: str,
    production_approved: bool,
    replace_output: bool = False,
    allow_snapshot_warnings: bool = False,
    compare_to: Path | None = None,
) -> tuple[Path, ValidationReport, dict[str, Any] | None]:
    snapshot = snapshot.resolve()
    output = output.resolve()
    metadata, snapshot_report = require_valid_snapshot(snapshot)
    if snapshot_report.warnings and not allow_snapshot_warnings:
        raise GenerationError(
            snapshot_report.to_markdown()
            + "\nReview snapshot warnings and rerun with "
            "--allow-snapshot-warnings.\n"
        )
    if output.exists() and not replace_output:
        raise GenerationError(
            f"Output already exists: {output}. Use --replace-output after review."
        )

    output.parent.mkdir(parents=True, exist_ok=True)
    temporary = output.parent / f".{output.name}.incomplete-{uuid.uuid4().hex}"
    temporary.mkdir()
    comparison: dict[str, Any] | None = None
    try:
        with OfflineNetworkGuard():
            _copy_artwork(snapshot, metadata, temporary)
            database_path = temporary / "content" / "demo_reference.sqlite"
            counts = _build_database(
                snapshot=snapshot,
                metadata=metadata,
                database_path=database_path,
                dataset_version=dataset_version,
                content_schema=content_schema,
                display_name=display_name,
                production_approved=production_approved,
            )
            manifest = {
                "manifestVersion": 1,
                "channel": "development",
                "datasetVersion": dataset_version,
                "contentSchema": content_schema,
                "displayName": display_name,
                "productionApproved": production_approved,
                "message": "National Pokédex data is current.",
                "sourceSnapshotId": metadata["snapshotId"],
                "generatorVersion": GENERATOR_VERSION,
                "generatedAtUtc": metadata["createdAtUtc"],
                "languages": metadata["languages"],
                "semanticCounts": counts,
                "databaseSha256": sha256_file(database_path),
            }
            manifest_path = temporary / "content" / "demo_manifest.json"
            write_json(manifest_path, manifest)
            write_json(temporary / "reports" / "semantic_counts.json", counts)
            provenance = {
                "sourceSnapshotId": metadata["snapshotId"],
                "snapshotFormatVersion": metadata["snapshotFormatVersion"],
                "snapshotMetadataSha256": sha256_file(snapshot / "snapshot.json"),
                "generatorVersion": GENERATOR_VERSION,
                "generatorRepositoryRevision": _repo_revision(root),
                "deterministicGenerationTimestamp": metadata["createdAtUtc"],
                "buildExecutedAtUtc": _utc_now(),
                "networkAccess": "blocked",
                "sources": metadata["sources"],
                "languages": metadata["languages"],
            }
            write_json(
                temporary / "reports" / "source_provenance.json",
                provenance,
            )
            preliminary = _validate_database_without_completion(temporary, manifest)
            if not preliminary.valid:
                raise GenerationError(preliminary.to_markdown())
            write_json(
                temporary / "reports" / "validation.json",
                preliminary.to_dict(),
            )
            (temporary / "reports" / "validation.md").write_text(
                preliminary.to_markdown(),
                encoding="utf-8",
            )
            if compare_to is not None:
                comparison = compare_databases(database_path, compare_to.resolve())
                write_json(
                    temporary / "reports" / "comparison.json",
                    comparison,
                )
                (temporary / "reports" / "comparison.md").write_text(
                    comparison_markdown(comparison),
                    encoding="utf-8",
                )
            _write_checksums(temporary)
            write_json(
                temporary / ".complete",
                {
                    "sourceSnapshotId": metadata["snapshotId"],
                    "manifestSha256": sha256_file(manifest_path),
                    "databaseSha256": sha256_file(database_path),
                },
            )
            final_report = validate_generated_output(temporary)
            if not final_report.valid:
                raise GenerationError(final_report.to_markdown())

        if output.exists():
            backup = output.parent / f".{output.name}.backup-{uuid.uuid4().hex}"
            os.replace(output, backup)
            try:
                os.replace(temporary, output)
            except Exception:
                os.replace(backup, output)
                raise
            shutil.rmtree(backup)
        else:
            os.replace(temporary, output)
        return output, validate_generated_output(output), comparison
    except Exception:
        if temporary.exists():
            shutil.rmtree(temporary)
        raise


def _validate_database_without_completion(
    output: Path,
    manifest: dict[str, Any],
) -> ValidationReport:
    report = ValidationReport(subject=str(output))
    database_path = output / "content" / "demo_reference.sqlite"
    database = sqlite3.connect(database_path)
    try:
        integrity = database.execute("PRAGMA integrity_check").fetchone()[0]
        if integrity != "ok":
            report.error("sqlite_integrity_failed", str(integrity))
        foreign_keys = database.execute("PRAGMA foreign_key_check").fetchall()
        if foreign_keys:
            report.error(
                "sqlite_foreign_keys_failed",
                f"Foreign-key check returned {len(foreign_keys)} row(s).",
            )
        actual = {
            "species": _row_count(database, "species"),
            "forms": _row_count(database, "forms"),
            "evolutionEdges": _row_count(database, "evolution_edges"),
            "moveLearningLinks": _row_count(database, "species_moves"),
            "baseArtwork": len(list((output / "artwork").glob("*.png"))),
            "formArtwork": len(list((output / "form_artwork").glob("*.png"))),
            "highestNationalDexNumber": int(
                database.execute("SELECT MAX(dex_number) FROM species").fetchone()[0]
            ),
        }
        for key, value in actual.items():
            if manifest["semanticCounts"].get(key) != value:
                report.error(
                    "semantic_count_mismatch",
                    f"{key} expected {manifest['semanticCounts'].get(key)}; "
                    f"found {value}.",
                )
        metadata = dict(database.execute("SELECT key,value FROM metadata"))
        if metadata.get("source_snapshot_id") != manifest["sourceSnapshotId"]:
            report.error(
                "source_snapshot_metadata_missing",
                "Database does not identify source snapshot.",
            )
    finally:
        database.close()
    for path in (output / "artwork").glob("*.png"):
        if not is_png(path):
            report.error("base_artwork_invalid", "Invalid PNG.", str(path))
    for path in (output / "form_artwork").glob("*.png"):
        if not is_png(path):
            report.error("form_artwork_invalid", "Invalid PNG.", str(path))
    report.facts["semanticCounts"] = manifest["semanticCounts"]
    return report
