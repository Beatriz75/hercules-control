import 'package:flutter/widgets.dart';

/// Width breakpoints shared by the whole app (Material 3 window classes):
/// phones below [compact], tablets below [medium], desktop from [medium].
abstract final class Breakpoints {
  /// Below this width the layout is "compact" (phones, ~360–430 px).
  static const double compact = 600;

  /// Below this width (and from [compact]) the layout is "medium" (tablets).
  static const double medium = 1024;
}

enum WindowSize {
  compact,
  medium,
  expanded;

  static WindowSize forWidth(double width) {
    if (width < Breakpoints.compact) return WindowSize.compact;
    if (width < Breakpoints.medium) return WindowSize.medium;
    return WindowSize.expanded;
  }
}

extension ResponsiveContext on BuildContext {
  /// Window class of the current screen width.
  WindowSize get windowSize =>
      WindowSize.forWidth(MediaQuery.sizeOf(this).width);

  /// Phone-sized screen: one column, drawer navigation, full-screen dialogs.
  bool get isCompact => windowSize == WindowSize.compact;

  /// Padding around page content and inside dialogs.
  double get pagePadding => switch (windowSize) {
    WindowSize.compact => 12,
    WindowSize.medium => 20,
    WindowSize.expanded => 24,
  };

  /// Padding inside dialogs: tighter on phones to leave room for content.
  double get dialogPadding => isCompact ? 16 : 24;
}
