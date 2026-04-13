"""Python port of AdaptiveWeightController (GDScript).

Mirrors the GDScript AdaptiveWeightController line-for-line, establishing
behavioral contracts that the GDScript implementation must satisfy.

This is the Wave 1 test scaffold for Phase 3 (ADAPT-01 through ADAPT-05).

Algorithm:
  - EMA-based health metrics update per frame at rate 0.02 (D-11)
  - Two groups: DEFENSIVE (projectile, boss, bumper) and OFFENSIVE (consumable, item, tree)
  - Defensive multipliers increase toward 1.3 under high threat; decrease toward 0.7 when safe
  - Offensive multipliers decrease toward 0.7 under high threat; increase toward 1.3 when safe
  - All multipliers clamped to [0.7, 1.3] (D-10)
  - Wave boundary (prev_time < 0.05 AND current_time > 1.0) triggers hard reset (D-03, D-12)
  - Force types not in either group (e.g. gold, boundary) return 1.0 from get_multiplier
"""

from __future__ import annotations


def _lerp(a: float, b: float, t: float) -> float:
    """Linear interpolation: a + (b - a) * t. Mirrors GDScript lerp()."""
    return a + (b - a) * t


class AdaptiveController:
    """Python port of the GDScript AdaptiveWeightController node.

    Tracks EMA-smoothed performance metrics and adjusts per-type weight
    multipliers to guide AI adaptation during a wave.

    Group assignments (D-09):
      DEFENSIVE: projectile, boss, bumper — increase toward 1.3 under damage
      OFFENSIVE: consumable, item, tree  — decrease toward 0.7 under damage
    """

    DEFENSIVE = ["projectile", "boss", "bumper"]
    OFFENSIVE = ["consumable", "item", "tree"]

    EMA_RATE = 0.02   # D-11: ~3s convergence at 60fps
    MULT_MIN = 0.7    # D-10
    MULT_MAX = 1.3    # D-10

    def __init__(self) -> None:
        self._reset()

    def _reset(self) -> None:
        """Hard-reset all EMA and multiplier state to baseline. Called at wave boundaries."""
        self.ema_damage_rate: float = 0.0
        self.ema_health_ratio: float = 1.0
        self._prev_health: float = -1.0         # -1 sentinel: first-frame guard (Pitfall 1)
        self._prev_wave_time_left: float = 1.0  # Initialize > 0.05 to avoid spurious reset
        self._multipliers: dict[str, float] = {
            t: 1.0 for t in self.DEFENSIVE + self.OFFENSIVE
        }

    def get_multiplier(self, force_type: str) -> float:
        """Return the current multiplier for a force type.

        Returns 1.0 (no-op) for unknown types — mirrors GDScript dict.get(key, 1.0).
        """
        return self._multipliers.get(force_type, 1.0)

    def update(
        self,
        cur_hp: float,
        max_hp: float,
        wave_time_left: float,
        delta: float = 1.0 / 60.0,
    ) -> None:
        """Update EMA metrics and multipliers for one frame.

        Args:
            cur_hp: Current player HP.
            max_hp: Maximum player HP.
            wave_time_left: Seconds remaining in the current wave.
            delta: Frame delta in seconds (default 1/60).
        """
        # Wave boundary detection (D-03, D-12):
        # Previous time was near-zero (<0.05) and current time jumped above 1.0
        # → a new wave has started; hard-reset and return (Pattern 5 from RESEARCH.md)
        if self._prev_wave_time_left < 0.05 and wave_time_left > 1.0:
            self._reset()
            self._prev_wave_time_left = wave_time_left
            return

        self._prev_wave_time_left = wave_time_left
        self._update_ema(cur_hp, max_hp, delta)
        self._update_multipliers()

    def _update_ema(self, cur_hp: float, max_hp: float, delta: float) -> None:
        """Compute raw metrics and apply EMA smoothing (D-01, D-11).

        First-frame sentinel: if _prev_health < 0, initialize without computing
        damage_rate to prevent a false spike (Pitfall 1 from RESEARCH.md).
        """
        # First-frame guard: initialize _prev_health without computing damage
        if self._prev_health < 0.0:
            self._prev_health = cur_hp
            # Still update health_ratio EMA so it starts converging
            raw_health_ratio = cur_hp / max_hp if max_hp > 0.0 else 1.0
            self.ema_health_ratio = _lerp(self.ema_health_ratio, raw_health_ratio, self.EMA_RATE)
            return

        # damage_rate: HP lost per second, normalized to max_hp → [0, 1]
        # Clamped to [0, 1]: healing produces 0 damage rate, not negative (D-01)
        raw_damage_rate = (self._prev_health - cur_hp) / (delta * max_hp) if max_hp > 0.0 else 0.0
        raw_damage_rate = max(0.0, min(1.0, raw_damage_rate))

        # health_ratio: fraction of max HP remaining → [0, 1]
        raw_health_ratio = cur_hp / max_hp if max_hp > 0.0 else 1.0

        self._prev_health = cur_hp

        # Apply EMA: ema = lerp(ema, raw, rate)
        self.ema_damage_rate = _lerp(self.ema_damage_rate, raw_damage_rate, self.EMA_RATE)
        self.ema_health_ratio = _lerp(self.ema_health_ratio, raw_health_ratio, self.EMA_RATE)

    def _update_multipliers(self) -> None:
        """Shift multipliers toward their targets based on current threat level (D-09, Pattern 4).

        threat_level = 1.0 - ema_health_ratio
          0.0 = safe (full health)   → DEFENSIVE targets MULT_MIN, OFFENSIVE targets MULT_MAX
          1.0 = dying (0% health)   → DEFENSIVE targets MULT_MAX, OFFENSIVE targets MULT_MIN
        """
        threat_level = 1.0 - self.ema_health_ratio  # [0, 1]: 0 = safe, 1 = dying

        # DEFENSIVE group: increase toward MULT_MAX under threat, decrease toward MULT_MIN when safe
        defensive_target = _lerp(self.MULT_MIN, self.MULT_MAX, threat_level)
        for t in self.DEFENSIVE:
            updated = _lerp(self._multipliers[t], defensive_target, self.EMA_RATE)
            self._multipliers[t] = max(self.MULT_MIN, min(self.MULT_MAX, updated))

        # OFFENSIVE group: decrease toward MULT_MIN under threat, increase toward MULT_MAX when safe
        offensive_target = _lerp(self.MULT_MAX, self.MULT_MIN, threat_level)
        for t in self.OFFENSIVE:
            updated = _lerp(self._multipliers[t], offensive_target, self.EMA_RATE)
            self._multipliers[t] = max(self.MULT_MIN, min(self.MULT_MAX, updated))
