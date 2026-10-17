import 'package:flutter/material.dart';
import 'package:hercules_control/app/navigation/app_route.dart';
import 'package:hercules_control/app/navigation/app_section.dart';
import 'package:hercules_control/app/navigation/shell_navigation.dart';
import 'package:hercules_control/core/auth/auth_scope.dart';
import 'package:hercules_control/core/auth/current_user.dart';
import 'package:hercules_control/core/layout/breakpoints.dart';
import 'package:hercules_control/core/theme/app_theme.dart';
import 'package:hercules_control/core/widgets/brand_logo.dart';
import 'package:hercules_control/features/audits/presentation/audits_page.dart';
import 'package:hercules_control/features/auth/presentation/change_password_dialog.dart';
import 'package:hercules_control/features/candidates/presentation/candidates_page.dart';
import 'package:hercules_control/features/courses/presentation/courses_page.dart';
import 'package:hercules_control/features/dashboard/presentation/dashboard_page.dart';
import 'package:hercules_control/features/employees/presentation/employees_page.dart';
import 'package:hercules_control/features/lines/presentation/lines_page.dart';
import 'package:hercules_control/features/performance/presentation/performance_page.dart';
import 'package:hercules_control/features/reports/presentation/reports_page.dart';
import 'package:hercules_control/features/settings/presentation/settings_page.dart';
import 'package:hercules_control/features/users/presentation/users_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection? _active;
  int? _focusCourseId;

  void _goTo(AppSection section, {int? courseId}) {
    setState(() {
      _active = section;
      _focusCourseId = courseId;
    });
  }

  /// Sidebar width chosen by the user. Null follows the screen: collapsed on
  /// tablets, expanded on desktop.
  bool? _collapsedOverride;

  Widget _pageFor(AppSection section) {
    return switch (section) {
      AppSection.dashboard => const DashboardPage(),
      AppSection.employees => const EmployeesPage(),
      AppSection.candidates => const CandidatesPage(),
      AppSection.audits => const AuditsPage(),
      AppSection.courses => CoursesPage(
        key: ValueKey('courses-$_focusCourseId'),
        initialCourseId: _focusCourseId,
      ),
      AppSection.questionBank => const QuestionBankPage(),
      AppSection.performance => const PerformancePage(),
      AppSection.reports => const ReportsPage(),
      AppSection.lines => const LinesPage(),
      AppSection.settings => const SettingsPage(),
      AppSection.users => const UsersPage(),
    };
  }

  void _select(AppSection section) {
    setState(() {
      _active = section;
      _focusCourseId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final user = auth.user!;
    final routes = visibleRoutesFor(user.permissions);
    final active = routes.any((route) => route.section == _active)
        ? _active
        : routes.isEmpty
        ? null
        : routes.first.section;
    final windowSize = context.windowSize;
    final compact = windowSize == WindowSize.compact;

    final content = SafeArea(
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 180),
        child: Container(
          key: ValueKey(active),
          padding: EdgeInsets.all(context.pagePadding),
          child: active == null ? const _NoModulesView() : _pageFor(active),
        ),
      ),
    );

    // Phones: app bar with a hamburger button and the menu in a drawer.
    if (compact) {
      String? activeLabel;
      for (final route in routes) {
        if (route.section == active) activeLabel = route.label;
      }

      final theme = Theme.of(context);

      return ShellNavigation(
        goTo: _goTo,
        // Narrower side margins for every dialog opened on a phone.
        child: Theme(
          data: theme.copyWith(
            dialogTheme: theme.dialogTheme.copyWith(
              insetPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 24,
              ),
            ),
          ),
          child: Scaffold(
            appBar: AppBar(
              titleSpacing: 0,
              title: Row(
                children: [
                  const BrandMark(size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      activeLabel ?? 'Hércules Control',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                  ),
                ],
              ),
            ),
            drawer: Drawer(
              backgroundColor: BrandColors.navy,
              child: Builder(
                builder: (drawerContext) => _SidebarContent(
                  collapsed: false,
                  routes: routes,
                  active: active,
                  user: user,
                  onSelect: (section) {
                    Navigator.of(drawerContext).pop();
                    _select(section);
                  },
                ),
              ),
            ),
            body: content,
          ),
        ),
      );
    }

    final collapsed = _collapsedOverride ?? windowSize == WindowSize.medium;
    final sidebarWidth = collapsed ? 84.0 : 248.0;

    return ShellNavigation(
      goTo: _goTo,
      child: Scaffold(
        body: Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: sidebarWidth,
              color: BrandColors.navy,
              // The content is laid out at its final width and clipped while
              // the width animates, so it never overflows mid-animation.
              child: ClipRect(
                child: OverflowBox(
                  alignment: Alignment.centerLeft,
                  minWidth: sidebarWidth,
                  maxWidth: sidebarWidth,
                  child: _SidebarContent(
                    collapsed: collapsed,
                    routes: routes,
                    active: active,
                    user: user,
                    onSelect: _select,
                    onToggleCollapsed: () =>
                        setState(() => _collapsedOverride = !collapsed),
                  ),
                ),
              ),
            ),
            Expanded(child: content),
          ],
        ),
      ),
    );
  }
}

