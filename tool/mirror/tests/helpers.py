"""Shared builders for the mirror test-suite."""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

from mergedrop.block_state import BlockState  # noqa: E402
from mergedrop.game_board import GameBoard  # noqa: E402

ROWS = 12
COLUMNS = 6


def empty_board(rows=ROWS, columns=COLUMNS):
    return GameBoard(rows, columns)


def board_from(rows, columns, grid):
    """grid[row][col] = value or 0."""
    blocks = []
    next_id = 1
    for r in range(rows):
        for c in range(columns):
            v = grid[r][c]
            if v:
                blocks.append(BlockState(next_id, v, r, c))
                next_id += 1
    return GameBoard(rows, columns, blocks)


def values(board):
    return [[(b.value if b else None) for b in row] for row in board.cells]


def bottom_row_values(board):
    return [board.cells[board.rows - 1][c].value
            if board.cells[board.rows - 1][c] else None
            for c in range(board.columns)]


def column_values(board, column):
    return [board.cells[r][column].value if board.cells[r][column] else None
            for r in range(board.rows)]
