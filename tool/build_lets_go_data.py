"""Legacy combined acquisition/build tool for the private companion dataset.

Structured data: PokeAPI (BSD-3-Clause). Artwork: The Pokemon Company;
downloaded only for this private family application. Do not redistribute.

This command is intentionally not part of routine app builds. Missing cache
entries or artwork trigger network requests, existing files are not
checksummed, output metadata includes the build time, and the shipping database
is replaced directly. Preserve known-good generated content before running it.

Future work will split network acquisition from deterministic offline
generation. Until then, treat this as an explicit content-maintenance tool.
"""

from __future__ import annotations

import json
import sqlite3
import time
import urllib.request
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CACHE = ROOT / "third_party" / "pokeapi-cache"
ART = ROOT / "assets" / "artwork"
FORM_ART = ROOT / "assets" / "form_artwork"
DB = ROOT / "assets" / "content" / "demo_reference.sqlite"
LETS_GO_IDS = {*range(1, 152), 808, 809}
API = "https://pokeapi.co/api/v2"


def get_json(url: str) -> dict:
    CACHE.mkdir(parents=True, exist_ok=True)
    key = (
        url.removeprefix(f"{API}/")
        .strip("/")
        .replace("/", "-")
        .replace("?", "-")
        .replace("&", "-")
        .replace("=", "-")
        + ".json"
    )
    target = CACHE / key
    if target.exists():
        return json.loads(target.read_text(encoding="utf-8"))
    for attempt in range(5):
        try:
            request = urllib.request.Request(url, headers={"User-Agent": "ChavezPokemon/1.0"})
            with urllib.request.urlopen(request, timeout=30) as response:
                data = response.read()
            target.write_bytes(data)
            return json.loads(data)
        except Exception:
            if attempt == 4:
                raise
            time.sleep(2**attempt)
    raise RuntimeError("unreachable")


def english(items: list[dict], key: str, preferred_version: str | None = None) -> str:
    choices = [item for item in items if item["language"]["name"] == "en"]
    if preferred_version:
        preferred = [
            item for item in choices
            if item.get("version", {}).get("name") == preferred_version
        ]
        if preferred:
            choices = preferred
    return choices[-1][key].replace("\n", " ").replace("\f", " ") if choices else ""


def title(value: str) -> str:
    special = {"mr-mime": "Mr. Mime", "farfetchd": "Farfetch'd", "nidoran-f": "Nidoran♀",
               "nidoran-m": "Nidoran♂", "mime-jr": "Mime Jr."}
    if "-mega" in value:
        base, suffix = value.split("-mega", 1)
        suffix = suffix.removeprefix("-")
        return f"Mega {title(base)}{f' {suffix.upper()}' if suffix else ''}"
    regions = {
        "-alola": "Alolan",
        "-galar": "Galarian",
        "-hisui": "Hisuian",
        "-paldea": "Paldean",
    }
    for marker, adjective in regions.items():
        if value.endswith(marker):
            return f"{adjective} {title(value.removesuffix(marker))}"
    if value.endswith("-gmax"):
        return f"Gigantamax {title(value.removesuffix('-gmax'))}"
    return special.get(value, value.replace("-", " ").title())


def condition(detail: dict) -> str:
    trigger = detail["trigger"]["name"]
    parts = []
    if detail.get("min_level"):
        parts.append(f"level {detail['min_level']}")
    if detail.get("min_happiness"):
        parts.append("high friendship")
    if detail.get("min_affection"):
        parts.append("high affection")
    if detail.get("min_beauty"):
        parts.append("high Beauty")
    if detail.get("time_of_day"):
        parts.append(detail["time_of_day"])
    if detail.get("gender") == 1:
        parts.append("female")
    if detail.get("gender") == 2:
        parts.append("male")
    if detail.get("known_move"):
        parts.append(f"knowing {title(detail['known_move']['name'])}")
    if detail.get("known_move_type"):
        parts.append(f"knowing a {title(detail['known_move_type']['name'])}-type move")
    if detail.get("location"):
        parts.append(f"at {title(detail['location']['name'])}")
    if detail.get("held_item"):
        parts.append(f"holding {title(detail['held_item']['name'])}")
    if detail.get("needs_overworld_rain"):
        parts.append("while it is raining")
    if detail.get("party_species"):
        parts.append(f"with {title(detail['party_species']['name'])} in the party")
    if detail.get("party_type"):
        parts.append(f"with a {title(detail['party_type']['name'])}-type in the party")
    if detail.get("turn_upside_down"):
        parts.append("while the system is upside down")
    relative = detail.get("relative_physical_stats")
    if relative == 1:
        parts.append("with Attack higher than Defense")
    elif relative == -1:
        parts.append("with Attack lower than Defense")
    elif relative == 0:
        parts.append("with Attack equal to Defense")
    if trigger == "level-up":
        return "Level up" + (f" at {' and '.join(parts)}" if parts else "")
    if trigger == "use-item":
        item = f"Use {title(detail['item']['name'])}"
        return item + (f" while {' and '.join(parts)}" if parts else "")
    if trigger == "trade":
        trade = "Trade"
        if detail.get("trade_species"):
            trade += f" for {title(detail['trade_species']['name'])}"
        return trade + (f" while {' and '.join(parts)}" if parts else "")
    return title(trigger) + (f" while {' and '.join(parts)}" if parts else "")


