import 'package:flutter/material.dart';
import 'package:hercules_control/core/widgets/focus_list_panel.dart';
import 'package:hercules_control/core/widgets/metric_card.dart';
import 'package:hercules_control/core/widgets/page_header.dart';

class PerformancePage extends StatelessWidget {
  const PerformancePage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Rendimiento',
            subtitle:
                'Vista inicial para indicadores operativos de equipo y calidad de atención.',
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
                title: 'Desempeño por empleado',
                value: 'Visual',
                caption: 'Indicadores futuros',
                icon: Icons.groups_2_rounded,
              ),
              MetricCard(
                title: 'Calidad de atención',
                value: 'Visual',
                caption: 'Seguimiento operativo',
                icon: Icons.support_agent_rounded,
              ),
              MetricCard(
                title: 'Tendencias',
                value: 'Futuro',
                caption: 'Sin reportes semanales separados',
                icon: Icons.timeline_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const FocusListPanel(
            title: 'Enfoque de rendimiento',
            items: [
              'Agrupar métricas diarias y semanales dentro de una sola vista.',
              'Priorizar señales accionables antes que tableros financieros.',
              'Mantener los cálculos profundos fuera de esta tarea visual.',
            ],
          ),
        ],
      ),
    );
  }
}
