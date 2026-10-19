import 'package:flutter/material.dart';
import 'package:hercules_control/core/layout/breakpoints.dart';

class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.action,
  });

  final String title;
  final String subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final compact = context.isCompact;
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: compact ? textTheme.headlineSmall : textTheme.headlineMedium,
        ),
        const SizedBox(height: 6),
        Text(subtitle),
      ],
    );

    // Phones: the action goes under the texts so the title keeps the width.
    if (compact) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          texts,
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: texts),
        ...?action == null ? null : [action!],
      ],
    );
  }
}
