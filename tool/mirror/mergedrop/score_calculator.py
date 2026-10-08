"""Mirror of lib/features/game/domain/score_calculator.dart."""

MAX_COMBO_STEP = 9


def combo_multiplier(chain_step):
    return 1.0 + 0.5 * max(0, min(chain_step, MAX_COMBO_STEP))


def merge_score(new_value, chain_step=0):
    if new_value <= 0:
        return 0
    return round(new_value * combo_multiplier(chain_step))


def big_merge_bonus(new_value):
    if new_value >= 2048:
        return 2048
    if new_value >= 1024:
        return 1024
    if new_value >= 512:
        return 512
    if new_value >= 256:
        return 256
    if new_value >= 128:
        return 128
    return 0


DROP_SCORE = 0


def level_completion_coins(stars):
    return {3: 30, 2: 20, 1: 10}.get(stars, 0)


def star_bonus_coins(stars):
    return max(0, min(stars - 1, 2)) * 15


def daily_reward_coins(day):
    if day <= 0:
        return 20
    if day >= 7:
        return 200
    return 20 + (day - 1) * 30
