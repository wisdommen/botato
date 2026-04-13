"""Unit + scenario tests for AdaptiveWeightController.

Covers all ADAPT requirements:
  ADAPT-01: EMA-based performance metrics (damage_rate, health_ratio)
  ADAPT-02: Dynamic weight multipliers, clamped to [0.7, 1.3]
  ADAPT-03: Hard reset at wave boundaries
  ADAPT-05: Smooth transitions (~3s convergence at 60fps)
"""

import unittest

from tests.sim.adaptive_controller import AdaptiveController

DELTA = 1.0 / 60.0
MID_WAVE_TIME = 25.0


class TestEMAMetrics(unittest.TestCase):
    """ADAPT-01: EMA metrics track damage_rate and health_ratio correctly."""

    def test_initial_state(self):
        """New controller has ema_damage_rate=0.0 and ema_health_ratio=1.0."""
        ctrl = AdaptiveController()
        self.assertAlmostEqual(ctrl.ema_damage_rate, 0.0)
        self.assertAlmostEqual(ctrl.ema_health_ratio, 1.0)

    def test_damage_rate_increases_on_hp_loss(self):
        """Feed 100hp then 90hp -> ema_damage_rate > 0."""
        ctrl = AdaptiveController()
        # Frame 1: initialize prev_health
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        # Frame 2: HP drops by 10
        ctrl.update(cur_hp=90.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        self.assertGreater(ctrl.ema_damage_rate, 0.0)

    def test_health_ratio_tracks_current_hp(self):
        """Feed hp_ratio=0.5 for 60 frames -> ema converges near 0.5."""
        ctrl = AdaptiveController()
        for _ in range(60):
            ctrl.update(cur_hp=50.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        # After 60 frames at EMA_RATE=0.02, converges ~70% toward 0.5 from 1.0
        # Expected: ema_health_ratio < 0.85 (significantly below initial 1.0)
        self.assertLess(ctrl.ema_health_ratio, 0.85)
        self.assertGreater(ctrl.ema_health_ratio, 0.4)

    def test_first_frame_sentinel(self):
        """First update with _prev_health=-1 produces damage_rate=0 (no spike)."""
        ctrl = AdaptiveController()
        ctrl.update(cur_hp=10.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        # With sentinel, no damage spike on first frame
        self.assertAlmostEqual(ctrl.ema_damage_rate, 0.0)

    def test_damage_rate_zero_on_healing(self):
        """HP increases between frames -> damage_rate stays at 0 (clamped, no negative)."""
        ctrl = AdaptiveController()
        # Initialize
        ctrl.update(cur_hp=80.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        initial_damage_rate = ctrl.ema_damage_rate
        # HP increases (healing)
        ctrl.update(cur_hp=90.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        # damage_rate should not increase due to healing
        self.assertLessEqual(ctrl.ema_damage_rate, initial_damage_rate + 0.001)


class TestMultiplierClamp(unittest.TestCase):
    """ADAPT-02: Multipliers always stay within [0.7, 1.3]."""

    def test_multipliers_never_exceed_max(self):
        """Run 1000 frames with constant heavy damage -> all multipliers <= 1.3."""
        ctrl = AdaptiveController()
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        for _ in range(1000):
            ctrl.update(cur_hp=1.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        for force_type in AdaptiveController.DEFENSIVE + AdaptiveController.OFFENSIVE:
            self.assertLessEqual(
                ctrl.get_multiplier(force_type), 1.3,
                f"{force_type} multiplier exceeded 1.3"
            )

    def test_multipliers_never_below_min(self):
        """Run 1000 frames with constant heavy damage -> all multipliers >= 0.7."""
        ctrl = AdaptiveController()
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        for _ in range(1000):
            ctrl.update(cur_hp=1.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        for force_type in AdaptiveController.DEFENSIVE + AdaptiveController.OFFENSIVE:
            self.assertGreaterEqual(
                ctrl.get_multiplier(force_type), 0.7,
                f"{force_type} multiplier went below 0.7"
            )

    def test_unknown_type_returns_one(self):
        """get_multiplier for unknown force type returns 1.0."""
        ctrl = AdaptiveController()
        result = ctrl.get_multiplier("nonexistent")
        self.assertAlmostEqual(result, 1.0)


class TestMultiplierShift(unittest.TestCase):
    """ADAPT-02: Multipliers shift correctly based on threat level."""

    def _run_frames_at_hp(self, ctrl, hp_ratio, n_frames):
        """Helper: run n_frames with fixed hp_ratio."""
        hp = hp_ratio * 100.0
        for _ in range(n_frames):
            ctrl.update(cur_hp=hp, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)

    def test_defensive_increase_under_damage(self):
        """180 frames at hp_ratio=0.3 -> projectile multiplier > 1.0."""
        ctrl = AdaptiveController()
        # Initialize at full health first
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        self._run_frames_at_hp(ctrl, 0.3, 180)
        self.assertGreater(ctrl.get_multiplier("projectile"), 1.0)

    def test_offensive_decrease_under_damage(self):
        """180 frames at hp_ratio=0.3 -> item multiplier < 1.0."""
        ctrl = AdaptiveController()
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        self._run_frames_at_hp(ctrl, 0.3, 180)
        self.assertLess(ctrl.get_multiplier("item"), 1.0)

    def test_defensive_decrease_when_safe(self):
        """After damage, 180 frames at hp_ratio=1.0 -> projectile multiplier < initial damage level."""
        ctrl = AdaptiveController()
        # First accumulate some defensive multiplier
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        self._run_frames_at_hp(ctrl, 0.2, 100)
        damaged_mult = ctrl.get_multiplier("projectile")
        # Now recover at full health
        self._run_frames_at_hp(ctrl, 1.0, 180)
        recovered_mult = ctrl.get_multiplier("projectile")
        # Defensive multiplier should decrease when safe
        self.assertLess(recovered_mult, damaged_mult)

    def test_offensive_increase_when_safe(self):
        """After damage, 180 frames at hp_ratio=1.0 -> item multiplier recovers toward 1.0."""
        ctrl = AdaptiveController()
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        self._run_frames_at_hp(ctrl, 0.2, 100)
        damaged_mult = ctrl.get_multiplier("item")
        self._run_frames_at_hp(ctrl, 1.0, 180)
        recovered_mult = ctrl.get_multiplier("item")
        # Offensive multiplier should increase (recover) when safe
        self.assertGreater(recovered_mult, damaged_mult)

    def test_two_group_split(self):
        """All DEFENSIVE types shift same direction, all OFFENSIVE types shift opposite."""
        ctrl = AdaptiveController()
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        self._run_frames_at_hp(ctrl, 0.2, 300)

        # All defensive should be above 1.0
        for t in AdaptiveController.DEFENSIVE:
            self.assertGreater(ctrl.get_multiplier(t), 1.0,
                               f"DEFENSIVE type '{t}' should be > 1.0 under damage")
        # All offensive should be below 1.0
        for t in AdaptiveController.OFFENSIVE:
            self.assertLess(ctrl.get_multiplier(t), 1.0,
                            f"OFFENSIVE type '{t}' should be < 1.0 under damage")


class TestWaveReset(unittest.TestCase):
    """ADAPT-03: Adaptive state hard-resets at wave boundaries."""

    def _accumulate_state(self, ctrl, n_frames=100):
        """Helper: run n_frames of damage to build up state."""
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        for _ in range(n_frames):
            ctrl.update(cur_hp=30.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)

    def test_reset_clears_ema(self):
        """After accumulating state, call reset -> ema_damage_rate=0, ema_health_ratio=1.0."""
        ctrl = AdaptiveController()
        self._accumulate_state(ctrl)
        # State should be non-baseline
        self.assertGreater(ctrl.ema_damage_rate, 0.0)
        # Trigger wave reset by transitioning from low time_left to high
        ctrl.update(cur_hp=80.0, max_hp=100.0, wave_time_left=0.03, delta=DELTA)
        ctrl.update(cur_hp=80.0, max_hp=100.0, wave_time_left=25.0, delta=DELTA)
        # EMA should be reset
        self.assertAlmostEqual(ctrl.ema_damage_rate, 0.0)
        self.assertAlmostEqual(ctrl.ema_health_ratio, 1.0)

    def test_reset_clears_multipliers(self):
        """After shifting multipliers, reset -> all multipliers=1.0."""
        ctrl = AdaptiveController()
        self._accumulate_state(ctrl)
        # Multipliers shifted from baseline
        self.assertGreater(ctrl.get_multiplier("projectile"), 1.0)
        # Wave transition
        ctrl.update(cur_hp=80.0, max_hp=100.0, wave_time_left=0.03, delta=DELTA)
        ctrl.update(cur_hp=80.0, max_hp=100.0, wave_time_left=25.0, delta=DELTA)
        for force_type in AdaptiveController.DEFENSIVE + AdaptiveController.OFFENSIVE:
            self.assertAlmostEqual(
                ctrl.get_multiplier(force_type), 1.0, places=5,
                msg=f"{force_type} multiplier not reset to 1.0 after wave boundary"
            )

    def test_wave_boundary_detection(self):
        """Simulate timer going from 0.03 to 25.0 -> triggers reset."""
        ctrl = AdaptiveController()
        self._accumulate_state(ctrl)
        pre_reset_damage_rate = ctrl.ema_damage_rate
        # Simulate wave end: time_left drops to near zero
        ctrl.update(cur_hp=80.0, max_hp=100.0, wave_time_left=0.03, delta=DELTA)
        # Simulate new wave start: time_left jumps to high value
        ctrl.update(cur_hp=80.0, max_hp=100.0, wave_time_left=25.0, delta=DELTA)
        # Confirm reset happened
        self.assertAlmostEqual(ctrl.ema_damage_rate, 0.0)
        self.assertLess(ctrl.ema_damage_rate, pre_reset_damage_rate)

    def test_no_false_reset_mid_wave(self):
        """Timer going from 10.0 to 5.0 -> no reset."""
        ctrl = AdaptiveController()
        self._accumulate_state(ctrl)
        pre_state_damage_rate = ctrl.ema_damage_rate
        # Mid-wave: time_left decreasing normally
        ctrl.update(cur_hp=30.0, max_hp=100.0, wave_time_left=10.0, delta=DELTA)
        ctrl.update(cur_hp=30.0, max_hp=100.0, wave_time_left=5.0, delta=DELTA)
        # No reset: state should still be non-zero
        self.assertGreater(ctrl.ema_damage_rate, 0.0)

    def test_no_reset_on_low_to_low(self):
        """Timer going from 0.04 to 0.03 -> no reset (both below threshold)."""
        ctrl = AdaptiveController()
        self._accumulate_state(ctrl)
        pre_mult = ctrl.get_multiplier("projectile")
        # Both values below 0.05 (wave ending, not a transition to new wave)
        ctrl.update(cur_hp=30.0, max_hp=100.0, wave_time_left=0.04, delta=DELTA)
        ctrl.update(cur_hp=30.0, max_hp=100.0, wave_time_left=0.03, delta=DELTA)
        # Multiplier should still be shifted (no reset)
        self.assertGreater(ctrl.get_multiplier("projectile"), 1.0)


class TestConvergenceRate(unittest.TestCase):
    """ADAPT-05: Multipliers converge to within 5% of target within 300 frames."""

    def test_convergence_within_300_frames(self):
        """At constant hp_ratio=0.2 for 300 frames, defensive multiplier within 5% of 1.3 target."""
        ctrl = AdaptiveController()
        # Initialize
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        # Run 300 frames at very low HP (threat_level near 1.0 -> target near 1.3)
        for _ in range(300):
            ctrl.update(cur_hp=20.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        projectile_mult = ctrl.get_multiplier("projectile")
        # Should be within 5% of 1.3 = 1.235 to 1.3
        target = 1.3
        self.assertGreater(projectile_mult, target * 0.95,
                           f"Projectile multiplier {projectile_mult:.4f} not within 5% of target {target}")

    def test_smooth_no_oscillation(self):
        """Multiplier values are monotonically increasing under constant threat."""
        ctrl = AdaptiveController()
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        prev_mult = ctrl.get_multiplier("projectile")
        # Under constant heavy damage, defensive multiplier should only increase
        for _ in range(200):
            ctrl.update(cur_hp=10.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
            current_mult = ctrl.get_multiplier("projectile")
            self.assertGreaterEqual(
                current_mult, prev_mult - 0.0001,
                f"Multiplier decreased: {current_mult:.6f} < {prev_mult:.6f}"
            )
            prev_mult = current_mult


class TestAdaptiveScenarios(unittest.TestCase):
    """End-to-end scenario tests for adaptive behavior."""

    def test_sustained_damage_scenario(self):
        """5 seconds of hp dropping from 1.0 to 0.3 -> defensive weights at ~1.3, offensive at ~0.7."""
        ctrl = AdaptiveController()
        frames = 300  # 5s at 60fps
        # Initialize
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        # Simulate: HP consistently at 20% (low health = high threat)
        for _ in range(frames):
            ctrl.update(cur_hp=20.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        # Defensive multipliers should be near 1.3
        for t in AdaptiveController.DEFENSIVE:
            mult = ctrl.get_multiplier(t)
            self.assertGreater(mult, 1.2,
                               f"After sustained damage, {t} multiplier={mult:.3f} should be near 1.3")
        # Offensive multipliers should be near 0.7
        for t in AdaptiveController.OFFENSIVE:
            mult = ctrl.get_multiplier(t)
            self.assertLess(mult, 0.8,
                            f"After sustained damage, {t} multiplier={mult:.3f} should be near 0.7")

    def test_recovery_scenario(self):
        """After heavy damage, 5 seconds at full hp -> weights return near 1.0."""
        ctrl = AdaptiveController()
        # Phase 1: Build up defensive multipliers with 300 frames of damage
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        for _ in range(300):
            ctrl.update(cur_hp=20.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        # Confirm defensive were elevated
        self.assertGreater(ctrl.get_multiplier("projectile"), 1.2)
        # Phase 2: 5 seconds at full HP (safe)
        for _ in range(300):
            ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        # Multipliers should recover significantly toward 1.0
        for t in AdaptiveController.DEFENSIVE:
            mult = ctrl.get_multiplier(t)
            self.assertLess(mult, 1.15,
                            f"After recovery, {t} multiplier={mult:.3f} should recover toward 1.0")

    def test_wave_transition_scenario(self):
        """Accumulate state, trigger wave reset, verify clean slate."""
        ctrl = AdaptiveController()
        # Accumulate state
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        for _ in range(200):
            ctrl.update(cur_hp=20.0, max_hp=100.0, wave_time_left=MID_WAVE_TIME, delta=DELTA)
        # Confirm non-baseline state
        self.assertGreater(ctrl.get_multiplier("projectile"), 1.0)
        self.assertLess(ctrl.get_multiplier("item"), 1.0)
        # Trigger wave transition: time_left goes near-zero then high
        ctrl.update(cur_hp=20.0, max_hp=100.0, wave_time_left=0.03, delta=DELTA)
        ctrl.update(cur_hp=100.0, max_hp=100.0, wave_time_left=25.0, delta=DELTA)
        # All multipliers must be at baseline
        for t in AdaptiveController.DEFENSIVE + AdaptiveController.OFFENSIVE:
            self.assertAlmostEqual(ctrl.get_multiplier(t), 1.0, places=5,
                                   msg=f"{t} should be 1.0 after wave reset")
        # EMA should be at baseline
        self.assertAlmostEqual(ctrl.ema_damage_rate, 0.0)
        self.assertAlmostEqual(ctrl.ema_health_ratio, 1.0)


if __name__ == "__main__":
    unittest.main()
