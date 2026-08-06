import 'package:flutter/material.dart';
import 'package:hercules_control/core/widgets/focus_list_panel.dart';
import 'package:hercules_control/core/widgets/metric_card.dart';
import 'package:hercules_control/core/widgets/page_header.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const PageHeader(
            title: 'Configuración',
            subtitle:
                'Vista inicial para parámetros operativos, accesos y preferencias de la app.',
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
                title: 'Preferencias',
                value: 'Próximo',
                caption: 'Sin persistencia todavía',
                icon: Icons.tune_rounded,
              ),
              MetricCard(
                title: 'Usuarios',
                value: 'Próximo',
                caption: 'Sin permisos implementados',
                icon: Icons.admin_panel_settings_rounded,
              ),
              MetricCard(
                title: 'Parámetros',
                value: 'Visual',
                caption: 'Solo alcance inicial',
                icon: Icons.rule_rounded,
              ),
            ],
          ),
          const SizedBox(height: 24),
          const FocusListPanel(
            title: 'Límites de esta pantalla',
            items: [
              'No guarda preferencias ni modifica configuración real.',
              'No agrega permisos, roles ni autenticación.',
              'Solo reserva el lugar visual del módulo aprobado.',
            ],
          ),
        ],
      ),
    );
  }
}
