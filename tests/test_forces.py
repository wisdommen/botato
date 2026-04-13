"""Unit tests for all 7 force calculators.

Verifies behavioral parity with GDScript originals using known inputs.
"""

import unittest
import math
from tests.sim.vector2 import Vector2
from tests.sim.mocks import (
    MockEntity, MockProjectile, MockHitbox, MockCollision,
    CircleShape2D, RectangleShape2D, MockEnemy, MockBoss,
    MockStats, SpawningAttackBehavior, ChargingAttackBehavior,
    build_ctx,
)
from tests.sim import force_calculators as fc


class TestVector2(unittest.TestCase):
    """Verify Vector2 matches Godot 3.5 behavior."""

    def test_length_squared(self):
        v = Vector2(3, 4)
        self.assertAlmostEqual(v.length_squared(), 25.0)

    def test_normalized(self):
        v = Vector2(0, 5)
        n = v.normalized()
        self.assertAlmostEqual(n.x, 0.0)
        self.assertAlmostEqual(n.y, 1.0)

    def test_normalized_zero(self):
        n = Vector2(0, 0).normalized()
        self.assertAlmostEqual(n.length(), 0.0)

    def test_tangent(self):
        # Godot 3.5: tangent of (1,0) = (0, -1) — 90° CW in screen coords
        v = Vector2(1, 0)
        t = v.tangent()
        self.assertAlmostEqual(t.x, 0.0)
        self.assertAlmostEqual(t.y, -1.0)

    def test_cross(self):
        a = Vector2(1, 0)
        b = Vector2(0, 1)
        self.assertAlmostEqual(a.cross(b), 1.0)
        self.assertAlmostEqual(b.cross(a), -1.0)

    def test_rotated(self):
        v = Vector2(1, 0)
        r = v.rotated(math.pi / 2)
        self.assertAlmostEqual(r.x, 0.0, places=5)
        self.assertAlmostEqual(r.y, 1.0, places=5)


class TestConsumableForce(unittest.TestCase):

    def test_attracts_toward_consumable(self):
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            consumables=[MockEntity(position=Vector2(600, 500))],
            consumable_weight=1.0,
        )
        result = fc.consumable_force(ctx)
        # Force should point right (toward consumable)
        self.assertGreater(result["vector"].x, 0)
        self.assertAlmostEqual(result["vector"].y, 0, places=5)

    def test_stronger_when_health_low(self):
        low_hp_ctx = build_ctx(
            player_pos=Vector2(500, 500),
            consumables=[MockEntity(position=Vector2(600, 500))],
            consumable_weight=1.8,  # (1 - 0.1) * 2 = low HP
        )
        high_hp_ctx = build_ctx(
            player_pos=Vector2(500, 500),
            consumables=[MockEntity(position=Vector2(600, 500))],
            consumable_weight=0.2,  # (1 - 0.9) * 2 = high HP
        )
        low_result = fc.consumable_force(low_hp_ctx)
        high_result = fc.consumable_force(high_hp_ctx)
        self.assertGreater(
            low_result["vector"].length(),
            high_result["vector"].length(),
        )

    def test_empty_consumables(self):
        ctx = build_ctx(consumables=[])
        result = fc.consumable_force(ctx)
        self.assertAlmostEqual(result["vector"].length(), 0.0)
        self.assertEqual(len(result["debug_items"]), 0)

    def test_debug_items_populated(self):
        ctx = build_ctx(
            consumables=[
                MockEntity(position=Vector2(600, 500)),
                MockEntity(position=Vector2(400, 500)),
            ],
        )
        result = fc.consumable_force(ctx)
        self.assertEqual(len(result["debug_items"]), 2)
        for item in result["debug_items"]:
            self.assertIn("position", item)
            self.assertIn("force_vector", item)
            self.assertIn("weight", item)


class TestGoldForce(unittest.TestCase):

    def test_attracts_toward_gold(self):
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            golds=[MockEntity(position=Vector2(500, 300))],
        )
        result = fc.gold_force(ctx)
        # Should attract upward (negative y)
        self.assertLess(result["vector"].y, 0)

    def test_inverse_distance_falloff(self):
        near_ctx = build_ctx(
            player_pos=Vector2(500, 500),
            golds=[MockEntity(position=Vector2(550, 500))],
        )
        far_ctx = build_ctx(
            player_pos=Vector2(500, 500),
            golds=[MockEntity(position=Vector2(800, 500))],
        )
        near = fc.gold_force(near_ctx)
        far = fc.gold_force(far_ctx)
        self.assertGreater(near["vector"].length(), far["vector"].length())


