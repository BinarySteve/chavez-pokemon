from __future__ import annotations

import json
import os
import shutil
import time
import urllib.request
import uuid
from concurrent.futures import ThreadPoolExecutor
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Iterable

from . import ACQUISITION_TOOL_VERSION, SNAPSHOT_FORMAT_VERSION
from .common import (
    API_BASE,
    LETS_GO_IDS,
    artwork_candidates,
    cache_key_for_url,
    form_category,
    is_png,
    load_json,
    sha256_file,
    stable_id_from_url,
    write_json,
)
from .snapshot import COMPLETE_FILE, METADATA_FILE, ValidationReport, validate_snapshot


class AcquisitionError(RuntimeError):
    pass


@dataclass(frozen=True)
class AcquiredSnapshot:
    path: Path
    metadata: dict[str, Any]
    report: ValidationReport


class CachedFetcher:
    def __init__(
        self,
        cache_dir: Path,
        *,
        cache_only: bool,
        refresh: bool,
    ):
        self.cache_dir = cache_dir
        self.cache_only = cache_only
        self.refresh = refresh
        self.cache_dir.mkdir(parents=True, exist_ok=True)

    def json(self, url: str) -> tuple[Path, dict[str, Any]]:
        target = self.cache_dir / cache_key_for_url(url)
        if target.is_file() and not self.refresh:
            try:
                return target, load_json(target)
            except (
                OSError,
                UnicodeDecodeError,
                json.JSONDecodeError,
                ValueError,
            ) as error:
                if self.cache_only:
                    raise AcquisitionError(
                        f"Cached JSON is malformed and network is disabled: "
                        f"{target}: {error}"
                    ) from error
        if self.cache_only:
            raise AcquisitionError(
                f"Required acquisition cache entry is missing: {target} ({url})"
            )
        data = self._download(url, timeout=30)
        temporary = target.with_name(f".{target.name}.{uuid.uuid4().hex}.tmp")
        temporary.write_bytes(data)
        try:
            value = load_json(temporary)
        except (
            OSError,
            UnicodeDecodeError,
            json.JSONDecodeError,
            ValueError,
        ) as error:
            temporary.unlink(missing_ok=True)
            raise AcquisitionError(f"Upstream JSON is invalid: {url}: {error}") from error
        os.replace(temporary, target)
        return target, value

    def bytes(self, url: str, target: Path, *, timeout: int = 60) -> Path:
        if target.is_file() and is_png(target) and not self.refresh:
            return target
        if self.cache_only:
            raise AcquisitionError(
                f"Required artwork cache entry is missing or invalid: {target} ({url})"
            )
        data = self._download(url, timeout=timeout)
        temporary = target.with_name(f".{target.name}.{uuid.uuid4().hex}.tmp")
        temporary.parent.mkdir(parents=True, exist_ok=True)
        temporary.write_bytes(data)
        if not is_png(temporary):
            temporary.unlink(missing_ok=True)
            raise AcquisitionError(f"Upstream artwork is not a PNG: {url}")
        os.replace(temporary, target)
        return target

    @staticmethod
    def _download(url: str, *, timeout: int) -> bytes:
        for attempt in range(5):
            try:
                request = urllib.request.Request(
                    url,
                    headers={"User-Agent": "ChavezPokemonSnapshot/1.0"},
                )
                with urllib.request.urlopen(request, timeout=timeout) as response:
                    return response.read()
            except Exception:
                if attempt == 4:
                    raise
                time.sleep(2**attempt)
        raise AcquisitionError(f"Download failed: {url}")


def _utc_now() -> str:
    return datetime.now(timezone.utc).isoformat().replace("+00:00", "Z")


def _copy_file(source: Path, target: Path) -> None:
    target.parent.mkdir(parents=True, exist_ok=True)
    shutil.copyfile(source, target)


def _manifest_entry(
    root: Path,
    relative: str,
    *,
    kind: str,
    stable_id: int | None = None,
    required: bool = True,
) -> dict[str, Any]:
    path = root / relative
    entry: dict[str, Any] = {
        "path": relative,
        "kind": kind,
        "required": required,
        "size": path.stat().st_size,
        "sha256": sha256_file(path),
    }
    if stable_id is not None:
        entry["stableId"] = stable_id
    return entry


def _copy_record(
    root: Path,
    source: Path,
    relative: str,
    *,
    kind: str,
    stable_id: int | None,
    manifest: list[dict[str, Any]],
) -> None:
    _copy_file(source, root / relative)
    manifest.append(
        _manifest_entry(
            root,
            relative,
            kind=kind,
            stable_id=stable_id,
        )
    )


