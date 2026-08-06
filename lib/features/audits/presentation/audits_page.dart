import 'package:flutter/material.dart';
import 'package:hercules_control/core/widgets/focus_list_panel.dart';
import 'package:hercules_control/core/widgets/metric_card.dart';
import 'package:hercules_control/core/widgets/page_header.dart';

class AuditsPage extends StatelessWidget {
  const AuditsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Auditorías',
            subtitle:
                'Espacio visual para controles manuales, trazabilidad y revisión operativa.',
          ),
          const SizedBox(height: 24),
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.55,
            children: const [
              MetricCard(
                title: 'Controles diarios',
                value: 'Manual',
                caption: 'Sin automatización en esta etapa',
                icon: Icons.playlist_add_check_rounded,
              ),
              MetricCard(
                title: 'Comprobantes diarios',
                value: 'Futuro',
                caption: 'Métrica manual, no módulo',
                icon: Icons.receipt_long_rounded,
              ),
              MetricCard(
                title: 'Riesgos',
                value: 'Visual',
                caption: 'Trazabilidad y observaciones',
                icon: Icons.warning_amber_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const FocusListPanel(
            title: 'Qué cubre este módulo',
            items: [
              'Revisión operativa manual sin reglas contables nuevas.',
              'Señales de trazabilidad, faltas y observaciones del equipo.',
              'Comprobantes diarios queda como métrica futura dentro del módulo.',
            ],
          ),
        ],
      ),
    );
  }
}
