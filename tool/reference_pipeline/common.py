from __future__ import annotations

import hashlib
import json
import os
import re
from pathlib import Path
from typing import Any, Iterable

API_BASE = "https://pokeapi.co/api/v2"
LETS_GO_IDS = {*range(1, 152), 808, 809}
POKEMON_TYPES = {
    "normal",
    "fire",
    "water",
    "electric",
    "grass",
    "ice",
    "fighting",
    "poison",
    "ground",
    "flying",
    "psychic",
    "bug",
    "rock",
    "ghost",
    "dragon",
    "dark",
    "steel",
    "fairy",
}
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def sha256_file(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def write_json(path: Path, value: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_name(f".{path.name}.tmp")
    temporary.write_text(
        json.dumps(value, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
        encoding="utf-8",
    )
    os.replace(temporary, path)


def load_json(path: Path) -> dict[str, Any]:
    value = json.loads(path.read_text(encoding="utf-8"))
    if not isinstance(value, dict):
        raise ValueError(f"{path} must contain a JSON object")
    return value


def is_png(path: Path) -> bool:
    try:
        with path.open("rb") as source:
            return source.read(len(PNG_SIGNATURE)) == PNG_SIGNATURE
    except OSError:
        return False


def stable_id_from_url(url: str) -> int:
    try:
        return int(url.rstrip("/").split("/")[-1])
    except (TypeError, ValueError) as error:
        raise ValueError(f"URL has no numeric stable identifier: {url!r}") from error


def cache_key_for_url(url: str) -> str:
    return (
        url.removeprefix(f"{API_BASE}/")
        .strip("/")
        .replace("/", "-")
        .replace("?", "-")
        .replace("&", "-")
        .replace("=", "-")
        + ".json"
    )


def english(
    items: list[dict[str, Any]],
    key: str,
    preferred_version: str | None = None,
) -> str:
    choices = [item for item in items if item["language"]["name"] == "en"]
    if preferred_version:
        preferred = [
            item
            for item in choices
            if item.get("version", {}).get("name") == preferred_version
        ]
        if preferred:
            choices = preferred
    if not choices:
        return ""
    return choices[-1][key].replace("\n", " ").replace("\f", " ")


def title(value: str) -> str:
    special = {
        "mr-mime": "Mr. Mime",
        "farfetchd": "Farfetch'd",
        "nidoran-f": "Nidoran♀",
        "nidoran-m": "Nidoran♂",
        "mime-jr": "Mime Jr.",
    }
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


def artwork_candidates(pokemon: dict[str, Any]) -> list[tuple[str, str]]:
    other = pokemon["sprites"]["other"]
    candidates = [
        ("official-artwork", other["official-artwork"]["front_default"]),
        ("home", other.get("home", {}).get("front_default")),
        ("front-default", pokemon["sprites"].get("front_default")),
    ]
    return [(name, url) for name, url in candidates if url]


def selected_move_detail(
    species_id: int,
    move_item: dict[str, Any],
) -> dict[str, Any] | None:
    details = move_item["version_group_details"]
    lets_go = [
        detail
        for detail in details
        if detail["version_group"]["name"] == "lets-go-pikachu-lets-go-eevee"
    ]
    selected = lets_go if lets_go else ([] if species_id in LETS_GO_IDS else details[-1:])
    return selected[-1] if selected else None


def condition(detail: dict[str, Any]) -> str:
    trigger = detail["trigger"]["name"]
    parts: list[str] = []
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


def walk_chain(
    node: dict[str, Any],
    family: str,
    edges: list[tuple[str, int, int, str, int]],
) -> None:
    parent_id = stable_id_from_url(node["species"]["url"])
    for index, child in enumerate(node["evolves_to"]):
        child_id = stable_id_from_url(child["species"]["url"])
        conditions = " or ".join(
            condition(detail) for detail in child["evolution_details"]
        )
        edges.append((family, parent_id, child_id, conditions or "Evolves", index))
        walk_chain(child, family, edges)


def safe_relative_path(value: str) -> bool:
    if not value or "\\" in value:
        return False
    path = Path(value)
    return not path.is_absolute() and ".." not in path.parts


def natural_key(value: str) -> list[int | str]:
    return [
        int(piece) if piece.isdigit() else piece
        for piece in re.split(r"(\d+)", value.lower())
    ]


def unique_stable_ids(records: Iterable[dict[str, Any]]) -> set[int]:
    return {int(record["id"]) for record in records}

