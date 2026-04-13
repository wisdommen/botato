"""Tests for ai_canvas.gd logic — boundary wall detection, arrow math, data flow."""

import unittest
import math
from tests.sim.vector2 import Vector2
from tests.sim.canvas_logic import (
    compute_arrow, infer_wall_origin, simulate_canvas_draw,
    ARROW_SCALE, ARROW_MAX_LEN, ARROW_MIN_LEN,
)
from tests.sim.mocks import MockEntity, build_ctx
from tests.sim import force_calculators as fc


class TestArrowComputation(unittest.TestCase):

    def test_zero_force_returns_none(self):
        result = compute_arrow(Vector2(100, 100), Vector2(0, 0))
        self.assertIsNone(result)

    def test_tiny_force_returns_none(self):
        result = compute_arrow(Vector2(100, 100), Vector2(0.00001, 0))
        self.assertIsNone(result)

    def test_normal_force_produces_arrow(self):
        result = compute_arrow(Vector2(100, 100), Vector2(0.5, 0))
        self.assertIsNotNone(result)
        self.assertGreater(result["length"], 0)
        # Tip should be to the right of origin
        self.assertGreater(result["tip"].x, result["origin"].x)

    def test_arrow_length_capped(self):
        # Very large force should be capped at ARROW_MAX_LEN
        result = compute_arrow(Vector2(0, 0), Vector2(100, 0))
        self.assertIsNotNone(result)
        self.assertAlmostEqual(result["length"], ARROW_MAX_LEN)

    def test_arrow_direction_matches_force(self):
        force = Vector2(3, 4)
        result = compute_arrow(Vector2(0, 0), force)
        expected_dir = force.normalized()
        self.assertAlmostEqual(result["direction"].x, expected_dir.x, places=5)
        self.assertAlmostEqual(result["direction"].y, expected_dir.y, places=5)

    def test_below_min_length_returns_none(self):
        # Force that produces length < ARROW_MIN_LEN
        tiny_mag = (ARROW_MIN_LEN - 0.5) / ARROW_SCALE
        result = compute_arrow(Vector2(0, 0), Vector2(tiny_mag, 0))
        self.assertIsNone(result)


class TestBoundaryWallInference(unittest.TestCase):
    """Verify ai_canvas correctly identifies which wall from force_vector direction."""

    def test_top_wall(self):
        # Top wall pushes downward: (0, 1)
        origin = infer_wall_origin(
            Vector2(0, 1), Vector2(500, 50), Vector2(1920, 1080)
        )
        self.assertAlmostEqual(origin.x, 500.0)
        self.assertAlmostEqual(origin.y, 0.0)  # y=0 = top edge

    def test_bottom_wall(self):
        # Bottom wall pushes upward: (0, -1)
        origin = infer_wall_origin(
            Vector2(0, -1), Vector2(500, 1030), Vector2(1920, 1080)
        )
        self.assertAlmostEqual(origin.x, 500.0)
        self.assertAlmostEqual(origin.y, 1080.0)  # y=map_height = bottom edge

    def test_left_wall(self):
        # Left wall pushes rightward: (1, 0)
        origin = infer_wall_origin(
            Vector2(1, 0), Vector2(50, 500), Vector2(1920, 1080)
        )
        self.assertAlmostEqual(origin.x, 0.0)  # x=0 = left edge
        self.assertAlmostEqual(origin.y, 500.0)

    def test_right_wall(self):
        # Right wall pushes leftward: (-1, 0)
        origin = infer_wall_origin(
            Vector2(-1, 0), Vector2(1870, 500), Vector2(1920, 1080)
        )
        self.assertAlmostEqual(origin.x, 1920.0)  # x=map_width = right edge
        self.assertAlmostEqual(origin.y, 500.0)

    def test_diagonal_force_resolves_to_dominant_axis(self):
        # Force (0.3, 0.7) — y dominant → top wall
        origin = infer_wall_origin(
            Vector2(0.3, 0.7), Vector2(500, 50), Vector2(1920, 1080)
        )
        self.assertAlmostEqual(origin.y, 0.0, msg="Y-dominant force should resolve to top wall")

    def test_diagonal_x_dominant(self):
        # Force (0.8, 0.2) — x dominant → left wall
        origin = infer_wall_origin(
            Vector2(0.8, 0.2), Vector2(50, 500), Vector2(1920, 1080)
        )
        self.assertAlmostEqual(origin.x, 0.0, msg="X-dominant force should resolve to left wall")


