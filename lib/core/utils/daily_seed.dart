/// Deterministic derivation of the daily-challenge seed.
///
/// The daily puzzle must be *identical for every player*, so the seed cannot
/// come from `DateTime.now().millisecondsSinceEpoch` or from any other
/// non-reproducible source. It is derived from the calendar date with FNV-1a,
/// a hash defined over raw bytes, which produces the same value on every
/// device, platform and SDK version - forever.
class DailySeed {
  const DailySeed._();

  static const int _mask32 = 0xFFFFFFFF;
  static const int _fnvOffset = 0x811C9DC5;
  static const int _fnvPrime = 0x01000193;

  /// `YYYY-MM-DD`, zero padded - the canonical daily identity.
  static String keyFor(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  /// 32-bit FNV-1a over the UTF-8 code units of [text].
  static int fnv1a32(String text) {
    var hash = _fnvOffset;
    for (final codeUnit in text.codeUnits) {
      hash ^= codeUnit & 0xFF;
      hash = (hash * _fnvPrime) & _mask32;
    }
    return hash & _mask32;
  }

  /// Deterministic seed for a daily key such as `2026-10-08`.
  static int seedFor(String dailyKey) => fnv1a32('merge_drop-daily-$dailyKey');

  /// Deterministic seed for a calendar date.
  static int seedForDate(DateTime date) => seedFor(keyFor(date));
}
