"""Mirror of lib/features/game/domain/block_generator.dart."""
from .rng import Rng, weighted_index


class BlockGenerator:
    def __init__(self, profile, seed=None, rng=None):
        self.profile = profile
        self.rng = rng if rng is not None else Rng(1 if seed is None else seed)
        self._values = profile.spawnable_values
        self._weights = [float(profile.spawn_weights.get(v, 0)) for v in self._values]
        self._queue = []

    def _draw(self):
        if self.profile.spawn_probability < 1.0 and self.rng.next_double() > self.profile.spawn_probability:
            return self.profile.min_spawn_value
        index = weighted_index(self._weights, self.rng.next_double())
        if index < 0 or index >= len(self._values):
            return self.profile.min_spawn_value
        return self._values[index]

    def _fill(self, count):
        while len(self._queue) < count:
            self._queue.append(self._draw())

    def peek(self):
        self._fill(1)
        return self._queue[0]

    def peek_ahead(self, count=2):
        self._fill(count)
        return list(self._queue[:count])

    def next(self):
        self._fill(1)
        return self._queue.pop(0)

    def clone(self):
        g = BlockGenerator(self.profile, rng=Rng(self.rng.state))
        g._queue = list(self._queue)
        return g

    def next_batch(self, count):
        return [self.next() for _ in range(count)]

    def sample_distribution(self, sample_size):
        counts = {}
        for _ in range(sample_size):
            v = self.next()
            counts[v] = counts.get(v, 0) + 1
        return {k: v / sample_size for k, v in counts.items()}
