"""Arena simulator for automated AI behavior testing.

Simulates Brotato combat scenarios by spawning entities, running force
calculators each frame, and moving the player accordingly. Collects
performance metrics for automated verification.
"""

from __future__ import annotations
import math
import random
from tests.sim.vector2 import Vector2
from tests.sim.mocks import (
    MockEntity,
    MockProjectile,
    MockHitbox,
    MockCollision,
    CircleShape2D,
    MockEnemy,
    MockBoss,
    MockPlayer,
    MockStats,
    build_ctx,
)
from tests.sim.force_calculators import run_all_calculators


class ArenaSimulator:
    """Lightweight combat arena for AI testing."""

    def __init__(
        self,
        map_size: Vector2 = Vector2(1920, 1080),
        player_start: Vector2 | None = None,
        player_speed: float = 300.0,
        player_hp: float = 100.0,
        weapon_range: float = 300.0,
        seed: int | None = None,
    ):
        self.map_size = map_size
        self.player_pos = player_start or Vector2(map_size.x / 2, map_size.y / 2)
        self.player_speed = player_speed
        self.player_hp = player_hp
        self.max_hp = player_hp
        self.weapon_range = weapon_range

        self.consumables: list[MockEntity] = []
        self.golds: list[MockEntity] = []
        self.neutrals: list[MockEntity] = []
        self.enemies: list[MockEnemy] = []
        self.bosses: list[MockBoss] = []
        self.projectiles: list[MockProjectile] = []

        self.rng = random.Random(seed)

        # Metrics
        self.frames_survived = 0
        self.total_damage_taken = 0.0
        self.items_collected = 0
        self.golds_collected = 0
        self.min_projectile_dist = float("inf")
        self.wall_contacts = 0
        self.force_results_history: list[list[dict]] = []

    def _build_sim_ctx(self) -> dict:
        hp_ratio = self.player_hp / self.max_hp
        consumable_weight = (1.0 - hp_ratio) * 2.0
        return build_ctx(
            player_pos=self.player_pos,
            consumables=self.consumables,
            golds=self.golds,
            neutrals=self.neutrals,
            enemies=self.enemies,
            bosses=self.bosses,
            projectiles=self.projectiles,
            far_corner=self.map_size,
            preferred_distance_sq=self.weapon_range * self.weapon_range,
            consumable_weight=consumable_weight,
        )

    def step(self, delta: float = 1.0 / 60.0) -> Vector2:
        """Advance one frame. Returns the AI's chosen movement vector."""
        # Update projectile positions
        for p in self.projectiles:
            p.position = p.position + p.linear_velocity * delta

        # Remove off-screen projectiles
        self.projectiles = [
            p for p in self.projectiles
            if 0 <= p.position.x <= self.map_size.x
            and 0 <= p.position.y <= self.map_size.y
        ]

        # Move enemies toward player (simple chase)
        for enemy in self.enemies:
            to_player = self.player_pos - enemy.position
            if to_player.length_squared() > 1.0:
                enemy.position = enemy.position + to_player.normalized() * 100 * delta

        # Run AI
        ctx = self._build_sim_ctx()
        move_vector, force_results = run_all_calculators(ctx)
        self.force_results_history.append(force_results)

        # Move player (threshold matches GDScript: any nonzero vector → normalized to full speed)
        if move_vector.length_squared() > 1e-12:
            movement = move_vector.normalized() * self.player_speed * delta
            new_pos = self.player_pos + movement
            # Clamp to map bounds
            new_pos = Vector2(
                max(0, min(new_pos.x, self.map_size.x)),
                max(0, min(new_pos.y, self.map_size.y)),
            )
            self.player_pos = new_pos

        # Check wall contacts
        margin = 10.0
        if (self.player_pos.x < margin or self.player_pos.x > self.map_size.x - margin
                or self.player_pos.y < margin or self.player_pos.y > self.map_size.y - margin):
            self.wall_contacts += 1

        # Check projectile collisions (simplified: 20px radius)
        for p in self.projectiles:
            dist = (p.position - self.player_pos).length()
            self.min_projectile_dist = min(self.min_projectile_dist, dist)
            if dist < 20.0:
                self.total_damage_taken += 10.0
                self.player_hp -= 10.0

        # Check item collection (40px radius)
        collected = []
        for i, c in enumerate(self.consumables):
            if (c.position - self.player_pos).length() < 40.0:
                self.items_collected += 1
                self.player_hp = min(self.player_hp + 10, self.max_hp)
                collected.append(i)
        for i in reversed(collected):
            self.consumables.pop(i)

        collected_g = []
        for i, g in enumerate(self.golds):
            if (g.position - self.player_pos).length() < 40.0:
                self.golds_collected += 1
                collected_g.append(i)
        for i in reversed(collected_g):
            self.golds.pop(i)

        self.frames_survived += 1
        return move_vector

    def run(self, frames: int, delta: float = 1.0 / 60.0) -> dict:
        """Run simulation for N frames. Returns metrics dict."""
        for _ in range(frames):
            self.step(delta)
            if self.player_hp <= 0:
                break
        return self.get_metrics()

    def get_metrics(self) -> dict:
        return {
            "frames_survived": self.frames_survived,
            "player_hp": self.player_hp,
            "total_damage_taken": self.total_damage_taken,
            "items_collected": self.items_collected,
            "golds_collected": self.golds_collected,
            "min_projectile_distance": self.min_projectile_dist,
            "wall_contacts": self.wall_contacts,
            "alive": self.player_hp > 0,
        }


