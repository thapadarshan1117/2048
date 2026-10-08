"""Mirror of lib/features/game/domain/rng.dart (32-bit xorshift)."""

MASK32 = 0xFFFFFFFF


class Rng:
    __slots__ = ("_state",)

    def __init__(self, seed=1):
        s = seed & MASK32
        self._state = s if s != 0 else 0x9E3779B9

    @property
    def state(self):
        return self._state

    def fork(self, salt=0):
        return Rng((self._state ^ ((salt * 0x85EBCA6B) & MASK32)) & MASK32)

    def next_uint32(self):
        x = self._state
        x ^= (x << 13) & MASK32
        x ^= x >> 17
        x ^= (x << 5) & MASK32
        self._state = x & MASK32
        return self._state

    def next_double(self):
        return self.next_uint32() / 4294967296.0

    def next_int_below(self, max_value):
        if max_value <= 0:
            return 0
        v = int(self.next_double() * max_value)
        return min(max(v, 0), max_value - 1)

    def next_bool(self, probability=0.5):
        return self.next_double() < probability

    def pick(self, items):
        if not items:
            return None
        return items[self.next_int_below(len(items))]

    def shuffle(self, items):
        for i in range(len(items) - 1, 0, -1):
            j = self.next_int_below(i + 1)
            items[i], items[j] = items[j], items[i]
        return items


def weighted_index(weights, roll):
    """Mirror of Rng.weightedIndex."""
    if not weights:
        return -1
    total = 0.0
    for w in weights:
        if w < 0:
            return -1
        total += w
    if total <= 0:
        return -1
    target = min(max(roll, 0.0), 0.999999) * total
    for i, w in enumerate(weights):
        target -= w
        if target < 0:
            return i
    return len(weights) - 1
