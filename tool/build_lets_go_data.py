#!/usr/bin/env python3
"""Deprecated compatibility wrapper for deterministic reference generation."""

from __future__ import annotations

import sys

from build_reference_data import main


if __name__ == "__main__":
    print(
        "Deprecated: use `python tool/build_reference_data.py build`. "
        "Network acquisition now uses `tool/acquire_reference_snapshot.py`.",
        file=sys.stderr,
    )
    raise SystemExit(main(["build", *sys.argv[1:]]))