def _fetch_many(
    fetcher: CachedFetcher,
    urls: Iterable[str],
    workers: int,
) -> dict[str, tuple[Path, dict[str, Any]]]:
    unique = sorted(set(urls))
    with ThreadPoolExecutor(max_workers=max(1, workers)) as executor:
        values = list(executor.map(fetcher.json, unique))
    return dict(zip(unique, values, strict=True))


def acquire_snapshot(
    *,
    snapshot_id: str,
    output_root: Path,
    cache_dir: Path,
    artwork_cache_dir: Path,
    existing_base_artwork: Path,
    existing_form_artwork: Path,
    third_party_notices: Path,
    cache_only: bool = False,
    refresh: bool = False,
    workers: int = 20,
    source_acquired_at_utc: str | None = None,
    accept_warnings: bool = False,
) -> AcquiredSnapshot:
    if not snapshot_id or "/" in snapshot_id or "\\" in snapshot_id:
        raise AcquisitionError("Snapshot identifier must be one directory name.")
    output_root = output_root.resolve()
    final = output_root / snapshot_id
    if final.exists():
        raise AcquisitionError(
            f"Finalized snapshot already exists and is immutable: {final}"
        )
    output_root.mkdir(parents=True, exist_ok=True)
    temporary = output_root / f".{snapshot_id}.incomplete-{uuid.uuid4().hex}"
    temporary.mkdir()
    created_at = _utc_now()
    source_acquired_at = source_acquired_at_utc or created_at
    fetcher = CachedFetcher(cache_dir, cache_only=cache_only, refresh=refresh)
    manifest: list[dict[str, Any]] = []

    try:
        catalog_url = f"{API_BASE}/pokemon-species?limit=100000"
        catalog_source, catalog = fetcher.json(catalog_url)
        catalog_relative = "records/catalog/pokemon-species-limit-100000.json"
        _copy_record(
            temporary,
            catalog_source,
            catalog_relative,
            kind="catalog-json",
            stable_id=None,
            manifest=manifest,
        )
        species_ids = sorted(
            stable_id_from_url(item["url"]) for item in catalog["results"]
        )
        if not species_ids:
            raise AcquisitionError("PokeAPI species catalog is empty.")

        primary_urls = [
            url
            for species_id in species_ids
            for url in (
                f"{API_BASE}/pokemon/{species_id}",
                f"{API_BASE}/pokemon-species/{species_id}",
            )
        ]
        primary = _fetch_many(fetcher, primary_urls, workers)

        species_records: dict[int, dict[str, Any]] = {}
        default_pokemon: dict[int, dict[str, Any]] = {}
        record_paths: dict[str, list[str]] = {
            "species": [],
            "defaultPokemon": [],
            "formPokemon": [],
            "moves": [],
            "evolutionChains": [],
        }
        move_urls: set[str] = set()
        form_urls: set[str] = set()
        evolution_urls: set[str] = set()

        for species_id in species_ids:
            pokemon_url = f"{API_BASE}/pokemon/{species_id}"
            species_url = f"{API_BASE}/pokemon-species/{species_id}"
            pokemon_source, pokemon = primary[pokemon_url]
            species_source, species = primary[species_url]
            if int(pokemon.get("id", -1)) != species_id:
                raise AcquisitionError(
                    f"Default Pokémon id mismatch for species {species_id}."
                )
            if int(species.get("id", -1)) != species_id:
                raise AcquisitionError(f"Species id mismatch for {species_id}.")
            species_records[species_id] = species
            default_pokemon[species_id] = pokemon

            relative = f"records/pokemon-species/{species_id}.json"
            _copy_record(
                temporary,
                species_source,
                relative,
                kind="record-species-json",
                stable_id=species_id,
                manifest=manifest,
            )
            record_paths["species"].append(relative)
            relative = f"records/pokemon/{species_id}.json"
            _copy_record(
                temporary,
                pokemon_source,
                relative,
                kind="record-default-pokemon-json",
                stable_id=species_id,
                manifest=manifest,
            )
            record_paths["defaultPokemon"].append(relative)

            for item in pokemon["moves"]:
                details = item["version_group_details"]
                has_lets_go = any(
                    detail["version_group"]["name"]
                    == "lets-go-pikachu-lets-go-eevee"
                    for detail in details
                )
                if has_lets_go or (species_id not in LETS_GO_IDS and details):
                    move_urls.add(item["move"]["url"])
            for variety in species["varieties"]:
                if form_category(variety["pokemon"]["name"]):
                    form_urls.add(variety["pokemon"]["url"])
            evolution_urls.add(species["evolution_chain"]["url"])

        secondary = _fetch_many(
            fetcher,
            move_urls | form_urls | evolution_urls,
            workers,
        )
        move_records: dict[int, dict[str, Any]] = {}
        for url in sorted(move_urls, key=stable_id_from_url):
            source, record = secondary[url]
            record_id = stable_id_from_url(url)
            move_records[record_id] = record
            relative = f"records/move/{record_id}.json"
            _copy_record(
                temporary,
                source,
                relative,
                kind="record-move-json",
                stable_id=record_id,
                manifest=manifest,
            )
            record_paths["moves"].append(relative)

        form_records: dict[int, dict[str, Any]] = {}
        for url in sorted(form_urls, key=stable_id_from_url):
            source, record = secondary[url]
            record_id = stable_id_from_url(url)
            form_records[record_id] = record
            relative = f"records/pokemon/{record_id}.json"
            _copy_record(
                temporary,
                source,
                relative,
                kind="record-form-pokemon-json",
                stable_id=record_id,
                manifest=manifest,
            )
            record_paths["formPokemon"].append(relative)

        evolution_records: dict[int, dict[str, Any]] = {}
        for url in sorted(evolution_urls, key=stable_id_from_url):
            source, record = secondary[url]
            record_id = stable_id_from_url(url)
            evolution_records[record_id] = record
            relative = f"records/evolution-chain/{record_id}.json"
            _copy_record(
                temporary,
                source,
                relative,
                kind="record-evolution-json",
                stable_id=record_id,
                manifest=manifest,
            )
            record_paths["evolutionChains"].append(relative)

        artwork_cache_dir.mkdir(parents=True, exist_ok=True)
        artwork_mappings: list[dict[str, Any]] = []
        base_mapping_by_species: dict[int, dict[str, Any]] = {}

        def obtain_artwork(
            *,
            candidates: list[tuple[str, str]],
            existing: Path,
            cache_name: str,
            target_relative: str,
        ) -> tuple[str, str]:
            if not candidates:
                raise AcquisitionError(f"No artwork URL is available for {cache_name}.")
            source_kind, source_url = candidates[0]
            target = temporary / target_relative
            if existing.is_file() and is_png(existing) and not refresh:
                _copy_file(existing, target)
                return source_kind, source_url
            cache_target = artwork_cache_dir / f"{cache_name}.png"
            acquired = fetcher.bytes(source_url, cache_target)
            _copy_file(acquired, target)
            return source_kind, source_url

        for species_id in species_ids:
            relative = f"artwork/base/{species_id}.png"
            source_kind, source_url = obtain_artwork(
                candidates=artwork_candidates(default_pokemon[species_id]),
                existing=existing_base_artwork / f"{species_id}.png",
                cache_name=f"base-{species_id}",
                target_relative=relative,
            )
            manifest.append(
                _manifest_entry(
                    temporary,
                    relative,
                    kind="artwork-base-png",
                    stable_id=species_id,
                )
            )
            mapping = {
                "category": "base",
                "id": species_id,
                "snapshotPath": relative,
                "outputAsset": f"assets/artwork/{species_id}.png",
                "sourceUrl": source_url,
                "fallback": source_kind,
            }
            artwork_mappings.append(mapping)
            base_mapping_by_species[species_id] = mapping

        form_by_name = {record["name"]: record for record in form_records.values()}
        for species_id in species_ids:
            for variety in species_records[species_id]["varieties"]:
                name = variety["pokemon"]["name"]
                if form_category(name) is None:
                    continue
                record = form_by_name[name]
                relative = f"artwork/forms/{name}.png"
                candidates = artwork_candidates(record)
                if candidates:
                    source_kind, source_url = obtain_artwork(
                        candidates=candidates,
                        existing=existing_form_artwork / f"{name}.png",
                        cache_name=f"form-{name}",
                        target_relative=relative,
                    )
                    manifest.append(
                        _manifest_entry(
                            temporary,
                            relative,
                            kind="artwork-form-png",
                            stable_id=int(record["id"]),
                        )
                    )
                    output_asset = f"assets/form_artwork/{name}.png"
                    snapshot_path = relative
                else:
                    source_kind = "base-species"
                    source_url = base_mapping_by_species[species_id]["sourceUrl"]
                    snapshot_path = f"artwork/base/{species_id}.png"
                    output_asset = f"assets/artwork/{species_id}.png"
                artwork_mappings.append(
                    {
                        "category": "forms",
                        "id": name,
                        "upstreamPokemonId": int(record["id"]),
                        "speciesId": species_id,
                        "snapshotPath": snapshot_path,
                        "outputAsset": output_asset,
                        "sourceUrl": source_url,
                        "fallback": source_kind,
                    }
                )

        mapping_relative = "mappings/artwork.json"
        write_json(temporary / mapping_relative, {"mappings": artwork_mappings})
        manifest.append(
            _manifest_entry(
                temporary,
                mapping_relative,
                kind="mapping-json",
            )
        )

        license_relative = "licenses/THIRD_PARTY_NOTICES.md"
        _copy_file(third_party_notices, temporary / license_relative)
        manifest.append(
            _manifest_entry(
                temporary,
                license_relative,
                kind="license",
            )
        )

        ability_ids = {
            stable_id_from_url(item["ability"]["url"])
            for record in [*default_pokemon.values(), *form_records.values()]
            for item in record["abilities"]
        }
        type_names = {
            item["type"]["name"]
            for record in [*default_pokemon.values(), *form_records.values()]
            for item in record["types"]
        }
        critical_species = [value for value in (1, 25, 133) if value in species_ids]
        critical_evolution_ids = sorted(
            {
                stable_id_from_url(
                    species_records[species_id]["evolution_chain"]["url"]
                )
                for species_id in critical_species
            }
        )
        metadata: dict[str, Any] = {
            "snapshotFormatVersion": SNAPSHOT_FORMAT_VERSION,
            "snapshotId": snapshot_id,
            "createdAtUtc": created_at,
            "sourceAcquiredAtUtc": source_acquired_at,
            "acquisitionToolVersion": ACQUISITION_TOOL_VERSION,
            "sources": [
                {
                    "name": "PokeAPI",
                    "baseLocation": API_BASE,
                    "revision": None,
                    "catalogUrl": catalog_url,
                    "catalogFile": catalog_relative,
                    "catalogResultCount": len(species_ids),
                },
                {
                    "name": "PokeAPI sprites",
                    "baseLocation": "URLs embedded in PokeAPI Pokémon records",
                    "revision": None,
                },
            ],
            "catalog": {
                "highestNationalDexNumber": max(species_ids),
                "speciesCount": len(species_ids),
                "catalogSha256": sha256_file(temporary / catalog_relative),
            },
            "expectedCounts": {
                "species": len(species_records),
                "defaultPokemon": len(default_pokemon),
                "pokemonRecords": len(default_pokemon) + len(form_records),
                "forms": len(form_records),
                "evolutionChains": len(evolution_records),
                "moves": len(move_records),
                "abilities": len(ability_ids),
                "types": len(type_names),
                "artwork": {
                    "base": sum(
                        mapping["category"] == "base"
                        for mapping in artwork_mappings
                    ),
                    "forms": sum(
                        mapping["category"] == "forms"
                        for mapping in artwork_mappings
                    ),
                },
            },
            "languages": ["en"],
            "records": record_paths,
            "artworkMappingsFile": mapping_relative,
            "criticalRecords": {
                "speciesIds": critical_species,
                "evolutionChainIds": critical_evolution_ids,
                "types": sorted(type_names),
            },
            "fileManifest": sorted(manifest, key=lambda entry: entry["path"]),
            "knownOptionalFiles": [],
            "knownOmissions": [
                "PokeAPI live API does not expose an immutable source revision.",
                "Legacy cache entries may have different original acquisition times.",
            ],
            "licenses": [
                {
                    "name": "PokéAPI BSD 3-Clause",
                    "reference": license_relative,
                },
                {
                    "name": "Pokémon artwork rights notice",
                    "reference": license_relative,
                },
            ],
            "manualCorrections": [],
            "notes": [
                "Snapshot preserves current form selection and move-selection rules.",
                "Snapshot is authoritative build input; mutable cache is not.",
            ],
        }
        write_json(temporary / METADATA_FILE, metadata)
        write_json(
            temporary / COMPLETE_FILE,
            {
                "snapshotId": snapshot_id,
                "snapshotMetadataSha256": sha256_file(temporary / METADATA_FILE),
            },
        )
        report = validate_snapshot(temporary, require_directory_name=False)
        if not report.valid:
            raise AcquisitionError(report.to_markdown())
        if report.warnings and not accept_warnings:
            raise AcquisitionError(
                report.to_markdown()
                + "\nReview warnings and rerun with --accept-warnings to finalize.\n"
            )
        os.replace(temporary, final)
        final_report = validate_snapshot(final)
        if not final_report.valid:
            raise AcquisitionError(final_report.to_markdown())
        return AcquiredSnapshot(final, metadata, final_report)
    except Exception:
        # Keep the unmistakably incomplete directory for diagnosis or manual cleanup.
        raise
