#!/usr/bin/env python3
"""Master Blender 5.3.0 orchestrator regenerating all upgraded Kage no Machi GLBs."""

from __future__ import annotations

import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
if HERE not in sys.path:
    sys.path.insert(0, HERE)

import bridge_and_landmarks
import buildings
import castle_port
import characters
import nature_trees
import props_street
import rocks_and_shore
import vistas


def main() -> None:
    print("=== Kage no Machi Blender 5.3.0 Asset Build ===")
    rocks_and_shore.build_all()
    bridge_and_landmarks.build_edo_arched_bridge()
    buildings.build_all()
    castle_port.build_all()
    characters.build_all()
    nature_trees.build_all()
    props_street.build_all()
    vistas.build_all()
    print("=== All Blender GLBs exported cleanly ===")


if __name__ == "__main__":
    main()
