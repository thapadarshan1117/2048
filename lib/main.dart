import 'package:flutter/material.dart';

import 'app/app.dart';

/// Entry point.
///
/// Kept deliberately thin: all wiring lives in [MergeDropApp] and
/// `ServiceLocator`, so `main` never has to know what the app is made of.
void main() {
  runApp(const MergeDropApp());
}