class TestTreeForce(unittest.TestCase):

    def test_attracts_when_far(self):
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            neutrals=[MockEntity(position=Vector2(800, 500))],
            preferred_distance_sq=90000.0,  # 300^2
        )
        result = fc.tree_force(ctx)
        # Far tree: attract (positive x)
        self.assertGreater(result["vector"].x, 0)

    def test_repels_when_close(self):
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            neutrals=[MockEntity(position=Vector2(520, 500))],
            preferred_distance_sq=90000.0,  # dist_sq=400 < 45000/2
        )
        result = fc.tree_force(ctx)
        # Close tree: repel (negative x = away from tree to right)
        self.assertLess(result["vector"].x, 0)


class TestProjectileForce(unittest.TestCase):

    def test_perpendicular_dodge(self):
        # Projectile moving right, player below
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            projectiles=[MockProjectile(
                position=Vector2(300, 500),
                linear_velocity=Vector2(200, 0),
                _hitbox=MockHitbox(active=True, _collision=MockCollision(CircleShape2D(5.0))),
            )],
        )
        result = fc.projectile_force(ctx)
        # Dodge should be perpendicular to velocity (y component dominant)
        vec = result["vector"]
        self.assertGreater(abs(vec.y), abs(vec.x) * 0.5,
                           "Dodge should be primarily perpendicular to projectile velocity")

    def test_distance_cutoff(self):
        # Projectile very far away (>500px → dist_sq > 250000)
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            projectiles=[MockProjectile(
                position=Vector2(1500, 500),  # 1000px away → dist_sq = 1M
                linear_velocity=Vector2(-200, 0),
                _hitbox=MockHitbox(active=True, _collision=MockCollision(CircleShape2D(5.0))),
            )],
        )
        result = fc.projectile_force(ctx)
        self.assertAlmostEqual(result["vector"].length(), 0.0)

    def test_inactive_hitbox_skipped(self):
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            projectiles=[MockProjectile(
                position=Vector2(550, 500),
                linear_velocity=Vector2(-200, 0),
                _hitbox=MockHitbox(active=False),
            )],
        )
        result = fc.projectile_force(ctx)
        self.assertAlmostEqual(result["vector"].length(), 0.0)

    def test_zero_velocity_skipped(self):
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            projectiles=[MockProjectile(
                position=Vector2(550, 500),
                linear_velocity=Vector2(0, 0),  # mine
                _hitbox=MockHitbox(active=True, _collision=MockCollision(CircleShape2D(5.0))),
            )],
        )
        result = fc.projectile_force(ctx)
        self.assertAlmostEqual(result["vector"].length(), 0.0)

    def test_symmetric_projectiles_cancel_is_expected(self):
        """D-02: Perfectly symmetric projectiles cancel — other forces break the tie."""
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            projectiles=[
                MockProjectile(
                    position=Vector2(400, 500),
                    linear_velocity=Vector2(200, 0),
                    _hitbox=MockHitbox(active=True, _collision=MockCollision(CircleShape2D(5.0))),
                ),
                MockProjectile(
                    position=Vector2(600, 500),
                    linear_velocity=Vector2(-200, 0),
                    _hitbox=MockHitbox(active=True, _collision=MockCollision(CircleShape2D(5.0))),
                ),
            ],
        )
        result = fc.projectile_force(ctx)
        # Per D-02: symmetric cancellation is expected — resolved by other force types
        self.assertAlmostEqual(result["vector"].length(), 0.0, places=3)

    def test_asymmetric_projectiles_produce_dodge(self):
        """Non-symmetric projectiles should produce a nonzero dodge vector."""
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            projectiles=[
                MockProjectile(
                    position=Vector2(400, 500),
                    linear_velocity=Vector2(200, 0),
                    _hitbox=MockHitbox(active=True, _collision=MockCollision(CircleShape2D(5.0))),
                ),
                MockProjectile(
                    position=Vector2(450, 480),
                    linear_velocity=Vector2(150, 50),
                    _hitbox=MockHitbox(active=True, _collision=MockCollision(CircleShape2D(5.0))),
                ),
            ],
        )
        result = fc.projectile_force(ctx)
        self.assertGreater(result["vector"].length(), 0.001,
                           "Asymmetric projectiles should produce nonzero dodge")


