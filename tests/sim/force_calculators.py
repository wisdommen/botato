"""Python ports of all 7 GDScript force calculators.

Each function takes a ctx dict and returns {"vector": Vector2, "debug_items": list}.
Ported line-for-line from the GDScript originals to ensure behavioral parity.
"""

from __future__ import annotations
import math
from tests.sim.vector2 import Vector2
from tests.sim.mocks import (
    SpawningAttackBehavior,
    ChargingAttackBehavior,
    CircleShape2D,
    RectangleShape2D,
)


def _safe_force(direction: Vector2, dist_sq: float, weight: float) -> Vector2:
    if dist_sq < 0.001:
        dist_sq = 0.001
    result = direction.normalized() / dist_sq * weight
    if result.is_nan():
        return Vector2.ZERO
    return result


# ── [0] Consumable Force ────────────────────────────────────────

def consumable_force(ctx: dict) -> dict:
    move_vector = Vector2(0, 0)
    debug_items = []
    player_pos = ctx["player"].position
    weight = ctx["consumable_weight"]

    for consumable in ctx["consumables"]:
        to_entity = consumable.position - player_pos
        dist_sq = to_entity.length_squared()
        if dist_sq < 0.001:
            dist_sq = 0.001
        # D-09: *10 multiplier intentional
        force = to_entity.normalized() / dist_sq * 10.0 * weight
        if not force.is_nan():
            move_vector = move_vector + force
            debug_items.append({
                "position": consumable.position,
                "force_vector": force,
                "weight": weight,
            })

    return {"vector": move_vector, "debug_items": debug_items}


# ── [1] Gold Force ──────────────────────────────────────────────

def gold_force(ctx: dict) -> dict:
    move_vector = Vector2(0, 0)
    debug_items = []
    player_pos = ctx["player"].position
    weight = ctx["item_weight"]

    for item in ctx["golds"]:
        to_entity = item.position - player_pos
        dist_sq = to_entity.length_squared()
        if dist_sq < 0.001:
            dist_sq = 0.001
        force = to_entity.normalized() / dist_sq * weight
        if not force.is_nan():
            move_vector = move_vector + force
            debug_items.append({
                "position": item.position,
                "force_vector": force,
                "weight": weight,
            })

    return {"vector": move_vector, "debug_items": debug_items}


# ── [2] Tree Force ──────────────────────────────────────────────

def tree_force(ctx: dict) -> dict:
    move_vector = Vector2(0, 0)
    debug_items = []
    player_pos = ctx["player"].position
    weight = ctx["tree_weight"]
    preferred_dist_sq = ctx["preferred_distance_sq"]

    for neutral in ctx["neutrals"]:
        to_entity = neutral.position - player_pos
        dist_sq = to_entity.length_squared()
        if dist_sq < 0.001:
            dist_sq = 0.001
        force = to_entity.normalized() / dist_sq * weight

        # D-06: repel when inside half weapon range
        if dist_sq < (preferred_dist_sq / 2.0):
            force = force * -1.0

        if not force.is_nan():
            move_vector = move_vector + force
            debug_items.append({
                "position": neutral.position,
                "force_vector": force,
                "weight": weight,
            })

    return {"vector": move_vector, "debug_items": debug_items}


# ── [3] Projectile Force ───────────────────────────────────────

def _gather_threats(ctx: dict) -> list[Vector2]:
    threats = []
    for enemy in ctx["enemies"]:
        threats.append(enemy.position)
    for boss in ctx["bosses"]:
        threats.append(boss.position)
    for projectile in ctx["projectiles"]:
        threats.append(projectile.position)
    return threats


def _get_dodge_direction(
    projectile_vel: Vector2, player_pos: Vector2, threats: list[Vector2]
) -> Vector2:
    perp = projectile_vel.normalized().tangent()
    left_dodge = perp
    right_dodge = -perp

    left_count = 0
    right_count = 0
    for threat_pos in threats:
        to_threat = threat_pos - player_pos
        if perp.cross(to_threat) > 0:
            left_count += 1
        else:
            right_count += 1

    return left_dodge if left_count <= right_count else right_dodge


def projectile_force(ctx: dict) -> dict:
    move_vector = Vector2(0, 0)
    debug_items = []
    player_pos = ctx["player"].position
    weight = ctx["projectile_weight"]

    threats = _gather_threats(ctx)

    for projectile in ctx["projectiles"]:
        if projectile._hitbox is None or not projectile._hitbox.active:
            continue
        if projectile.linear_velocity.length_squared() < 0.001:
            continue

        extra_range = 0.0
        shape = projectile._hitbox._collision.shape
        if isinstance(shape, CircleShape2D):
            extra_range = shape.radius
        elif isinstance(shape, RectangleShape2D):
            extra_range = shape.extents.x
            if shape.extents.y > extra_range:
                extra_range = shape.extents.y

        to_projectile = projectile.position - player_pos
        extra_range_sq = extra_range * extra_range
        dist_sq = to_projectile.length_squared() - extra_range_sq
        if dist_sq < 0.001:
            dist_sq = 0.001

        if dist_sq > 250000.0:
            continue

        dodge_dir = _get_dodge_direction(
            projectile.linear_velocity, player_pos, threats
        )
        force = dodge_dir / dist_sq * weight
        if not force.is_nan():
            move_vector = move_vector + force
            debug_items.append({
                "position": projectile.position,
                "force_vector": force,
                "weight": weight,
            })

    return {"vector": move_vector, "debug_items": debug_items}


