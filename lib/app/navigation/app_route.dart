import 'package:hercules_control/app/navigation/app_section.dart';

class AppRouteDefinition {
  const AppRouteDefinition({
    required this.section,
    required this.path,
    required this.label,
    required this.requiredPermission,
    this.alternativePermissions = const [],
    this.enabled = false,
  });

  final AppSection section;
  final String path;
  final String label;

  /// Main permission that grants access to the section.
  final String requiredPermission;

  /// Other permissions that also grant access (any of them is enough).
  final List<String> alternativePermissions;

  /// Whether the module is released in the current delivery. Modules that are
  /// still in development keep their route but are hidden from navigation.
  final bool enabled;

  List<String> get acceptedPermissions => [
    requiredPermission,
    ...alternativePermissions,
  ];

  bool isVisibleFor(Set<String> permissions) =>
      enabled && acceptedPermissions.any(permissions.contains);
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
    section: AppSection.courses,
    path: '/courses',
    label: 'Cursos',
    requiredPermission: 'courses.view',
    alternativePermissions: ['courses.take'],
    enabled: true,
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
  AppRouteDefinition(
    section: AppSection.users,
    path: '/users',
    label: 'Usuarios',
    requiredPermission: 'users.manage',
    enabled: true,
  ),
];

/// Routes shown in the navigation for a user with [permissions].
List<AppRouteDefinition> visibleRoutesFor(Set<String> permissions) => [
  for (final route in appRoutes)
    if (route.isVisibleFor(permissions)) route,
];
