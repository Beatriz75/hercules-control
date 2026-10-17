import 'package:flutter/material.dart';
import 'package:hercules_control/core/layout/breakpoints.dart';

/// Large dialog that fills the whole screen on phones and keeps the centered,
/// width-capped card on tablet and desktop.
///
/// [child] gets tight full-screen constraints on phones, so a
/// `Column(mainAxisSize: MainAxisSize.min)` with a `Flexible` / `Expanded`
/// scroll area works the same in both layouts.
class ResponsiveDialog extends StatelessWidget {
  const ResponsiveDialog({
    super.key,
    required this.maxWidth,
    required this.child,
    this.maxHeightFactor,
  });

  final double maxWidth;

  /// Share of the screen height the card may use outside phones. Null leaves
  /// the height to the content (the dialog still never exceeds the screen).
  final double? maxHeightFactor;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (context.isCompact) {
      return Dialog.fullscreen(child: SafeArea(child: child));
    }

    final heightFactor = maxHeightFactor;
    return Dialog(
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: maxWidth,
          maxHeight: heightFactor == null
              ? double.infinity
              : MediaQuery.sizeOf(context).height * heightFactor,
        ),
        child: child,
      ),
    );
  }
}