class TestCanvasDataFlow(unittest.TestCase):
    """Integration: verify canvas simulation correctly reads force results."""

    def test_empty_results(self):
        draw = simulate_canvas_draw([], Vector2(500, 500), Vector2(1920, 1080))
        self.assertEqual(len(draw["entity_arrows"]), 0)
        self.assertEqual(len(draw["boundary_arrows"]), 0)
        self.assertIsNone(draw["sum_arrow"])

    def test_single_consumable_produces_arrow(self):
        # Place consumable very close (20px) so force magnitude exceeds arrow threshold
        # At 20px: dist_sq=400, force=normalized/400*10*1.0=0.025, arrow_len=0.025*150=3.75
        # Still below MIN_LEN=4. Use consumable_weight=2.0 to push over: 0.05*150=7.5 > 4
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            consumables=[MockEntity(position=Vector2(520, 500))],
            consumable_weight=2.0,
        )
        _, results = fc.run_all_calculators(ctx)
        draw = simulate_canvas_draw(results, Vector2(500, 500), Vector2(1920, 1080))

        # Should have at least 1 entity arrow (consumable)
        self.assertGreater(len(draw["entity_arrows"]), 0)
        # Arrow should be green (consumable)
        self.assertEqual(draw["entity_arrows"][0]["color"], "consumable_green")
        # Sum arrow should exist and point toward consumable
        self.assertIsNotNone(draw["sum_arrow"])

    def test_boundary_arrows_at_wall_edges(self):
        # Player at (30, 30) with higher bumper_weight to ensure arrows render
        # At dist=30: dist_sq=900, force=push_dir/900*8.0≈0.0089, arrow=0.0089*150=1.33
        # Still below MIN_LEN. Use bumper_weight=30 and bumper_distance=200:
        # force=push_dir/900*30=0.033, arrow=0.033*150=5.0 > 4.0
        ctx = build_ctx(
            player_pos=Vector2(30, 30),
            bumper_weight=30.0,
            bumper_distance=200.0,
        )
        _, results = fc.run_all_calculators(ctx)
        draw = simulate_canvas_draw(results, Vector2(30, 30), Vector2(1920, 1080))

        # Should have boundary arrows for top and left walls
        self.assertGreaterEqual(len(draw["boundary_arrows"]), 2)

        walls_found = {a["wall"] for a in draw["boundary_arrows"]}
        self.assertIn("top", walls_found, "Top wall arrow should be present near top edge")
        self.assertIn("left", walls_found, "Left wall arrow should be present near left edge")

        # Verify origins are at wall edges, not at player position
        for arrow in draw["boundary_arrows"]:
            if arrow["wall"] == "top":
                self.assertAlmostEqual(arrow["origin"].y, 0.0)
            elif arrow["wall"] == "left":
                self.assertAlmostEqual(arrow["origin"].x, 0.0)

    def test_seven_types_processed(self):
        ctx = build_ctx(
            consumables=[MockEntity(position=Vector2(600, 500))],
        )
        _, results = fc.run_all_calculators(ctx)
        draw = simulate_canvas_draw(results, Vector2(500, 500), Vector2(1920, 1080))
        self.assertEqual(draw["type_count"], 7)

    def test_sum_vector_matches_movement(self):
        """Sum vector from canvas should match the AI movement vector."""
        ctx = build_ctx(
            player_pos=Vector2(500, 500),
            consumables=[MockEntity(position=Vector2(700, 500))],
            golds=[MockEntity(position=Vector2(300, 500))],
        )
        move_vec, results = fc.run_all_calculators(ctx)
        draw = simulate_canvas_draw(results, Vector2(500, 500), Vector2(1920, 1080))

        self.assertAlmostEqual(draw["sum_vector"].x, move_vec.x, places=5)
        self.assertAlmostEqual(draw["sum_vector"].y, move_vec.y, places=5)

    def test_no_banned_patterns_in_canvas(self):
        """Meta-test: verify the canvas logic module contains no force calculation."""
        import inspect
        from tests.sim import canvas_logic
        source = inspect.getsource(canvas_logic)
        banned = [
            "_entity_spawner", "_consumables", "_active_golds",
            "EnemyProjectiles", "circle_size_multiplier",
            "item_weight_squared", "projectile_weight_squared",
            "SpawningAttackBehavior", "bumper_x", "bumper_y",
        ]
        for pattern in banned:
            self.assertNotIn(pattern, source,
                             f"Canvas logic should not contain '{pattern}'")


if __name__ == "__main__":
    unittest.main()