class TestEnemyForce(unittest.TestCase):

    def test_attract_far_enemy(self):
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            enemies=[MockEnemy(position=Vector2(900, 500), stats=MockStats())],
            preferred_distance_sq=90000.0,
        )
        result = fc.enemy_force(ctx)
        self.assertGreater(result["vector"].x, 0, "Should attract toward far enemy")

    def test_repel_close_enemy(self):
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            enemies=[MockEnemy(position=Vector2(520, 500), stats=MockStats())],
            preferred_distance_sq=90000.0,  # dist_sq=400 < 90000
        )
        result = fc.enemy_force(ctx)
        self.assertLess(result["vector"].x, 0, "Should repel from close enemy")

    def test_sets_shooting_flag(self):
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            enemies=[MockEnemy(position=Vector2(520, 500), stats=MockStats())],
            preferred_distance_sq=90000.0,
        )
        fc.enemy_force(ctx)
        self.assertTrue(ctx["shooting_anyone"])

    def test_sets_must_run_away(self):
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            enemies=[MockEnemy(position=Vector2(505, 500), stats=MockStats())],
            preferred_distance_sq=90000.0,  # quarter = 22500, dist_sq=25 < 22500
        )
        fc.enemy_force(ctx)
        self.assertTrue(ctx["must_run_away"])


class TestBossForce(unittest.TestCase):

    def test_attract_far_boss(self):
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            bosses=[MockBoss(position=Vector2(900, 500))],
            preferred_distance_sq=90000.0,
        )
        result = fc.boss_force(ctx)
        self.assertGreater(result["vector"].x, 0)

    def test_repel_close_boss(self):
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            bosses=[MockBoss(position=Vector2(520, 500))],
            preferred_distance_sq=90000.0,
        )
        result = fc.boss_force(ctx)
        self.assertLess(result["vector"].x, 0)


class TestBoundaryForce(unittest.TestCase):

    def test_repels_from_top_wall(self):
        ctx = build_ctx(
            player_pos=Vector2(500, 50),  # near top
            bumper_weight=3.0,
            bumper_distance=150.0,
        )
        result = fc.boundary_force(ctx)
        # Top wall: push direction is (0, 1) → positive y
        self.assertGreater(result["vector"].y, 0, "Should push away from top wall")

    def test_repels_from_left_wall(self):
        ctx = build_ctx(
            player_pos=Vector2(50, 500),  # near left
            bumper_weight=3.0,
            bumper_distance=150.0,
        )
        result = fc.boundary_force(ctx)
        self.assertGreater(result["vector"].x, 0, "Should push away from left wall")

    def test_no_force_when_far(self):
        ctx = build_ctx(
            player_pos=Vector2(960, 540),  # center
            bumper_weight=3.0,
            bumper_distance=150.0,
        )
        result = fc.boundary_force(ctx)
        self.assertAlmostEqual(result["vector"].length(), 0.0, places=3)
        self.assertEqual(len(result["debug_items"]), 0)

    def test_corner_produces_diagonal(self):
        ctx = build_ctx(
            player_pos=Vector2(50, 50),  # near top-left corner
            bumper_weight=3.0,
            bumper_distance=150.0,
        )
        result = fc.boundary_force(ctx)
        # Both top (y>0) and left (x>0) should contribute
        self.assertGreater(result["vector"].x, 0)
        self.assertGreater(result["vector"].y, 0)

    def test_debug_items_use_player_pos(self):
        ctx = build_ctx(
            player_pos=Vector2(50, 500),
            bumper_distance=150.0,
        )
        result = fc.boundary_force(ctx)
        for item in result["debug_items"]:
            # Boundary debug_items always have position = player_pos
            self.assertAlmostEqual(item["position"].x, 50.0)
            self.assertAlmostEqual(item["position"].y, 500.0)


class TestAllCalculators(unittest.TestCase):
    """Integration: verify run_all_calculators produces 7 results."""

    def test_returns_seven_results(self):
        ctx = build_ctx()
        _, results = fc.run_all_calculators(ctx)
        self.assertEqual(len(results), 7)

    def test_each_result_has_contract(self):
        ctx = build_ctx(
            consumables=[MockEntity(position=Vector2(600, 500))],
            golds=[MockEntity(position=Vector2(400, 500))],
        )
        _, results = fc.run_all_calculators(ctx)
        for result in results:
            self.assertIn("vector", result)
            self.assertIn("debug_items", result)
            self.assertIsInstance(result["vector"], Vector2)
            self.assertIsInstance(result["debug_items"], list)


if __name__ == "__main__":
    unittest.main()
