import 'package:flutter/material.dart';
import 'package:hercules_control/app/navigation/app_section.dart';
import 'package:hercules_control/features/audits/presentation/audits_page.dart';
import 'package:hercules_control/features/candidates/presentation/candidates_page.dart';
import 'package:hercules_control/features/dashboard/presentation/dashboard_page.dart';
import 'package:hercules_control/features/employees/presentation/employees_page.dart';
import 'package:hercules_control/features/lines/presentation/lines_page.dart';
import 'package:hercules_control/features/performance/presentation/performance_page.dart';
import 'package:hercules_control/features/reports/presentation/reports_page.dart';
import 'package:hercules_control/features/settings/presentation/settings_page.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  AppSection _active = AppSection.dashboard;
  bool _collapsed = false;

  @override
  Widget build(BuildContext context) {
    final pages = <AppSection, Widget>{
      AppSection.dashboard: const DashboardPage(),
      AppSection.employees: const EmployeesPage(),
      AppSection.candidates: const CandidatesPage(),
      AppSection.audits: const AuditsPage(),
      AppSection.performance: const PerformancePage(),
      AppSection.reports: const ReportsPage(),
      AppSection.lines: const LinesPage(),
      AppSection.settings: const SettingsPage(),
    };

    return Scaffold(
      body: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            width: _collapsed ? 84 : 248,
            color: const Color(0xFF0B1F33),
            child: SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: Row(
                      children: [
                        Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: const Color(0xFF173A5B),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'H',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              fontSize: 22,
                            ),
                          ),
                        ),
                        if (!_collapsed) ...[
                          const SizedBox(width: 12),
                          const Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Hercules',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Control',
                                  style: TextStyle(color: Color(0xFFB9C7D5)),
                                ),
                              ],
                            ),
                          ),
                        ],
                        IconButton(
                          onPressed: () {
                            setState(() {
                              _collapsed = !_collapsed;
                            });
                          },
                          icon: Icon(
                            _collapsed
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
                        for (final item in _sectionItems)
                          _SidebarTile(
                            collapsed: _collapsed,
                            selected: _active == item.section,
                            icon: item.icon,
                            label: item.label,
                            onTap: () {
                              setState(() {
                                _active = item.section;
                              });
                            },
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                child: Container(
                  key: ValueKey(_active),
                  padding: const EdgeInsets.all(24),
                  child: pages[_active]!,
                ),
              ),
            ),
          ),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: selected ? const Color(0xFF1D5E96) : Colors.transparent,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Padding(
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
                  color: selected ? Colors.white : const Color(0xFFC0CEDA),
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
  }
}

class _SectionItem {
  const _SectionItem(this.section, this.label, this.icon);

  final AppSection section;
  final String label;
  final IconData icon;
}

const _sectionItems = [
  _SectionItem(
    AppSection.dashboard,
    'Dashboard',
    Icons.space_dashboard_rounded,
  ),
  _SectionItem(AppSection.employees, 'Empleados', Icons.groups_rounded),
  _SectionItem(AppSection.candidates, 'Candidatos', Icons.badge_rounded),
  _SectionItem(AppSection.audits, 'Auditorías', Icons.fact_check_rounded),
  _SectionItem(
    AppSection.performance,
    'Rendimiento',
    Icons.trending_up_rounded,
  ),
  _SectionItem(AppSection.reports, 'Reportes', Icons.report_problem_rounded),
  _SectionItem(AppSection.lines, 'Líneas WhatsApp', Icons.sim_card_rounded),
  _SectionItem(AppSection.settings, 'Configuración', Icons.settings_rounded),
];
