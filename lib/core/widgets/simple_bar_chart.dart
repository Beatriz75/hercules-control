import 'package:flutter/material.dart';

class SimpleBarChart extends StatelessWidget {
  const SimpleBarChart({
    super.key,
    required this.values,
  });

  final List<ChartBarValue> values;

  @override
  Widget build(BuildContext context) {
    final maxValue = values.fold<double>(0, (prev, item) {
      return item.value > prev ? item.value : prev;
    });

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: values.map((item) {
        final ratio = maxValue == 0 ? 0.0 : item.value / maxValue;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.value.toStringAsFixed(0)),
                const SizedBox(height: 8),
                Container(
                  height: 140,
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    height: 16 + (ratio * 110),
                    decoration: BoxDecoration(
                      color: item.color,
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(item.label, textAlign: TextAlign.center),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class ChartBarValue {
  const ChartBarValue({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}
