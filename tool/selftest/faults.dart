// Regression fixture for tool/check_sources.py. NOT a Flutter test.
//
// Every construct in this file is a deliberate fault, and each one mirrors a
// real bug the analyser caught in this repository:
//
//   1. `if (hadMerges)` - a getter used bare when it belongs to a receiver.
//   2. `expect(totl, 3)` - a typo of a real local.
//   3. `_boardForLevel(...)` - a call to a method that does not exist.
//   4. `blockCount` - a bare name that is declared nowhere.
//
// The file lives outside test/ so `flutter test` never picks it up, and it is
// excluded from the normal scan. Run the self-test with:
//
//     python3 tool/check_sources.py --selftest
//
// It passes only when the analyser reports all four faults and nothing else.
import 'package:flutter_test/flutter_test.dart';

class Outcome {
  bool get hadMerges => true;
}

class Faulty {
  // FAULT 1: missing receiver. `hadMerges` is only ever reached through
  // `outcome` in this file, so the bare use cannot resolve.
  void a(Outcome outcome) {
    if (outcome.hadMerges && hadMerges) {
      expect(1, 1);
    }
  }

  // FAULT 2: typo of a real local.
  void b() {
    final total = 3;
    expect(totl, 3);
  }

  // FAULT 3: call to a method that does not exist anywhere in the project.
  void c() {
    final board = _boardForLevel(3);
    expect(board, isNotNull);
  }

  // FAULT 4: bare use of a name that is declared nowhere.
  void d() {
    final remaining = blockCount - consumedCount;
    expect(remaining, isNotNull);
  }
}
