import 'package:hercules_control/app/navigation/app_section.dart';

class AppRouteDefinition {
  const AppRouteDefinition({
    required this.section,
    required this.path,
    required this.label,
    required this.requiredPermission,
  });

  final AppSection section;
  final String path;
  final String label;
  final String requiredPermission;
}

const appRoutes = [
  AppRouteDefinition(
    section: AppSection.dashboard,
    path: '/dashboard',
    label: 'Dashboard',
    requiredPermission: 'dashboard.view',
  ),
  AppRouteDefinition(
    section: AppSection.employees,
    path: '/employees',
    label: 'Empleados',
    requiredPermission: 'employees.view',
  ),
  AppRouteDefinition(
    section: AppSection.candidates,
    path: '/candidates',
    label: 'Candidatos',
    requiredPermission: 'candidates.view',
  ),
  AppRouteDefinition(
    section: AppSection.audits,
    path: '/audits',
    label: 'Auditorías',
    requiredPermission: 'audits.view',
  ),
  AppRouteDefinition(
    section: AppSection.performance,
    path: '/performance',
    label: 'Rendimiento',
    requiredPermission: 'performance.view',
  ),
  AppRouteDefinition(
    section: AppSection.reports,
    path: '/reports',
    label: 'Reportes',
    requiredPermission: 'reports.view',
  ),
  AppRouteDefinition(
    section: AppSection.lines,
    path: '/whatsapp-lines',
    label: 'Líneas WhatsApp',
    requiredPermission: 'whatsapp-lines.view',
  ),
  AppRouteDefinition(
    section: AppSection.settings,
    path: '/settings',
    label: 'Configuración',
    requiredPermission: 'settings.view',
  ),
];
