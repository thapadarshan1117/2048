"""Mirror of lib/features/game/domain/merge_engine.dart."""
from .block_state import BlockState
from .game_board import GameBoard
from .score_calculator import merge_score, big_merge_bonus


class BlockMove:
    __slots__ = ("block_id", "from_row", "from_column", "to_row", "to_column")

    def __init__(self, block_id, from_row, from_column, to_row, to_column):
        self.block_id = block_id
        self.from_row = from_row
        self.from_column = from_column
        self.to_row = to_row
        self.to_column = to_column

    @property
    def did_move(self):
        return self.from_row != self.to_row or self.from_column != self.to_column


class MergeEvent:
    __slots__ = ("source_block_ids", "target_block_id", "old_value", "new_value",
                 "row", "column", "chain_step", "score_gained")

    def __init__(self, source_block_ids, target_block_id, old_value, new_value,
                 row, column, chain_step, score_gained):
        self.source_block_ids = source_block_ids
        self.target_block_id = target_block_id
        self.old_value = old_value
        self.new_value = new_value
        self.row = row
        self.column = column
        self.chain_step = chain_step
        self.score_gained = score_gained

    @property
    def is_chain_merge(self):
        return self.chain_step > 0


class BoardTransition:
    __slots__ = ("board", "moves", "merges")

    def __init__(self, board, moves, merges):
        self.board = board
        self.moves = moves
        self.merges = merges

    @property
    def has_merges(self):
        return len(self.merges) > 0


class MergeGroup:
    __slots__ = ("members",)

    def __init__(self, members):
        self.members = members

    @property
    def value(self):
        return self.members[0].value if self.members else 0

    @property
    def size(self):
        return len(self.members)

    @property
    def can_merge(self):
        return len(self.members) >= 2


class MergeResolution:
    __slots__ = ("transitions", "board", "events", "score_gained", "merge_count",
                 "longest_chain", "highest_value", "next_block_id")

    def __init__(self, transitions, board, events, score_gained, merge_count,
                 longest_chain, highest_value, next_block_id):
        self.transitions = transitions
        self.board = board
        self.events = events
        self.score_gained = score_gained
        self.merge_count = merge_count
        self.longest_chain = longest_chain
        self.highest_value = highest_value
        self.next_block_id = next_block_id

    @property
    def had_merges(self):
        return len(self.events) > 0


class MergeEngine:
    def __init__(self, score=None):
        self.score = score

    # --- public API --------------------------------------------------------
    def resolve(self, board, next_block_id, preferred_anchor_block_id=None):
        if board.rows <= 0 or board.columns <= 0:
            return MergeResolution([], GameBoard(0, 0), [], 0, 0, 0, 0, 1)

        current = board
        next_id = max(1, next_block_id)
        highest_existing = self._highest_block_id(board)
        if next_id <= highest_existing:
            next_id = highest_existing + 1
        transitions = []
        events = []
        total_score = 0
        chain_step = 0
        longest_chain = 0
        max_steps = board.rows * board.columns + 2

        for _ in range(max_steps):
            gravity = self.apply_gravity(current)
            current = gravity[0]
            groups = self.find_merge_groups(current)
            if not groups:
                transitions.append(BoardTransition(current, gravity[1], []))
                break

            step_events = []
            step_score = 0
            consumed = set()
            produced = []

            for group in groups:
                if not group.can_merge:
                    continue
                for a, b in self._pair_group(group.members):
                    new_value = a.value * 2
                    anchor = self._anchor_of(a, b, preferred_anchor_block_id)
                    block = BlockState(next_id, new_value, anchor.row, anchor.column)
                    next_id += 1
                    consumed.add(a.id)
                    consumed.add(b.id)
                    produced.append(block)
                    gained = (merge_score(new_value, chain_step)
                              + big_merge_bonus(new_value))
                    step_score += gained
                    step_events.append(MergeEvent(
                        [a.id, b.id], block.id, a.value, new_value,
                        block.row, block.column, chain_step, gained))

            grid = [list(row) for row in current.cells]
            for r in range(current.rows):
                for c in range(current.columns):
                    b = grid[r][c]
                    if b is not None and b.id in consumed:
                        grid[r][c] = None
            for block in produced:
                grid[block.row][block.column] = block
            current = GameBoard.from_cells(current.rows, current.columns, grid)
            events.extend(step_events)
            total_score += step_score
            longest_chain = chain_step + 1
            transitions.append(BoardTransition(current, gravity[1], step_events))
            chain_step += 1

        return MergeResolution(transitions, current, events, total_score,
                               len(events), longest_chain,
                               self.highest_value(current), next_id)

    def apply_gravity(self, board):
        moves = []
        grid = [list(row) for row in board.cells]
        for c in range(board.columns):
            write_row = board.rows - 1
            for r in range(board.rows - 1, -1, -1):
                block = grid[r][c]
                if block is None:
                    continue
                if r != write_row:
                    grid[r][c] = None
                    grid[write_row][c] = block.move_to(write_row, c)
                    moves.append(BlockMove(block.id, r, c, write_row, c))
                write_row -= 1
        return GameBoard.from_cells(board.rows, board.columns, grid), moves

    @staticmethod
    def _highest_block_id(board):
        highest = 0
        for b in board.blocks:
            if b.id > highest:
                highest = b.id
        return highest

    def find_merge_groups(self, board):
        groups = []
        visited = set()
        for r in range(board.rows):
            for c in range(board.columns):
                block = board.cells[r][c]
                if block is None or block.id in visited:
                    continue
                group = board.connected_group_of(r, c)
                for member in group:
                    visited.add(member.id)
                if len(group) >= 2:
                    groups.append(MergeGroup(list(group)))
        return groups

    def highest_value(self, board):
        highest = 0
        for b in board.blocks:
            if b.value > highest:
                highest = b.value
        return highest

    # --- internals ---------------------------------------------------------
    def _pair_group(self, members):
        pool = sorted(members, key=lambda b: (-b.row, b.column))
        pairs = []
        while len(pool) >= 2:
            a = pool.pop(0)
            best = None
            best_distance = 0
            best_is_adjacent = False
            for candidate in pool:
                distance = abs(a.row - candidate.row) + abs(a.column - candidate.column)
                adjacent = distance == 1
                if best is None:
                    best, best_distance, best_is_adjacent = candidate, distance, adjacent
                    continue
                if adjacent and not best_is_adjacent:
                    best, best_distance, best_is_adjacent = candidate, distance, True
                    continue
                if adjacent == best_is_adjacent and distance < best_distance:
                    best, best_distance = candidate, distance
            if best is None:
                break
            pool.remove(best)
            pairs.append((a, best))
        return pairs

    @staticmethod
    def _anchor_of(a, b, preferred_anchor_block_id=None):
        if preferred_anchor_block_id is not None:
            if a.id == preferred_anchor_block_id:
                return a
            if b.id == preferred_anchor_block_id:
                return b
        if a.row != b.row:
            return a if a.row > b.row else b
        return a if a.column < b.column else b
