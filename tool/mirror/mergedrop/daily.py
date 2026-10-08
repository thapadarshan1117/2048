"""Mirror of the daily-challenge seed derivation."""

MASK32 = 0xFFFFFFFF
FNV_OFFSET = 0x811C9DC5
FNV_PRIME = 0x01000193


def daily_key(year, month, day):
    """`YYYY-MM-DD`, zero padded - the canonical daily identity."""
    return "%04d-%02d-%02d" % (year, month, day)


def fnv1a32(text):
    """Platform-independent 32-bit FNV-1a over UTF-8 bytes."""
    h = FNV_OFFSET
    for byte in text.encode("utf-8"):
        h ^= byte
        h = (h * FNV_PRIME) & MASK32
    return h


def daily_seed(key):
    """Deterministic seed for a daily key: identical on every device."""
    return fnv1a32("mergedrop-daily-" + key)


def daily_seed_for_date(year, month, day):
    return daily_seed(daily_key(year, month, day))
