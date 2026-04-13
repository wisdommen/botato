"""Mock game objects for simulation testing."""

from __future__ import annotations
from dataclasses import dataclass, field
from tests.sim.vector2 import Vector2


@dataclass
class MockEntity:
    """Generic entity with position."""
    position: Vector2 = field(default_factory=lambda: Vector2(0, 0))


@dataclass
class MockShape:
    """Base shape for hitbox."""
    pass


@dataclass
class CircleShape2D(MockShape):
    radius: float = 10.0


@dataclass
class RectangleShape2D(MockShape):
    extents_x: float = 10.0
    extents_y: float = 10.0

    @property
    def extents(self):
        return type("Extents", (), {"x": self.extents_x, "y": self.extents_y})()


@dataclass
class MockCollision:
    shape: MockShape = field(default_factory=CircleShape2D)


@dataclass
class MockHitbox:
    active: bool = True
    _collision: MockCollision = field(default_factory=MockCollision)


@dataclass
class MockProjectile:
    """Projectile with position, velocity, and hitbox."""
    position: Vector2 = field(default_factory=lambda: Vector2(0, 0))
    linear_velocity: Vector2 = field(default_factory=lambda: Vector2(0, 0))
    _hitbox: MockHitbox | None = field(default_factory=MockHitbox)


class SpawningAttackBehavior:
    """Marker class for egg-type enemies."""
    pass


class ChargingAttackBehavior:
    """Behavior for charging enemies/bosses."""
    def __init__(self, charge_direction: Vector2 | None = None):
        self._charge_direction = charge_direction or Vector2(1, 0)


@dataclass
class MockStats:
    base_drop_chance: float = 0.0


@dataclass
class MockEnemy:
    """Enemy with position, attack behavior, move lock state."""
    position: Vector2 = field(default_factory=lambda: Vector2(0, 0))
    _attack_behavior: object = None
    _current_attack_behavior: object = None
    _move_locked: bool = False
    stats: MockStats = field(default_factory=MockStats)


@dataclass
class MockBoss:
    """Boss entity."""
    position: Vector2 = field(default_factory=lambda: Vector2(0, 0))
    _current_attack_behavior: object = None
    _move_locked: bool = False


@dataclass
class MockPlayer:
    """Player with position."""
    position: Vector2 = field(default_factory=lambda: Vector2(500, 500))


def build_ctx(
    player_pos: Vector2 = Vector2(500, 500),
    consumables: list | None = None,
    golds: list | None = None,
    neutrals: list | None = None,
    enemies: list | None = None,
    bosses: list | None = None,
    projectiles: list | None = None,
    far_corner: Vector2 = Vector2(1920, 1080),
    preferred_distance_sq: float = 90000.0,  # weapon range 300^2
    consumable_weight: float = 1.0,
    item_weight: float = 5.0,
    projectile_weight: float = 7.0,
    tree_weight: float = 3.0,
    boss_weight: float = 5.0,
    bumper_weight: float = 3.0,
    egg_weight: float = 4.0,
    bumper_distance: float = 150.0,
) -> dict:
    """Build a ctx dictionary matching _build_context() in player_movement_behavior.gd."""
    player = MockPlayer(position=player_pos)
    return {
        "player": player,
        "consumables": consumables or [],
        "golds": golds or [],
        "neutrals": neutrals or [],
        "enemies": enemies or [],
        "bosses": bosses or [],
        "projectiles": projectiles or [],
        "far_corner": far_corner,
        "preferred_distance_sq": preferred_distance_sq,
        "consumable_weight": consumable_weight,
        "item_weight": item_weight,
        "projectile_weight": projectile_weight,
        "tree_weight": tree_weight,
        "boss_weight": boss_weight,
        "bumper_weight": bumper_weight,
        "egg_weight": egg_weight,
        "bumper_distance": bumper_distance,
        "is_soldier": False,
        "is_bull": False,
        "shooting_anyone": False,
        "must_run_away": False,
    }