def walk_chain(node: dict, family: str, edges: list[tuple]) -> None:
    parent_id = int(node["species"]["url"].rstrip("/").split("/")[-1])
    for index, child in enumerate(node["evolves_to"]):
        child_id = int(child["species"]["url"].rstrip("/").split("/")[-1])
        details = child["evolution_details"]
        conditions = " or ".join(condition(detail) for detail in details)
        edges.append((family, parent_id, child_id, conditions or "Evolves", index))
        walk_chain(child, family, edges)


def download_art(url: str | None, dex: int) -> None:
    if not url:
        return
    ART.mkdir(parents=True, exist_ok=True)
    target = ART / f"{dex}.png"
    if target.exists():
        return
    for attempt in range(5):
        try:
            request = urllib.request.Request(
                url, headers={"User-Agent": "ChavezPokemon/1.0"}
            )
            with urllib.request.urlopen(request, timeout=60) as response:
                target.write_bytes(response.read())
            return
        except Exception:
            if attempt == 4:
                raise
            time.sleep(2**attempt)


def download_form_art(job: tuple[str, str]) -> None:
    url, form_id = job
    FORM_ART.mkdir(parents=True, exist_ok=True)
    target = FORM_ART / f"{form_id}.png"
    if target.exists():
        return
    for attempt in range(5):
        try:
            request = urllib.request.Request(
                url, headers={"User-Agent": "ChavezPokemon/1.0"}
            )
            with urllib.request.urlopen(request, timeout=60) as response:
                target.write_bytes(response.read())
            return
        except Exception:
            if attempt == 4:
                raise
            time.sleep(2**attempt)


def artwork_url(pokemon: dict) -> str | None:
    other = pokemon["sprites"]["other"]
    return (
        other["official-artwork"]["front_default"]
        or other.get("home", {}).get("front_default")
        or pokemon["sprites"]["front_default"]
    )


def prefetch(urls: list[str], workers: int = 20) -> None:
    unique = list(dict.fromkeys(urls))
    with ThreadPoolExecutor(max_workers=workers) as executor:
        list(executor.map(get_json, unique))


def form_category(name: str) -> tuple[str, str, bool] | None:
    if "-mega" in name:
        return ("Mega Evolution", "A temporary battle transformation.", True)
    regions = {
        "-alola": "Alolan Form",
        "-galar": "Galarian Form",
        "-hisui": "Hisuian Form",
        "-paldea": "Paldean Form",
    }
    for marker, category in regions.items():
        if marker in name:
            return (category, f"A regional form from {category.split()[0]}.", False)
    if "-gmax" in name:
        return ("Gigantamax Form", "A special Gigantamax battle form.", True)
    if any(marker in name for marker in ("-origin", "-therian")):
        return ("Special Form", "A distinct form used in certain games.", False)
    return None


