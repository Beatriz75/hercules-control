import 'package:flutter/material.dart';
import 'package:hercules_control/core/widgets/focus_list_panel.dart';
import 'package:hercules_control/core/widgets/metric_card.dart';
import 'package:hercules_control/core/widgets/page_header.dart';

class CandidatesPage extends StatelessWidget {
  const CandidatesPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Candidatos',
            subtitle:
                'Vista inicial para ordenar el seguimiento de postulaciones y entrevistas.',
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
                title: 'Postulantes',
                value: 'Próximo',
                caption: 'Registro manual pendiente',
                icon: Icons.person_search_rounded,
              ),
              MetricCard(
                title: 'Entrevistas',
                value: 'Próximo',
                caption: 'Agenda visual futura',
                icon: Icons.event_note_rounded,
              ),
              MetricCard(
                title: 'Altas potenciales',
                value: 'Próximo',
                caption: 'Sin flujo automatizado aún',
                icon: Icons.how_to_reg_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const FocusListPanel(
            title: 'Enfoque inicial',
            items: [
              'Centralizar candidatos antes de convertirlos en empleados.',
              'Separar entrevistas, estado y observaciones operativas.',
              'Evitar automatizaciones hasta validar el proceso real.',
            ],
          ),
        ],
      ),
    );
  }
}