# ── Scenario Builders ───────────────────────────────────────────

def scenario_dense_bullets(seed: int = 42) -> ArenaSimulator:
    """Dense bullet hell: projectiles from all directions."""
    arena = ArenaSimulator(seed=seed)
    rng = arena.rng

    # 30 projectiles from random edges, aimed at center area
    for _ in range(30):
        edge = rng.choice(["top", "bottom", "left", "right"])
        if edge == "top":
            pos = Vector2(rng.uniform(100, 1820), 0)
            vel = Vector2(rng.uniform(-50, 50), rng.uniform(200, 400))
        elif edge == "bottom":
            pos = Vector2(rng.uniform(100, 1820), 1080)
            vel = Vector2(rng.uniform(-50, 50), rng.uniform(-400, -200))
        elif edge == "left":
            pos = Vector2(0, rng.uniform(100, 980))
            vel = Vector2(rng.uniform(200, 400), rng.uniform(-50, 50))
        else:
            pos = Vector2(1920, rng.uniform(100, 980))
            vel = Vector2(rng.uniform(-400, -200), rng.uniform(-50, 50))

        arena.projectiles.append(MockProjectile(
            position=pos,
            linear_velocity=vel,
            _hitbox=MockHitbox(active=True, _collision=MockCollision(CircleShape2D(8.0))),
        ))

    # A few consumables
    for _ in range(5):
        arena.consumables.append(
            MockEntity(position=Vector2(rng.uniform(200, 1720), rng.uniform(200, 880)))
        )
    return arena


def scenario_surrounded(seed: int = 42) -> ArenaSimulator:
    """Player surrounded by enemies on all sides."""
    arena = ArenaSimulator(seed=seed)

    # 12 enemies in a ring around player
    for angle_deg in range(0, 360, 30):
        angle = math.radians(angle_deg)
        dist = 200.0
        pos = arena.player_pos + Vector2(math.cos(angle), math.sin(angle)) * dist
        arena.enemies.append(MockEnemy(position=pos, stats=MockStats()))

    return arena


def scenario_corner_escape(seed: int = 42) -> ArenaSimulator:
    """Player stuck in a corner with projectiles incoming."""
    arena = ArenaSimulator(
        player_start=Vector2(50, 50),
        seed=seed,
    )

    # Projectiles aimed at corner
    for i in range(10):
        arena.projectiles.append(MockProjectile(
            position=Vector2(400 + i * 30, 400 + i * 20),
            linear_velocity=Vector2(-300, -300),
            _hitbox=MockHitbox(active=True, _collision=MockCollision(CircleShape2D(8.0))),
        ))

    # Consumable away from corner
    arena.consumables.append(MockEntity(position=Vector2(960, 540)))

    return arena


def scenario_boss_fight(seed: int = 42) -> ArenaSimulator:
    """Boss in center with projectile spray."""
    arena = ArenaSimulator(seed=seed)
    rng = arena.rng

    boss_pos = Vector2(960, 540)
    arena.bosses.append(MockBoss(position=boss_pos))

    # Radial projectile spray from boss
    for angle_deg in range(0, 360, 15):
        angle = math.radians(angle_deg)
        vel = Vector2(math.cos(angle), math.sin(angle)) * 250
        arena.projectiles.append(MockProjectile(
            position=boss_pos + vel.normalized() * 50,
            linear_velocity=vel,
            _hitbox=MockHitbox(active=True, _collision=MockCollision(CircleShape2D(6.0))),
        ))

    # Gold scattered around
    for _ in range(8):
        arena.golds.append(
            MockEntity(position=Vector2(rng.uniform(100, 1820), rng.uniform(100, 980)))
        )

    return arena


def scenario_item_collection(seed: int = 42) -> ArenaSimulator:
    """Peaceful scenario: test item/gold collection efficiency."""
    arena = ArenaSimulator(seed=seed, player_hp=50.0)
    rng = arena.rng

    for _ in range(10):
        arena.consumables.append(
            MockEntity(position=Vector2(rng.uniform(100, 1820), rng.uniform(100, 980)))
        )
    for _ in range(15):
        arena.golds.append(
            MockEntity(position=Vector2(rng.uniform(100, 1820), rng.uniform(100, 980)))
        )

    return arena
