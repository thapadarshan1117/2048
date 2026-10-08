"""Mirror of lib/features/game/domain/boosters/*."""
from .game_state import GameState
from .merge_engine import MergeEngine
from .rng import Rng

REJECTION_NO_UNDO = "booster_reject_no_undo"
REJECTION_NO_TARGET = "booster_reject_no_target"
REJECTION_TOO_FEW_BLOCKS = "booster_reject_too_few_blocks"
REJECTION_GAME_OVER = "booster_reject_game_over"

EFFECT_UNDO = "undo"
EFFECT_REMOVE = "remove"
EFFECT_SHUFFLE = "shuffle"
EFFECT_WILDCARD = "wildcard"
EFFECT_UPGRADE = "upgrade"


class BoosterContext:
    __slots__ = ("state", "selected_block_id", "selected_column")

    def __init__(self, state, selected_block_id=None, selected_column=None):
        self.state = state
        self.selected_block_id = selected_block_id
        self.selected_column = selected_column

    def copy_with(self, **kw):
        data = {"state": self.state, "selected_block_id": self.selected_block_id,
                "selected_column": self.selected_column}
        data.update(kw)
        return BoosterContext(**data)


class BoosterOutcome:
    __slots__ = ("state", "effect", "transitions", "affected_block_ids", "applied",
                 "rejection_key")

    def __init__(self, state, effect, transitions=None, affected_block_ids=None,
                 applied=True, rejection_key=None):
        self.state = state
        self.effect = effect
        self.transitions = transitions or []
        self.affected_block_ids = affected_block_ids or []
        self.applied = applied
        self.rejection_key = rejection_key

    @property
    def score_gained(self):
        return sum(m.score_gained for t in self.transitions for m in t.merges)


class BoosterSupport:
    @staticmethod
    def settle(state, engine=None, count_as_move=False):
        engine = engine or MergeEngine()
        resolution = engine.resolve(state.board, state.next_block_id)
        stats = state.stats.apply_drop(
            score_gained=resolution.score_gained, merges=resolution.merge_count,
            longest_chain=resolution.longest_chain,
            board_highest=resolution.highest_value)
        nxt = state.copy_with(
            board=resolution.board, next_block_id=resolution.next_block_id,
            stats=stats, score=stats.score,
            moves_used=state.moves_used + (1 if count_as_move else 0),
            is_game_over=not resolution.board.has_legal_drop)
        return nxt, resolution.transitions

    @staticmethod
    def apply_resolution(state, resolution):
        stats = state.stats.apply_drop(
            score_gained=resolution.score_gained, merges=resolution.merge_count,
            longest_chain=resolution.longest_chain,
            board_highest=resolution.highest_value)
        return state.copy_with(board=resolution.board,
                               next_block_id=resolution.next_block_id,
                               stats=stats, score=stats.score,
                               is_game_over=not resolution.board.has_legal_drop)


class Booster:
    id = ""
    name_key = ""
    description_key = ""
    price = 0
    requires_target_block = False

    def can_use(self, context):
        raise NotImplementedError

    def apply(self, context):
        raise NotImplementedError


class UndoBooster(Booster):
    id = "undo"
    name_key = "booster_undo_name"
    description_key = "booster_undo_description"
    price = 60

    def can_use(self, context):
        return context.state.can_undo

    def apply(self, context):
        state = context.state
        if not self.can_use(context):
            return BoosterOutcome(state, EFFECT_UNDO, applied=False,
                                  rejection_key=REJECTION_NO_UNDO)
        history = list(state.undo_history)
        previous = history.pop()
        restored = previous.copy_with(mode=state.mode, level=state.level,
                                      undo_history=history, is_game_over=False)
        return BoosterOutcome(restored, EFFECT_UNDO,
                              affected_block_ids=[b.id for b in restored.board.blocks])


class HammerBooster(Booster):
    id = "hammer"
    name_key = "booster_hammer_name"
    description_key = "booster_hammer_description"
    price = 90
    requires_target_block = True

    def can_use(self, context):
        if context.selected_block_id is None:
            return False
        return context.state.board.block_by_id(context.selected_block_id) is not None

    def apply(self, context):
        state = context.state
        target_id = context.selected_block_id
        if target_id is None or not self.can_use(context):
            return BoosterOutcome(state, EFFECT_REMOVE, applied=False,
                                  rejection_key=REJECTION_NO_TARGET)
        removed = state.board.without_block(target_id)
        settled, transitions = BoosterSupport.settle(state.copy_with(board=removed))
        return BoosterOutcome(settled, EFFECT_REMOVE, transitions=transitions,
                              affected_block_ids=[target_id])


