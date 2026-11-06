import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The last vertical scrollable on screen that belongs to the page or form,
/// never to a text field.
///
/// Every `TextField` owns a `Scrollable` inside its `EditableText`:
/// horizontal for a single-line field, vertical for a multi-line one. So
/// neither `find.byType(Scrollable).last` (picked a single-line field's
/// horizontal scroller in emulator run 41880049338) nor "the last vertical
/// scrollable" (picks a multi-line field such as the recipe description) is
/// safe for scrolling a form to its Save button. Shared by widget tests and
/// the integration test so both use the same rule.
Finder lastPageScrollable() => find.byElementPredicate((element) {
  final widget = element.widget;
  if (widget is! Scrollable) return false;
  if (widget.axisDirection != AxisDirection.down &&
      widget.axisDirection != AxisDirection.up) {
    return false;
  }
  var insideTextField = false;
  element.visitAncestorElements((ancestor) {
    if (ancestor.widget is EditableText) {
      insideTextField = true;
      return false;
    }
    return true;
  });
  return !insideTextField;
}, description: 'last vertical page scrollable (not inside a text field)').last;
