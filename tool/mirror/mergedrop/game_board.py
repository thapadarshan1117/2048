"""Mirror of lib/features/game/domain/game_board.dart."""
from .block_state import BlockState


class FormatException_(Exception):
    pass


class GameBoard:
    __slots__ = ("rows", "columns", "cells")

    def __init__(self, rows, columns, blocks=None):
        self.rows = rows
        self.columns = columns
        self.cells = [[None] * columns for _ in range(rows)]
        for b in blocks or ():
            assert 0 <= b.row < rows and 0 <= b.column < columns, "block outside board"
            self.cells[b.row][b.column] = b

    # --- queries -----------------------------------------------------------
    def is_in_bounds(self, row, column):
        return 0 <= row < self.rows and 0 <= column < self.columns

    def get_block(self, row, column):
        if not self.is_in_bounds(row, column):
            return None
        return self.cells[row][column]

    def block_by_id(self, block_id):
        for row in self.cells:
            for b in row:
                if b is not None and b.id == block_id:
                    return b
        return None

    def is_empty(self, row, column):
        return self.get_block(row, column) is None

    def is_full(self, row, column):
        return not self.is_empty(row, column)

    @property
    def blocks(self):
        out = []
        for row in self.cells:
            out.extend(b for b in row if b is not None)
        return out

    @property
    def block_count(self):
        return len(self.blocks)

    @property
    def is_completely_full(self):
        return self.block_count == self.rows * self.columns

    def find_landing_row(self, column):
        if column < 0 or column >= self.columns:
            return None
        for row in range(self.rows - 1, -1, -1):
            if self.cells[row][column] is None:
                return row
        return None

    @property
    def has_legal_drop(self):
        return any(self.find_landing_row(c) is not None for c in range(self.columns))

    def get_neighbors(self, row, column):
        out = []
        for d in (-1, 1):
            b = self.get_block(row + d, column)
            if b is not None:
                out.append(b)
            b = self.get_block(row, column + d)
            if b is not None:
                out.append(b)
        return out

    def connected_group_of(self, row, column):
        seed = self.get_block(row, column)
        if seed is None:
            return set()
        seen = {seed.id}
        stack = [seed]
        group = set()
        while stack:
            current = stack.pop()
            group.add(current)
            for n in self.get_neighbors(current.row, current.column):
                if n.value != seed.value:
                    continue
                if n.id in seen:
                    continue
                seen.add(n.id)
                stack.append(n)
        return group

    # --- transitions -------------------------------------------------------
    def _copy_grid(self):
        return [list(row) for row in self.cells]

    def with_block(self, block):
        if not self.is_in_bounds(block.row, block.column):
            return self
        grid = self._copy_grid()
        grid[block.row][block.column] = block
        return GameBoard.from_cells(self.rows, self.columns, grid)

    def without_block(self, block_id):
        grid = self._copy_grid()
        changed = False
        for r in range(self.rows):
            for c in range(self.columns):
                b = grid[r][c]
                if b is not None and b.id == block_id:
                    grid[r][c] = None
                    changed = True
        if not changed:
            return self
        return GameBoard.from_cells(self.rows, self.columns, grid)

    def cleared(self):
        return GameBoard(self.rows, self.columns)

    def clone(self):
        return GameBoard.from_cells(self.rows, self.columns, self._copy_grid())

    @staticmethod
    def from_cells(rows, columns, cells):
        board = GameBoard.__new__(GameBoard)
        board.rows = rows
        board.columns = columns
        board.cells = cells
        return board

    # --- serialisation -----------------------------------------------------
    def to_json(self):
        return {
            "rows": self.rows,
            "columns": self.columns,
            "cells": [[(self.cells[r][c].value if self.cells[r][c] else 0)
                       for c in range(self.columns)] for r in range(self.rows)],
        }

    @staticmethod
    def from_json(data):
        rows = int(data["rows"])
        columns = int(data["columns"])
        raw = data["cells"]
        if len(raw) != rows:
            raise FormatException_("row mismatch")
        next_id = 1
        blocks = []
        for r in range(rows):
            if len(raw[r]) != columns:
                raise FormatException_("column mismatch")
            for c in range(columns):
                value = int(raw[r][c])
                if value <= 0:
                    continue
                blocks.append(BlockState(next_id, value, r, c))
                next_id += 1
        return GameBoard(rows, columns, blocks)

    def to_value_grid(self):
        return [[(self.cells[r][c].value if self.cells[r][c] else None)
                 for c in range(self.columns)] for r in range(self.rows)]

    def __repr__(self):
        lines = ["GameBoard(%dx%d)" % (self.rows, self.columns)]
        for row in self.cells:
            lines.append(" ".join(str(b.value if b else 0).rjust(5) for b in row))
        return "\n".join(lines)
