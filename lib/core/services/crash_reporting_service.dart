import 'dart:async';

import 'package:firebase_crashlytics/firebase_crashlytics.dart';

/// Crash reporting abstraction.
///
/// Game context (level, mode, board size) is attached to non-fatal reports so a
/// crash can be reproduced. No sensitive information is ever logged.
abstract interface class CrashReportingService {
  Future<void> initialize();

  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    Map<String, Object>? context,
  });

  void log(String message);

  void setCustomKey(String key, Object value);

  Future<void> dispose();
}

/// Firebase Crashlytics implementation.
class FirebaseCrashReportingService implements CrashReportingService {
  const FirebaseCrashReportingService(this._crashlytics);

  final FirebaseCrashlytics _crashlytics;

  @override
  Future<void> initialize() async {
    // Fatal errors are reported automatically; this only needs to make sure
    // collection is enabled and the build is ready for non-fatals.
    await _crashlytics.setCrashlyticsCollectionEnabled(true);
  }

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    Map<String, Object>? context,
  }) {
    context?.forEach(setCustomKey);
    // Reporting a crash must never cause another one.
    unawaited(_crashlytics.recordError(
      error,
      stackTrace,
      reason: reason,
      printDetails: false,
    ));
  }

  @override
  void log(String message) => unawaited(_crashlytics.log(message));

  @override
  void setCustomKey(String key, Object value) =>
      unawaited(_crashlytics.setCustomKey(key, value));

  @override
  Future<void> dispose() async {}
}

/// No-op implementation - the default.
class NoopCrashReportingService implements CrashReportingService {
  const NoopCrashReportingService();

  @override
  Future<void> initialize() async {}

  @override
  void recordError(
    Object error,
    StackTrace? stackTrace, {
    String? reason,
    Map<String, Object>? context,
  }) {}

  @override
  void log(String message) {}

  @override
  void setCustomKey(String key, Object value) {}

  @override
  Future<void> dispose() async {}
}
