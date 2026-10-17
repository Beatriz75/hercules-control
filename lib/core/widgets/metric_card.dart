import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:hercules_control/core/widgets/app_panel.dart';

class MetricCard extends StatelessWidget {
  const MetricCard({
    super.key,
    required this.title,
    required this.value,
    required this.caption,
    required this.icon,
    this.alert = false,
    this.dense = false,
  });

  final String title;
  final String value;
  final String caption;
  final IconData icon;
  final bool alert;

  /// One-line layout (icon, texts, value) for narrow screens.
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final accent = alert ? colorScheme.error : colorScheme.primary;

    if (dense) {
      return AppPanel(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: accent, size: 22),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              value,
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      );
    }

    return AppPanel(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: accent, size: 22),
          const SizedBox(height: 12),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.headlineMedium?.copyWith(color: accent),
            ),
          ),
          const SizedBox(height: 2),
          Text(caption, maxLines: 1, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

/// Three metric cards side by side, or stacked one-line cards when the
/// available width is narrow (phones and tablets with the menu open).
class MetricCardGrid extends StatelessWidget {
  const MetricCardGrid({super.key, required this.cards});

  /// Below this content width the cards are stacked.
  static const double stackBelow = 720;

  static const double _spacing = 16;

  /// Height the full card needs (icon, title, value and caption).
  static const double _minCardHeight = 164;

  final List<MetricCard> cards;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < stackBelow) {
          return Column(
            children: [
              for (final card in cards.indexed) ...[
                if (card.$1 > 0) const SizedBox(height: 10),
                MetricCard(
                  title: card.$2.title,
                  value: card.$2.value,
                  caption: card.$2.caption,
                  icon: card.$2.icon,
                  alert: card.$2.alert,
                  dense: true,
                ),
              ],
            ],
          );
        }

        // Same 2.65 proportion as before, but never shorter than the card's
        // content (it used to clip the caption around 1366 px).
        final cardWidth = (constraints.maxWidth - 2 * _spacing) / 3;
        return GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            mainAxisSpacing: _spacing,
            crossAxisSpacing: _spacing,
            mainAxisExtent: math.max(cardWidth / 2.65, _minCardHeight),
          ),
          children: cards,
        );
      },
    );
  }
}