def main() -> None:
    catalog = get_json(f"{API}/pokemon-species?limit=100000")
    ids = sorted(
        int(item["url"].rstrip("/").split("/")[-1])
        for item in catalog["results"]
    )
    print(f"Preparing {len(ids)} National Pokedex species")
    prefetch([
        url
        for dex in ids
        for url in (f"{API}/pokemon/{dex}", f"{API}/pokemon-species/{dex}")
    ])

    move_urls: list[str] = []
    form_urls: list[str] = []
    art_jobs: list[tuple[str, int]] = []
    for dex in ids:
        pokemon = get_json(f"{API}/pokemon/{dex}")
        species = get_json(f"{API}/pokemon-species/{dex}")
        for item in pokemon["moves"]:
            details = item["version_group_details"]
            has_lets_go = any(
                detail["version_group"]["name"]
                == "lets-go-pikachu-lets-go-eevee"
                for detail in details
            )
            if has_lets_go or (dex not in LETS_GO_IDS and details):
                move_urls.append(item["move"]["url"])
        for variety in species["varieties"]:
            if form_category(variety["pokemon"]["name"]):
                form_urls.append(variety["pokemon"]["url"])
        art = pokemon["sprites"]["other"]["official-artwork"]["front_default"]
        if art:
            art_jobs.append((art, dex))
    print("Caching move and form metadata")
    prefetch(move_urls + form_urls)
    form_art_jobs: list[tuple[str, str]] = []
    for form_url in form_urls:
        form = get_json(form_url)
        form_art_url = artwork_url(form)
        if form_art_url:
            form_art_jobs.append((form_art_url, form["name"]))
    print("Downloading missing base artwork")
    with ThreadPoolExecutor(max_workers=16) as executor:
        list(executor.map(lambda job: download_art(*job), art_jobs))
    print("Downloading missing form artwork")
    with ThreadPoolExecutor(max_workers=16) as executor:
        list(executor.map(download_form_art, form_art_jobs))

    species_rows, type_rows, ability_rows, stat_rows, move_rows = [], [], [], [], []
    form_rows, form_type_rows = [], []
    move_types: dict[str, str] = {}
    evolution_urls: dict[str, str] = {}

    for number, dex in enumerate(ids, 1):
        print(f"[{number}/{len(ids)}] Pokemon {dex}")
        pokemon = get_json(f"{API}/pokemon/{dex}")
        species = get_json(f"{API}/pokemon-species/{dex}")
        genus = english(species["genera"], "genus")
        description = english(species["flavor_text_entries"], "flavor_text", "lets-go-pikachu")
        if not description:
            description = english(species["flavor_text_entries"], "flavor_text")
        species_rows.append((
            dex, dex, title(species["name"]), genus, description,
            pokemon["height"] / 10,
            pokemon["weight"] / 10,
            int(species["generation"]["url"].rstrip("/").split("/")[-1]),
        ))
        for item in pokemon["types"]:
            type_rows.append((dex, item["slot"], title(item["type"]["name"])))
        for item in pokemon["abilities"]:
            ability_rows.append((dex, item["slot"], title(item["ability"]["name"])))
        for item in pokemon["stats"]:
            stat_rows.append((dex, item["stat"]["name"], item["base_stat"]))
        for item in pokemon["moves"]:
            lets_go_details = [
                detail for detail in item["version_group_details"]
                if detail["version_group"]["name"] == "lets-go-pikachu-lets-go-eevee"
            ]
            details = (
                lets_go_details
                if lets_go_details
                else (
                    []
                    if dex in LETS_GO_IDS
                    else item["version_group_details"][-1:]
                )
            )
            if not details:
                continue
            detail = details[-1]
            raw_move_name = item["move"]["name"]
            if raw_move_name not in move_types:
                move_types[raw_move_name] = title(
                    get_json(item["move"]["url"])["type"]["name"]
                )
            move_rows.append((
                dex, title(raw_move_name), move_types[raw_move_name],
                detail["move_learn_method"]["name"], detail["level_learned_at"],
            ))
        evolution_urls[species["evolution_chain"]["url"]] = f"family-{dex}"
        for variety in species["varieties"]:
            name = variety["pokemon"]["name"]
            category_details = form_category(name)
            if category_details is None:
                continue
            form = get_json(variety["pokemon"]["url"])
            form_id = name
            category, note, battle_only = category_details
            form_asset = (
                f"assets/form_artwork/{form_id}.png"
                if artwork_url(form)
                else f"assets/artwork/{dex}.png"
            )
            form_rows.append(
                (
                    form_id,
                    dex,
                    title(name),
                    category,
                    note,
                    int(battle_only),
                    form_asset,
                )
            )
            for item in form["types"]:
                form_type_rows.append((form_id, item["slot"], title(item["type"]["name"])))

    edges: list[tuple] = []
    prefetch(list(evolution_urls))
    for url, family in evolution_urls.items():
        chain = get_json(url)
        walk_chain(chain["chain"], family, edges)
    valid = set(ids)
    edges = [edge for edge in edges if edge[1] in valid and edge[2] in valid]

    DB.parent.mkdir(parents=True, exist_ok=True)
    DB.unlink(missing_ok=True)
    db = sqlite3.connect(DB)
    db.executescript("""
      PRAGMA foreign_keys=ON;
      CREATE TABLE metadata (key TEXT PRIMARY KEY, value TEXT NOT NULL);
      CREATE TABLE species (id INTEGER PRIMARY KEY, dex_number INTEGER NOT NULL UNIQUE,
        name TEXT NOT NULL, classification TEXT NOT NULL, description TEXT NOT NULL,
        height_m REAL NOT NULL, weight_kg REAL NOT NULL, generation INTEGER NOT NULL);
      CREATE TABLE species_types (species_id INTEGER NOT NULL, slot INTEGER NOT NULL,
        type_name TEXT NOT NULL, PRIMARY KEY(species_id,slot),
        FOREIGN KEY(species_id) REFERENCES species(id));
      CREATE TABLE species_abilities (species_id INTEGER NOT NULL, slot INTEGER NOT NULL,
        ability_name TEXT NOT NULL, PRIMARY KEY(species_id,slot),
        FOREIGN KEY(species_id) REFERENCES species(id));
      CREATE TABLE species_stats (species_id INTEGER NOT NULL, stat_name TEXT NOT NULL,
        base_value INTEGER NOT NULL, PRIMARY KEY(species_id,stat_name),
        FOREIGN KEY(species_id) REFERENCES species(id));
      CREATE TABLE species_moves (species_id INTEGER NOT NULL, move_name TEXT NOT NULL,
        move_type TEXT NOT NULL, learn_method TEXT NOT NULL, level_learned INTEGER NOT NULL,
        PRIMARY KEY(species_id,move_name,learn_method),
        FOREIGN KEY(species_id) REFERENCES species(id));
      CREATE TABLE forms (id TEXT PRIMARY KEY, species_id INTEGER NOT NULL, name TEXT NOT NULL,
        category TEXT NOT NULL, note TEXT NOT NULL, is_battle_only INTEGER NOT NULL DEFAULT 0,
        artwork_asset TEXT NOT NULL,
        FOREIGN KEY(species_id) REFERENCES species(id));
      CREATE TABLE form_types (form_id TEXT NOT NULL, slot INTEGER NOT NULL, type_name TEXT NOT NULL,
        PRIMARY KEY(form_id,slot), FOREIGN KEY(form_id) REFERENCES forms(id));
      CREATE TABLE evolution_edges (id INTEGER PRIMARY KEY AUTOINCREMENT, family_id TEXT NOT NULL,
        from_species_id INTEGER NOT NULL, to_species_id INTEGER NOT NULL,
        condition_text TEXT NOT NULL, sort_order INTEGER NOT NULL,
        FOREIGN KEY(from_species_id) REFERENCES species(id),
        FOREIGN KEY(to_species_id) REFERENCES species(id));
    """)
    metadata = {
        "dataset_version": "4", "content_schema": "1",
        "display_name": "National Pokédex Family Companion",
        "production_approved": "false",
        "game": "National Pokédex with a dedicated Let's Go guide",
        "structured_data_source": "PokeAPI (BSD-3-Clause)",
        "artwork_notice": "Artwork © The Pokémon Company. Private family use only.",
        "retrieved_at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
    }
    db.executemany("INSERT INTO metadata VALUES (?,?)", metadata.items())
    db.executemany("INSERT INTO species VALUES (?,?,?,?,?,?,?,?)", species_rows)
    db.executemany("INSERT INTO species_types VALUES (?,?,?)", type_rows)
    db.executemany("INSERT INTO species_abilities VALUES (?,?,?)", ability_rows)
    db.executemany("INSERT INTO species_stats VALUES (?,?,?)", stat_rows)
    db.executemany("INSERT INTO species_moves VALUES (?,?,?,?,?)", move_rows)
    db.executemany("INSERT INTO forms VALUES (?,?,?,?,?,?,?)", form_rows)
    db.executemany("INSERT INTO form_types VALUES (?,?,?)", form_type_rows)
    db.executemany(
        "INSERT INTO evolution_edges(family_id,from_species_id,to_species_id,condition_text,sort_order) VALUES (?,?,?,?,?)",
        edges,
    )
    db.commit()
    assert db.execute("PRAGMA integrity_check").fetchone()[0] == "ok"
    assert not db.execute("PRAGMA foreign_key_check").fetchall()
    print(f"Built {DB}: {len(species_rows)} species, {len(form_rows)} forms, "
          f"{len(edges)} evolutions, {len(move_rows)} move links")
    db.close()


if __name__ == "__main__":
    main()