class ShuffleBooster(Booster):
    id = "shuffle"
    name_key = "booster_shuffle_name"
    description_key = "booster_shuffle_description"
    price = 120

    def can_use(self, context):
        return context.state.board.block_count >= 2

    def apply(self, context):
        state = context.state
        if not self.can_use(context):
            return BoosterOutcome(state, EFFECT_SHUFFLE, applied=False,
                                  rejection_key=REJECTION_TOO_FEW_BLOCKS)
        board = state.board
        blocks = list(board.blocks)
        cells = []
        for c in range(board.columns):
            for r in range(board.rows - 1, -1, -1):
                if board.cells[r][c] is not None:
                    cells.append((r, c))
        rng = Rng(state.rng_state)
        rng.shuffle(blocks)
        grid = board.cleared()
        for i, (r, c) in enumerate(cells):
            if i >= len(blocks):
                break
            grid = grid.with_block(blocks[i].move_to(r, c))
        settled, transitions = BoosterSupport.settle(
            state.copy_with(board=grid, rng_state=rng.state))
        return BoosterOutcome(settled, EFFECT_SHUFFLE, transitions=transitions,
                              affected_block_ids=[b.id for b in blocks])


class WildcardBooster(Booster):
    id = "wildcard"
    name_key = "booster_wildcard_name"
    description_key = "booster_wildcard_description"
    price = 150
    requires_target_block = True

    def can_use(self, context):
        if context.selected_block_id is None:
            return False
        block = context.state.board.block_by_id(context.selected_block_id)
        if block is None:
            return False
        return len(context.state.board.get_neighbors(block.row, block.column)) > 0

    def apply(self, context):
        state = context.state
        target_id = context.selected_block_id
        target = state.board.block_by_id(target_id) if target_id is not None else None
        if target is None or not self.can_use(context):
            return BoosterOutcome(state, EFFECT_WILDCARD, applied=False,
                                  rejection_key=REJECTION_NO_TARGET)
        neighbors = list(state.board.get_neighbors(target.row, target.column))
        neighbors.sort(key=lambda b: (b.value, b.row, b.column))
        donor = neighbors[0]
        mutated = target.copy_with(value=donor.value)
        settled, transitions = BoosterSupport.settle(
            state.copy_with(board=state.board.with_block(mutated)))
        return BoosterOutcome(settled, EFFECT_WILDCARD, transitions=transitions,
                              affected_block_ids=[target.id])


class UpgradeBooster(Booster):
    id = "upgrade"
    name_key = "booster_upgrade_name"
    description_key = "booster_upgrade_description"
    price = 200
    requires_target_block = True

    def can_use(self, context):
        if context.selected_block_id is None:
            return False
        return context.state.board.block_by_id(context.selected_block_id) is not None

    def apply(self, context):
        state = context.state
        target_id = context.selected_block_id
        target = state.board.block_by_id(target_id) if target_id is not None else None
        if target is None or not self.can_use(context):
            return BoosterOutcome(state, EFFECT_UPGRADE, applied=False,
                                  rejection_key=REJECTION_NO_TARGET)
        upgraded = target.copy_with(value=target.doubled_value)
        settled, transitions = BoosterSupport.settle(
            state.copy_with(board=state.board.with_block(upgraded)))
        return BoosterOutcome(settled, EFFECT_UPGRADE, transitions=transitions,
                              affected_block_ids=[target.id])


ALL_BOOSTERS = [UndoBooster(), HammerBooster(), ShuffleBooster(),
                WildcardBooster(), UpgradeBooster()]
CORE_BOOSTERS = [UndoBooster(), HammerBooster(), ShuffleBooster()]
DEFAULT_IDS = ["undo", "hammer", "shuffle"]


def by_id(booster_id):
    for b in ALL_BOOSTERS:
        if b.id == booster_id:
            return b
    return None


def by_id_or_default(booster_id):
    return by_id(booster_id) or UndoBooster()
