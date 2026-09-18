"""Deterministic seeded randomness for the world model.

Bit-compatible with the shipped Godot prototype implementation
(`scripts/domain/rng.gd` + `scripts/domain/seeded_roll.gd`, read-only reference):

    SeededRng(seed):  state = abs(seed) % 2147483647 ; if 0 -> 1
    next_index(bound): state = (state * 48271) % 2147483647 ; return state % bound
    salt_hash(salt):  digest = 0 ; for ch in salt: digest = digest*31 + ord(ch)
    mixed_seed(seed, salt, tick) = seed*1000003 + tick*97 + salt_hash(salt)
    index(bound, seed, salt, tick) = SeededRng(mixed_seed(seed, salt, 0)).discard(tick).next_index(bound)

GDScript integers are signed 64-bit and wrap; `_wrap64` reproduces that so the
salt hash of long salt strings matches exactly.

Tick semantics
--------------
The parent repository's own rng.gd documents that folding `tick` affinely into
the seed and then taking a single LCG step produces an **arithmetic staircase**
(adjacent ticks differ by a constant `97 * 48271 mod M`), not a random stream.
Its 2026-09-10 fix makes `tick` mean "stream position" via `discard(tick)`, and
that is the semantics implemented here (`index`, `Stream.draw`). `mixed_seed`
keeps the affine form for byte-parity when `tick == 0` and for deriving the
base seed.

Layer identity goes into the SALT (`Stream.layer`), never into `tick`, so that
"layer 3's 5th encounter" and "layer 1's 5th encounter" are independent draws.
"""

from __future__ import annotations

from typing import Iterable, Sequence

M = 2147483647
A = 48271
_INT64_MASK = (1 << 64) - 1
_INT64_SIGN = 1 << 63


def wrap64(value: int) -> int:
    """Emulate GDScript's signed 64-bit integer wraparound."""
    value &= _INT64_MASK
    if value >= _INT64_SIGN:
        value -= (1 << 64)
    return value


def salt_hash(salt: str) -> int:
    digest = 0
    for ch in salt:
        digest = wrap64(digest * 31 + ord(ch))
    return digest


def mixed_seed(seed: int, salt: str, tick: int = 0) -> int:
    return wrap64(wrap64(wrap64(seed) * 1000003) + wrap64(tick) * 97 + salt_hash(salt))


def mixed_seed_int(seed: int, salt: int, tick: int = 0) -> int:
    return wrap64(wrap64(wrap64(seed) * 1000003) + wrap64(tick) * 97 + wrap64(wrap64(salt) * 193))


class SeededRng:
    """The Lehmer LCG stream itself (one linear congruential sequence)."""

    def __init__(self, seed_value: int):
        state = abs(wrap64(seed_value)) % M
        self._state = state if state != 0 else 1

    @property
    def state(self) -> int:
        return self._state

    def next_index(self, size: int) -> int:
        if size <= 0:
            raise ValueError("next_index requires size > 0")
        self._state = (self._state * A) % M
        return self._state % size

    def discard(self, count: int) -> None:
        for _ in range(max(int(count), 0)):
            self._state = (self._state * A) % M


def index(bound: int, seed: int, salt: str, tick: int) -> int:
    """Stateless draw: the `tick`-th draw of the (seed, salt) stream."""
    if bound <= 1:
        return 0
    rng = SeededRng(mixed_seed(seed, salt, 0))
    rng.discard(tick)
    return rng.next_index(bound)


class Stream:
    """A stateful (seed, salt) draw stream.

    Callers advance it in draw order; the position is recorded in the run ledger
    so a run can be replayed from any checkpoint.
    """

    def __init__(self, seed: int, salt: str, layer: int | None = None, position: int = 0):
        self.seed = int(seed)
        self.layer = layer
        self.salt = salt if layer is None else f"L{int(layer)}:{salt}"
        self._rng = SeededRng(mixed_seed(self.seed, self.salt, 0))
        self.position = 0
        if position:
            self.discard(position)

    # -- primitives -------------------------------------------------------
    def discard(self, count: int) -> None:
        self._rng.discard(count)
        self.position += max(int(count), 0)

    def draw(self, bound: int) -> int:
        if bound <= 1:
            self.position += 0
            return 0
        value = self._rng.next_index(bound)
        self.position += 1
        return value

    def chance(self, percent: float) -> bool:
        """`percent` is 0-100. Uses a 10000-bucket roll for sub-percent safety."""
        if percent <= 0:
            return False
        if percent >= 100:
            return True
        return self.draw(10000) < int(round(percent * 100))

    def pick(self, items: Sequence) -> object:
        if not items:
            raise ValueError("pick requires a non-empty sequence")
        return items[self.draw(len(items))]

    def weighted_pick(self, weights: Sequence[tuple[object, float]]) -> object:
        """`weights` is a sequence of (item, weight). Weight <= 0 entries are ignored."""
        usable = [(item, float(w)) for item, w in weights if float(w) > 0]
        if not usable:
            raise ValueError("weighted_pick requires at least one positive weight")
        total = sum(w for _, w in usable)
        roll = self.draw(int(round(total * 1000)))
        acc = 0.0
        for item, w in usable:
            acc += w * 1000
            if roll < acc:
                return item
        return usable[-1][0]

    def shuffled(self, items: Iterable) -> list:
        pool = list(items)
        for i in range(len(pool) - 1, 0, -1):
            j = self.draw(i + 1)
            pool[i], pool[j] = pool[j], pool[i]
        return pool

    def state(self) -> dict:
        return {"seed": self.seed, "salt": self.salt, "position": self.position,
                "lcg_state": self._rng.state}

    @classmethod
    def from_state(cls, payload: dict) -> "Stream":
        stream = cls(int(payload["seed"]), str(payload["salt"]))
        stream._rng._state = int(payload["lcg_state"])
        stream.position = int(payload["position"])
        return stream
