from enum import StrEnum


class Role(StrEnum):
    ADMINISTRADOR = "administrador"
    SUPERVISOR = "supervisor"
    AUDITOR = "auditor"
    CONSULTA_GERENCIAL = "consulta_gerencial"
    ALUMNO = "alumno"


class Permission(StrEnum):
    DASHBOARD_VIEW = "dashboard.view"
    EMPLOYEES_VIEW = "employees.view"
    CANDIDATES_VIEW = "candidates.view"
    AUDITS_VIEW = "audits.view"
    AUDITS_CREATE = "audits.create"
    AUDITS_MANAGE = "audits.manage"
    COURSES_VIEW = "courses.view"
    COURSES_MANAGE = "courses.manage"
    COURSES_PROGRESS_VIEW = "courses.progress.view"
    COURSES_TAKE = "courses.take"
    PERFORMANCE_VIEW = "performance.view"
    REPORTS_VIEW = "reports.view"
    REPORTS_CREATE = "reports.create"
    WHATSAPP_LINES_VIEW = "whatsapp-lines.view"
    SETTINGS_VIEW = "settings.view"
    USERS_MANAGE = "users.manage"


# Roles are fixed (docs/requirements.md "Roles y permisos" + Alumno for Cursos).
ROLE_PERMISSIONS: dict[Role, frozenset[Permission]] = {
    Role.ADMINISTRADOR: frozenset(Permission) - {Permission.COURSES_TAKE},
    Role.SUPERVISOR: frozenset(
        {
            Permission.DASHBOARD_VIEW,
            Permission.EMPLOYEES_VIEW,
            Permission.CANDIDATES_VIEW,
            Permission.AUDITS_VIEW,
            Permission.PERFORMANCE_VIEW,
            Permission.REPORTS_VIEW,
            Permission.COURSES_VIEW,
            Permission.COURSES_PROGRESS_VIEW,
        }
    ),
    Role.AUDITOR: frozenset(
        {
            Permission.DASHBOARD_VIEW,
            Permission.AUDITS_VIEW,
            Permission.AUDITS_CREATE,
            Permission.PERFORMANCE_VIEW,
            Permission.REPORTS_VIEW,
            Permission.REPORTS_CREATE,
        }
    ),
    Role.CONSULTA_GERENCIAL: frozenset(
        {
            Permission.DASHBOARD_VIEW,
            Permission.PERFORMANCE_VIEW,
            Permission.REPORTS_VIEW,
            Permission.COURSES_VIEW,
            Permission.COURSES_PROGRESS_VIEW,
        }
    ),
    Role.ALUMNO: frozenset({Permission.COURSES_TAKE}),
}


def permissions_for(role: str) -> frozenset[Permission]:
    try:
        return ROLE_PERMISSIONS[Role(role)]
    except ValueError:
        return frozenset()
