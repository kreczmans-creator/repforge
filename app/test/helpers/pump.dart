import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// Unmounts the widget tree and elapses fake time by one millisecond.
///
/// drift schedules a `Duration.zero` timer when a query stream is cancelled,
/// which happens when Riverpod disposes a `StreamProvider`. flutter_test
/// disposes the tree *before* `addTearDown` callbacks run and fails the test
/// on any pending timer, so every widget test that watches a drift stream
/// calls this as its last statement.
Future<void> unmount(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(milliseconds: 1));
}
