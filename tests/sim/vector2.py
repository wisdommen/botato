"""Minimal Vector2 matching Godot 3.5 API for simulation testing."""

from __future__ import annotations
import math


class Vector2:
    __slots__ = ("x", "y")

    ZERO: Vector2  # set after class definition

    def __init__(self, x: float = 0.0, y: float = 0.0):
        self.x = float(x)
        self.y = float(y)

    # ── arithmetic ──────────────────────────────────────────────

    def __add__(self, other: Vector2) -> Vector2:
        return Vector2(self.x + other.x, self.y + other.y)

    def __sub__(self, other: Vector2) -> Vector2:
        return Vector2(self.x - other.x, self.y - other.y)

    def __mul__(self, scalar: float) -> Vector2:
        return Vector2(self.x * scalar, self.y * scalar)

    def __rmul__(self, scalar: float) -> Vector2:
        return self.__mul__(scalar)

    def __truediv__(self, scalar: float) -> Vector2:
        return Vector2(self.x / scalar, self.y / scalar)

    def __neg__(self) -> Vector2:
        return Vector2(-self.x, -self.y)

    def __eq__(self, other: object) -> bool:
        if not isinstance(other, Vector2):
            return NotImplemented
        return math.isclose(self.x, other.x, abs_tol=1e-9) and math.isclose(
            self.y, other.y, abs_tol=1e-9
        )

    def __repr__(self) -> str:
        return f"Vector2({self.x:.4f}, {self.y:.4f})"

    # ── geometry ────────────────────────────────────────────────

    def length_squared(self) -> float:
        return self.x * self.x + self.y * self.y

    def length(self) -> float:
        return math.sqrt(self.length_squared())

    def normalized(self) -> Vector2:
        ln = self.length()
        if ln < 1e-10:
            return Vector2(0.0, 0.0)
        return Vector2(self.x / ln, self.y / ln)

    def tangent(self) -> Vector2:
        """Godot 3.5 tangent(): 90-degree CCW rotation → (y, -x)."""
        return Vector2(self.y, -self.x)

    def cross(self, other: Vector2) -> float:
        return self.x * other.y - self.y * other.x

    def dot(self, other: Vector2) -> float:
        return self.x * other.x + self.y * other.y

    def distance_to(self, other: Vector2) -> float:
        return (self - other).length()

    def distance_squared_to(self, other: Vector2) -> float:
        return (self - other).length_squared()

    def rotated(self, angle: float) -> Vector2:
        cos_a = math.cos(angle)
        sin_a = math.sin(angle)
        return Vector2(
            self.x * cos_a - self.y * sin_a,
            self.x * sin_a + self.y * cos_a,
        )

    def is_nan(self) -> bool:
        return math.isnan(self.x) or math.isnan(self.y)


Vector2.ZERO = Vector2(0.0, 0.0)