/// Brand, module list and user panel. Used by the desktop sidebar and by the
/// drawer on phones.
class _SidebarContent extends StatelessWidget {
  const _SidebarContent({
    required this.collapsed,
    required this.routes,
    required this.active,
    required this.user,
    required this.onSelect,
    this.onToggleCollapsed,
  });

  final bool collapsed;
  final List<AppRouteDefinition> routes;
  final AppSection? active;
  final CurrentUser user;
  final ValueChanged<AppSection> onSelect;

  /// Null hides the collapse button (drawer).
  final VoidCallback? onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              collapsed ? 8 : 16,
              16,
              collapsed ? 8 : 8,
              24,
            ),
            child: Flex(
              direction: collapsed ? Axis.vertical : Axis.horizontal,
              mainAxisSize: MainAxisSize.min,
              children: [
                const BrandMark(size: 44),
                if (!collapsed) ...[
                  const SizedBox(width: 10),
                  const Expanded(
                    child: BrandWordmark(
                      fontSize: 17,
                      titleColor: Colors.white,
                    ),
                  ),
                ],
                if (onToggleCollapsed != null)
                  IconButton(
                    onPressed: onToggleCollapsed,
                    tooltip: collapsed ? 'Expandir menú' : 'Contraer menú',
                    icon: Icon(
                      collapsed
                          ? Icons.keyboard_double_arrow_right_rounded
                          : Icons.keyboard_double_arrow_left_rounded,
                      color: Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                for (final route in routes)
                  _SidebarTile(
                    collapsed: collapsed,
                    selected: active == route.section,
                    icon: _iconForSection(route.section),
                    label: route.label,
                    onTap: () => onSelect(route.section),
                  ),
              ],
            ),
          ),
          _UserPanel(collapsed: collapsed, user: user),
        ],
      ),
    );
  }
}

class _UserPanel extends StatelessWidget {
  const _UserPanel({required this.collapsed, required this.user});

  final bool collapsed;
  final CurrentUser user;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.read(context);

    void changePassword() {
      showDialog<void>(
        context: context,
        builder: (context) => const ChangePasswordDialog(),
      );
    }

    final actions = [
      IconButton(
        onPressed: changePassword,
        tooltip: 'Cambiar contraseña',
        icon: const Icon(Icons.key_rounded, color: Color(0xFFC0CEDA)),
      ),
      IconButton(
        onPressed: auth.logout,
        tooltip: 'Cerrar sesión',
        icon: const Icon(Icons.logout_rounded, color: Color(0xFFC0CEDA)),
      ),
    ];

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: BrandColors.navyDeep,
        borderRadius: BorderRadius.circular(18),
      ),
      child: collapsed
          ? Column(mainAxisSize: MainAxisSize.min, children: actions)
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  [
                    user.roleName,
                    if (user.storeCode != null && user.storeCode!.isNotEmpty)
                      user.storeCode!,
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFB9C7D5),
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: actions,
                ),
              ],
            ),
    );
  }
}

class _NoModulesView extends StatelessWidget {
  const _NoModulesView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_clock_rounded,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              'Sin módulos disponibles',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text(
              'Tu rol todavía no tiene módulos habilitados en esta versión. Consulta con un administrador.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _SidebarTile extends StatelessWidget {
  const _SidebarTile({
    required this.collapsed,
    required this.selected,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final bool collapsed;
  final bool selected;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? BrandColors.navyLight : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: selected
              ? const BorderSide(color: BrandColors.gold, width: 1.2)
              : BorderSide.none,
        ),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            decoration: selected && !collapsed
                ? const BoxDecoration(
                    border: Border(
                      left: BorderSide(color: BrandColors.gold, width: 4),
                    ),
                  )
                : null,
            padding: EdgeInsets.symmetric(
              horizontal: collapsed ? 0 : 14,
              vertical: 14,
            ),
            child: Row(
              mainAxisAlignment: collapsed
                  ? MainAxisAlignment.center
                  : MainAxisAlignment.start,
              children: [
                Icon(
                  icon,
                  color: selected
                      ? BrandColors.goldLight
                      : const Color(0xFFC0CEDA),
                ),
                if (!collapsed) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: selected
                            ? Colors.white
                            : const Color(0xFFC0CEDA),
                        fontWeight: selected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );

    // Collapsed: only the icon is visible, the tooltip names the module.
    return collapsed ? Tooltip(message: label, child: tile) : tile;
  }
}

IconData _iconForSection(AppSection section) {
  return switch (section) {
    AppSection.dashboard => Icons.space_dashboard_rounded,
    AppSection.employees => Icons.groups_rounded,
    AppSection.candidates => Icons.badge_rounded,
    AppSection.audits => Icons.fact_check_rounded,
    AppSection.courses => Icons.school_rounded,
    AppSection.performance => Icons.trending_up_rounded,
    AppSection.reports => Icons.report_problem_rounded,
    AppSection.lines => Icons.sim_card_rounded,
    AppSection.settings => Icons.settings_rounded,
    AppSection.questionBank => Icons.quiz_rounded,
    AppSection.users => Icons.manage_accounts_rounded,
  };
}
