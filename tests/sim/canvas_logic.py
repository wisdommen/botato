"""Pure-logic port of ai_canvas.gd for offline verification.

This module tests the data flow and math that ai_canvas.gd performs,
without needing Godot's rendering engine. It verifies:
1. Boundary wall direction inference from force_vector
2. Arrow endpoint calculations
3. Force result iteration and sum accumulation
"""

from __future__ import annotations
import math
from tests.sim.vector2 import Vector2


# Constants matching ai_canvas.gd
ARROW_SCALE = 150.0
ARROW_MAX_LEN = 80.0
ARROW_MIN_LEN = 4.0
ARROWHEAD_SIZE = 6.0
BOUNDARY_TYPE_INDEX = 6

# Color palette (indices match calculator order)
TYPE_COLORS = [
    "consumable_green",   # [0]
    "gold_yellow",        # [1]
    "tree_teal",          # [2]
    "projectile_red",     # [3]
    "enemy_orange",       # [4]
    "boss_darkred",       # [5]
    "boundary_purple",    # [6]
]


def compute_arrow(origin: Vector2, force_vec: Vector2) -> dict | None:
    """Compute arrow geometry from origin and force vector.

    Returns None if arrow would be skipped (zero/tiny force).
    Returns {"origin", "tip", "direction", "length"} otherwise.
    """
    if force_vec.length_squared() < 0.0001:
        return None

    direction = force_vec.normalized()
    length = min(force_vec.length() * ARROW_SCALE, ARROW_MAX_LEN)

    if length < ARROW_MIN_LEN:
        return None

    tip = origin + direction * length
    return {
        "origin": origin,
        "tip": tip,
        "direction": direction,
        "length": length,
    }


def infer_wall_origin(
    force_vector: Vector2, player_pos: Vector2, far_corner: Vector2
) -> Vector2:
    """Infer which wall a boundary force came from, return arrow origin point.

    Mirrors _draw_boundary_arrows() in ai_canvas.gd.
    """
    abs_x = abs(force_vector.x)
    abs_y = abs(force_vector.y)

    if abs_y > abs_x:
        if force_vector.y > 0:
            # Top wall pushes downward (positive y)
            return Vector2(player_pos.x, 0)
        else:
            # Bottom wall pushes upward (negative y)
            return Vector2(player_pos.x, far_corner.y)
    else:
        if force_vector.x > 0:
            # Left wall pushes rightward (positive x)
            return Vector2(0, player_pos.y)
        else:
            # Right wall pushes leftward (negative x)
            return Vector2(far_corner.x, player_pos.y)


def simulate_canvas_draw(
    force_results: list[dict],
    player_pos: Vector2,
    far_corner: Vector2,
) -> dict:
    """Simulate what ai_canvas._draw() would produce.

    Returns a dict with:
      - "entity_arrows": list of arrow dicts per force type
      - "boundary_arrows": list of wall arrow dicts
      - "sum_arrow": the composite sum arrow dict or None
      - "sum_vector": the raw sum vector
      - "type_count": number of force types processed
    """
    entity_arrows = []
    boundary_arrows = []
    sum_vector = Vector2(0, 0)

    for i, result in enumerate(force_results):
        sum_vector = sum_vector + result["vector"]
        color = TYPE_COLORS[i] if i < len(TYPE_COLORS) else "white"

        if i == BOUNDARY_TYPE_INDEX:
            for item in result["debug_items"]:
                origin = infer_wall_origin(
                    item["force_vector"], player_pos, far_corner
                )
                arrow = compute_arrow(origin, item["force_vector"])
                if arrow is not None:
                    arrow["color"] = color
                    arrow["wall"] = _identify_wall(item["force_vector"])
                    boundary_arrows.append(arrow)
        else:
            for item in result["debug_items"]:
                arrow = compute_arrow(item["position"], item["force_vector"])
                if arrow is not None:
                    arrow["color"] = color
                    arrow["type_index"] = i
                    entity_arrows.append(arrow)

    sum_arrow = compute_arrow(player_pos, sum_vector)

    return {
        "entity_arrows": entity_arrows,
        "boundary_arrows": boundary_arrows,
        "sum_arrow": sum_arrow,
        "sum_vector": sum_vector,
        "type_count": len(force_results),
    }


def _identify_wall(force_vector: Vector2) -> str:
    abs_x = abs(force_vector.x)
    abs_y = abs(force_vector.y)
    if abs_y > abs_x:
        return "top" if force_vector.y > 0 else "bottom"
    else:
        return "left" if force_vector.x > 0 else "right"