# ── [4] Enemy Force ─────────────────────────────────────────────

def enemy_force(ctx: dict) -> dict:
    move_vector = Vector2(0, 0)
    debug_items = []
    player_pos = ctx["player"].position
    egg_weight = ctx["egg_weight"]
    preferred_dist_sq = ctx["preferred_distance_sq"]

    for enemy in ctx["enemies"]:
        is_egg = isinstance(enemy._attack_behavior, SpawningAttackBehavior)
        to_entity = enemy.position - player_pos
        dist_sq = to_entity.length_squared()
        if dist_sq < 0.001:
            dist_sq = 0.001

        force = to_entity.normalized() / dist_sq

        # D-07: egg strong attraction
        if getattr(enemy.stats, "base_drop_chance", 0) == 1:
            force = force * egg_weight * 4.0

        # attract-far / repel-near
        if dist_sq < preferred_dist_sq:
            ctx["shooting_anyone"] = True
            force = force * -1.0

            if isinstance(
                enemy._current_attack_behavior, ChargingAttackBehavior
            ) and enemy._move_locked:
                charge_dir = enemy._current_attack_behavior._charge_direction
                force = charge_dir.tangent().normalized() / dist_sq * -4.0

        # must-run-away
        if dist_sq < preferred_dist_sq * 0.25:
            ctx["must_run_away"] = True

        # additional egg multiplier
        if is_egg:
            force = force * egg_weight

        if not force.is_nan():
            move_vector = move_vector + force
            debug_items.append({
                "position": enemy.position,
                "force_vector": force,
                "weight": egg_weight if is_egg else 1.0,
            })

    return {"vector": move_vector, "debug_items": debug_items}


# ── [5] Boss Force ──────────────────────────────────────────────

BOSS_CHARGE_MULTIPLIER = 4.0


def boss_force(ctx: dict) -> dict:
    move_vector = Vector2(0, 0)
    debug_items = []
    player_pos = ctx["player"].position
    weight = ctx["boss_weight"]
    preferred_dist_sq = ctx["preferred_distance_sq"]

    for boss in ctx["bosses"]:
        to_entity = boss.position - player_pos
        dist_sq = to_entity.length_squared()
        if dist_sq < 0.001:
            dist_sq = 0.001

        force = to_entity.normalized() / dist_sq * weight

        if dist_sq < preferred_dist_sq:
            ctx["shooting_anyone"] = True
            force = force * -1.0

            if isinstance(
                boss._current_attack_behavior, ChargingAttackBehavior
            ) and boss._move_locked:
                charge_dir = boss._current_attack_behavior._charge_direction
                force = (
                    charge_dir.tangent().normalized()
                    / dist_sq
                    * weight
                    * BOSS_CHARGE_MULTIPLIER
                    * -1.0
                )

        if dist_sq < preferred_dist_sq * 0.25:
            ctx["must_run_away"] = True

        if not force.is_nan():
            move_vector = move_vector + force
            debug_items.append({
                "position": boss.position,
                "force_vector": force,
                "weight": weight,
            })

    return {"vector": move_vector, "debug_items": debug_items}


# ── [6] Boundary Force ──────────────────────────────────────────

def _wall_force(
    dist_to_wall: float, push_dir: Vector2, weight: float, threshold: float
) -> Vector2:
    if dist_to_wall <= 0.0:
        dist_to_wall = 0.001
    dist_sq = dist_to_wall * dist_to_wall
    threshold_sq = threshold * threshold
    if dist_sq > threshold_sq:
        return Vector2(0, 0)
    return push_dir / dist_sq * weight


def boundary_force(ctx: dict) -> dict:
    move_vector = Vector2(0, 0)
    debug_items = []
    player_pos = ctx["player"].position
    far_corner = ctx["far_corner"]
    weight = ctx["bumper_weight"]
    threshold = ctx["bumper_distance"]

    walls = [
        {"dist": player_pos.y, "push": Vector2(0, 1)},     # top (y=0)
        {"dist": far_corner.y - player_pos.y, "push": Vector2(0, -1)},  # bottom
        {"dist": player_pos.x, "push": Vector2(1, 0)},     # left (x=0)
        {"dist": far_corner.x - player_pos.x, "push": Vector2(-1, 0)},  # right
    ]

    for wall in walls:
        f = _wall_force(wall["dist"], wall["push"], weight, threshold)
        if not f.is_nan():
            move_vector = move_vector + f
            if f.length_squared() > 1e-10:
                debug_items.append({
                    "position": player_pos,
                    "force_vector": f,
                    "weight": weight,
                })

    return {"vector": move_vector, "debug_items": debug_items}


# ── Calculator registry ─────────────────────────────────────────

ALL_CALCULATORS = [
    consumable_force,   # [0]
    gold_force,         # [1]
    tree_force,         # [2]
    projectile_force,   # [3]
    enemy_force,        # [4]
    boss_force,         # [5]
    boundary_force,     # [6]
]


def run_all_calculators(ctx: dict) -> tuple[Vector2, list[dict]]:
    """Run all 7 calculators and return (move_vector, force_results).

    Mirrors get_movement() in player_movement_behavior.gd.
    """
    move_vector = Vector2(0, 0)
    force_results = []
    for calc in ALL_CALCULATORS:
        result = calc(ctx)
        move_vector = move_vector + result["vector"]
        force_results.append(result)
    return move_vector, force_results
