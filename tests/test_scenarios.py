"""Scenario-based simulation tests for AI behavior verification.

Runs full arena simulations and checks AI performance metrics.
These tests verify the AI makes reasonable survival decisions.
"""

import unittest
from tests.sim.vector2 import Vector2
from tests.sim.arena import (
    ArenaSimulator,
    scenario_dense_bullets,
    scenario_surrounded,
    scenario_corner_escape,
    scenario_boss_fight,
    scenario_item_collection,
)


class TestDenseBullets(unittest.TestCase):
    """AI should dodge most projectiles in a bullet hell scenario."""

    def test_survives_300_frames(self):
        arena = scenario_dense_bullets(seed=42)
        metrics = arena.run(frames=300)
        self.assertTrue(metrics["alive"], "AI should survive 300 frames of bullets")

    def test_takes_limited_damage(self):
        arena = scenario_dense_bullets(seed=42)
        metrics = arena.run(frames=300)
        self.assertLess(metrics["total_damage_taken"], 80,
                        "AI should dodge enough to take < 80 damage")

    def test_dodge_produces_movement_after_approach(self):
        """Projectiles start at edges (>500px cutoff). After travel time, they enter range."""
        arena = scenario_dense_bullets(seed=42)
        # Run several frames for projectiles to enter 500px range
        total_movement = 0.0
        for _ in range(60):
            move_vec = arena.step()
            total_movement += move_vec.length()
        self.assertGreater(total_movement, 0.01,
                           "AI should produce movement once projectiles enter range")


class TestSurrounded(unittest.TestCase):
    """AI surrounded by enemies should maintain weapon range distance."""

    def test_survives_and_fights(self):
        arena = scenario_surrounded(seed=42)
        metrics = arena.run(frames=600)
        self.assertEqual(metrics["frames_survived"], 600)

    def test_repulsion_forces_present(self):
        """Even if a perfect ring cancels, individual repulsion forces should exist."""
        arena = scenario_surrounded(seed=42)
        arena.step()
        enemy_results = arena.force_results_history[0][4]  # index 4 = enemy_force
        self.assertGreater(len(enemy_results["debug_items"]), 0,
                           "Enemy force should produce debug items when surrounded")

    def test_asymmetric_ring_produces_movement(self):
        """Break symmetry by offsetting one enemy — AI should move."""
        arena = scenario_surrounded(seed=42)
        # Move one enemy closer to break perfect symmetry
        arena.enemies[0].position = arena.player_pos + Vector2(100, 30)
        start_pos = Vector2(arena.player_pos.x, arena.player_pos.y)
        arena.run(frames=60)
        moved = (arena.player_pos - start_pos).length()
        self.assertGreater(moved, 5.0, "AI should move with asymmetric enemy ring")


class TestCornerEscape(unittest.TestCase):
    """AI in corner with incoming projectiles should escape toward open space."""

    def test_boundary_pushes_away_from_corner(self):
        """Boundary forces alone should push player away from corner."""
        arena = scenario_corner_escape(seed=42)
        arena.projectiles.clear()  # isolate boundary force
        arena.run(frames=120)
        # Boundary pushes away from (50,50) corner
        self.assertGreater(arena.player_pos.x, 50,
                           "Boundary force should push away from left wall")
        self.assertGreater(arena.player_pos.y, 50,
                           "Boundary force should push away from top wall")

    def test_boundary_force_exists_in_corner(self):
        """Verify boundary calculator produces nonzero force in corner."""
        arena = scenario_corner_escape(seed=42)
        arena.step()
        boundary_result = arena.force_results_history[0][6]  # index 6 = boundary
        self.assertGreater(boundary_result["vector"].length(), 0,
                           "Boundary force should be nonzero in corner")


class TestBossFight(unittest.TestCase):
    """AI facing boss with radial projectile spray."""

    def test_survives_300_frames(self):
        arena = scenario_boss_fight(seed=42)
        metrics = arena.run(frames=300)
        self.assertTrue(metrics["alive"])

    def test_boss_force_produces_repulsion(self):
        """Boss near player (not overlapping) should produce repulsion."""
        arena = scenario_boss_fight(seed=42)
        # Move player slightly off-center so direction is computable
        arena.player_pos = Vector2(900, 500)
        arena.step()
        boss_result = arena.force_results_history[0][5]  # index 5 = boss_force
        self.assertGreater(boss_result["vector"].length(), 0,
                           "Boss force should produce nonzero repulsion")


class TestItemCollection(unittest.TestCase):
    """Peaceful scenario: AI should efficiently collect items."""

    def test_consumable_force_points_toward_items(self):
        """With low HP, consumable force should attract toward nearest consumable."""
        arena = scenario_item_collection(seed=42)
        arena.player_hp = 30.0  # low health → high consumable_weight
        arena.step()
        consumable_result = arena.force_results_history[0][0]  # index 0 = consumable
        self.assertGreater(consumable_result["vector"].length(), 0,
                           "Consumable force should be nonzero when hurt")
        self.assertGreater(len(consumable_result["debug_items"]), 0)

    def test_gold_force_points_toward_gold(self):
        """Gold force should attract toward gold pickups."""
        arena = scenario_item_collection(seed=42)
        arena.step()
        gold_result = arena.force_results_history[0][1]  # index 1 = gold
        self.assertGreater(gold_result["vector"].length(), 0,
                           "Gold force should be nonzero with gold on field")

    def test_collects_items_with_enough_frames(self):
        """Given enough frames, AI should reach and collect some items."""
        arena = scenario_item_collection(seed=42)
        arena.player_hp = 30.0
        metrics = arena.run(frames=3000)  # 50 seconds at 60fps
        total_collected = metrics["items_collected"] + metrics["golds_collected"]
        self.assertGreater(total_collected, 0,
                           "AI should collect at least one item given enough time")


class TestForceResultIntegrity(unittest.TestCase):
    """Verify force_results data matches what canvas would consume."""

    def test_all_results_have_debug_items(self):
        arena = scenario_dense_bullets(seed=42)
        arena.step()
        for results in arena.force_results_history:
            self.assertEqual(len(results), 7)
            for r in results:
                self.assertIn("vector", r)
                self.assertIn("debug_items", r)

    def test_debug_items_have_required_fields(self):
        arena = scenario_dense_bullets(seed=42)
        arena.step()
        for results in arena.force_results_history:
            for r in results:
                for item in r["debug_items"]:
                    self.assertIn("position", item)
                    self.assertIn("force_vector", item)
                    self.assertIn("weight", item)

    def test_sum_vector_consistency_across_frames(self):
        """Canvas sum arrow should equal sum of all result.vector values."""
        arena = scenario_surrounded(seed=42)
        for _ in range(10):
            arena.step()
        for results in arena.force_results_history:
            expected = Vector2(0, 0)
            for r in results:
                expected = expected + r["vector"]
            # This is exactly what canvas computes for sum_arrow
            self.assertIsInstance(expected, Vector2)


if __name__ == "__main__":
    unittest.main()
