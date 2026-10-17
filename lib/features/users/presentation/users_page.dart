import 'package:flutter/material.dart';
import 'package:hercules_control/core/api/api_client.dart';
import 'package:hercules_control/core/auth/auth_scope.dart';
import 'package:hercules_control/core/auth/current_user.dart';
import 'package:hercules_control/core/widgets/app_panel.dart';
import 'package:hercules_control/core/widgets/page_header.dart';
import 'package:hercules_control/features/users/data/users_repository.dart';
import 'package:hercules_control/features/users/presentation/user_validators.dart';
import 'package:intl/intl.dart';

class UsersPage extends StatefulWidget {
  const UsersPage({super.key});

  @override
  State<UsersPage> createState() => _UsersPageState();
}

class _UsersPageState extends State<UsersPage> {
  late final UsersRepository _repository;
  List<AppUser>? _users;
  String? _error;
  var _loading = true;

  @override
  void initState() {
    super.initState();
    _repository = UsersRepository(AuthScope.apiOf(context));
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final users = await _repository.fetchUsers();
      if (!mounted) return;
      setState(() => _users = users);
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openCreate() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (context) => _UserFormDialog(repository: _repository),
    );
    if (created == true) await _load();
  }

  Future<void> _openEdit(AppUser user) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          _UserFormDialog(repository: _repository, user: user),
    );
    if (saved == true) await _load();
  }

  Future<void> _openResetPassword(AppUser user) async {
    await showDialog<void>(
      context: context,
      builder: (context) =>
          _ResetPasswordDialog(repository: _repository, user: user),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = AuthScope.of(context).user?.id;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        PageHeader(
          title: 'Usuarios',
          subtitle:
              'Accesos al sistema: crea usuarios, asigna rol y tienda, desactiva o restablece contraseñas.',
          action: FilledButton.icon(
            onPressed: _openCreate,
            icon: const Icon(Icons.person_add_alt_1_rounded),
            label: const Text('Nuevo usuario'),
          ),
        ),
        const SizedBox(height: 20),
        Expanded(
          child: AppPanel(
            child: _loading && _users == null
                ? const Center(child: CircularProgressIndicator())
                : _error != null && _users == null
                ? _ErrorRetry(message: _error!, onRetry: _load)
                : _UsersTable(
                    users: _users ?? const [],
                    currentUserId: currentUserId,
                    onEdit: _openEdit,
                    onResetPassword: _openResetPassword,
                  ),
          ),
        ),
      ],
    );
  }
}

class _UsersTable extends StatelessWidget {
  /// Below this width the users are listed as cards.
  static const double _tableMinWidth = 900;

  const _UsersTable({
    required this.users,
    required this.currentUserId,
    required this.onEdit,
    required this.onResetPassword,
  });

  final List<AppUser> users;
  final int? currentUserId;
  final ValueChanged<AppUser> onEdit;
  final ValueChanged<AppUser> onResetPassword;

  @override
  Widget build(BuildContext context) {
    if (users.isEmpty) {
      return const Center(child: Text('Todavía no hay usuarios.'));
    }
    final dateFormat = DateFormat('dd/MM/yyyy');

    return LayoutBuilder(
      builder: (context, constraints) {
        // Phones and tablets: one card per user; the table needs ~900 px.
        if (constraints.maxWidth < _tableMinWidth) {
          return ListView.separated(
            itemCount: users.length,
            separatorBuilder: (context, index) => const Divider(height: 20),
            itemBuilder: (context, index) => _UserCard(
              user: users[index],
              isCurrentUser: users[index].id == currentUserId,
              createdLabel: users[index].createdAt == null
                  ? '—'
                  : dateFormat.format(users[index].createdAt!.toLocal()),
              onEdit: onEdit,
              onResetPassword: onResetPassword,
            ),
          );
        }

        return SingleChildScrollView(
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              // Tighter columns on laptops so "Acciones" stays visible.
              columnSpacing: constraints.maxWidth < 1100 ? 28 : null,
              columns: const [
                DataColumn(label: Text('Usuario')),
                DataColumn(label: Text('Nombre')),
                DataColumn(label: Text('Rol')),
                DataColumn(label: Text('Tienda')),
                DataColumn(label: Text('Estado')),
                DataColumn(label: Text('Alta')),
                DataColumn(label: Text('Acciones')),
              ],
              rows: [
                for (final user in users)
                  DataRow(
                    cells: [
                      DataCell(
                        Text(
                          user.id == currentUserId
                              ? '${user.username} (tú)'
                              : user.username,
                        ),
                      ),
                      DataCell(Text(user.fullName)),
                      DataCell(Text(roleLabel(user.role))),
                      DataCell(Text(user.storeCode ?? '—')),
                      DataCell(_UserStatusChip(active: user.active)),
                      DataCell(
                        Text(
                          user.createdAt == null
                              ? '—'
                              : dateFormat.format(user.createdAt!.toLocal()),
                        ),
                      ),
                      DataCell(
                        Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: () => onEdit(user),
                              tooltip: 'Editar',
                              icon: const Icon(Icons.edit_rounded),
                            ),
                            IconButton(
                              onPressed: () => onResetPassword(user),
                              tooltip: 'Restablecer contraseña',
                              icon: const Icon(Icons.lock_reset_rounded),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Compact view of one user for phones and tablets.
class _UserCard extends StatelessWidget {
  const _UserCard({
    required this.user,
    required this.isCurrentUser,
    required this.createdLabel,
    required this.onEdit,
    required this.onResetPassword,
  });

  final AppUser user;
  final bool isCurrentUser;
  final String createdLabel;
  final ValueChanged<AppUser> onEdit;
  final ValueChanged<AppUser> onResetPassword;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.fullName.isEmpty ? user.username : user.fullName,
                style: textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(isCurrentUser ? '${user.username} (tú)' : user.username),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  _UserStatusChip(active: user.active),
                  Text(
                    [
                      roleLabel(user.role),
                      user.storeCode ?? 'Sin tienda',
                      'Alta $createdLabel',
                    ].join(' · '),
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () => onEdit(user),
          tooltip: 'Editar',
          icon: const Icon(Icons.edit_rounded),
        ),
        IconButton(
          onPressed: () => onResetPassword(user),
          tooltip: 'Restablecer contraseña',
          icon: const Icon(Icons.lock_reset_rounded),
        ),
      ],
    );
  }
}

class _UserStatusChip extends StatelessWidget {
  const _UserStatusChip({required this.active});

  final bool active;

  @override
  Widget build(BuildContext context) {
    return Chip(
      label: Text(active ? 'Activo' : 'Inactivo'),
      visualDensity: VisualDensity.compact,
      backgroundColor: active
          ? Colors.green.withValues(alpha: 0.12)
          : Theme.of(context).colorScheme.error.withValues(alpha: 0.1),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  const _UserFormDialog({required this.repository, this.user});

  final UsersRepository repository;
  final AppUser? user;

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _usernameController;
  late final TextEditingController _fullNameController;
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  late UserRole _role;
  String? _storeCode;
  late bool _active;
  var _saving = false;
  String? _error;

  bool get _isEdit => widget.user != null;

  @override
  void initState() {
    super.initState();
    final user = widget.user;
    _usernameController = TextEditingController(text: user?.username ?? '');
    _fullNameController = TextEditingController(text: user?.fullName ?? '');
    _role = UserRole.fromCode(user?.role) ?? UserRole.alumno;
    _storeCode = user?.storeCode;
    if (_storeCode != null && !storeCodes.contains(_storeCode)) {
      _storeCode = null;
    }
    _active = user?.active ?? true;
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _fullNameController.dispose();
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<bool> _confirmDeactivate() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('¿Desactivar a ${widget.user!.username}?'),
        content: const Text(
          'No podrá iniciar sesión hasta que lo vuelvas a activar. Su avance en los cursos se conserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_isEdit && widget.user!.active && !_active) {
      if (!await _confirmDeactivate() || !mounted) return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      if (_isEdit) {
        await widget.repository.updateUser(
          widget.user!.id,
          fullName: _fullNameController.text,
          role: _role.code,
          storeCode: _storeCode,
          active: _active,
        );
      } else {
        await widget.repository.createUser(
          username: _usernameController.text,
          fullName: _fullNameController.text,
          password: _passwordController.text,
          role: _role.code,
          storeCode: _storeCode,
        );
      }
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop(true);
      messenger.showSnackBar(
        SnackBar(
          content: Text(_isEdit ? 'Usuario actualizado.' : 'Usuario creado.'),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(_isEdit ? 'Editar usuario' : 'Nuevo usuario'),
      content: SizedBox(
        width: 440,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _usernameController,
                  enabled: !_isEdit,
                  decoration: const InputDecoration(
                    labelText: 'Usuario',
                    helperText: 'Letras, números, punto, guion o guion bajo.',
                  ),
                  validator: _isEdit ? null : validateUsername,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _fullNameController,
                  decoration: const InputDecoration(
                    labelText: 'Nombre completo',
                  ),
                  validator: validateFullName,
                ),
                if (!_isEdit) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Contraseña',
                      helperText: 'Mínimo 8 caracteres.',
                    ),
                    validator: validatePassword,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _confirmController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar contraseña',
                    ),
                    validator: (value) => validatePasswordConfirmation(
                      value,
                      _passwordController.text,
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                DropdownButtonFormField<UserRole>(
                  isExpanded: true,
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Rol'),
                  items: [
                    for (final role in UserRole.values)
                      DropdownMenuItem(value: role, child: Text(role.label)),
                  ],
                  onChanged: (value) {
                    if (value != null) setState(() => _role = value);
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String?>(
                  isExpanded: true,
                  initialValue: _storeCode,
                  decoration: InputDecoration(
                    labelText: _role == UserRole.alumno
                        ? 'Tienda (obligatoria para alumnos)'
                        : 'Tienda (opcional)',
                  ),
                  items: [
                    const DropdownMenuItem<String?>(
                      value: null,
                      child: Text('Sin tienda'),
                    ),
                    for (final store in storeCodes)
                      DropdownMenuItem<String?>(
                        value: store,
                        child: Text(store),
                      ),
                  ],
                  validator: (value) => validateStore(_role, value),
                  onChanged: (value) => setState(() => _storeCode = value),
                ),
                if (_isEdit) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: _active,
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Usuario activo'),
                    subtitle: const Text(
                      'Un usuario inactivo no puede iniciar sesión.',
                    ),
                    onChanged: (value) => setState(() => _active = value),
                  ),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Guardando...' : 'Guardar'),
        ),
      ],
    );
  }
}

class _ResetPasswordDialog extends StatefulWidget {
  const _ResetPasswordDialog({required this.repository, required this.user});

  final UsersRepository repository;
  final AppUser user;

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmController = TextEditingController();
  var _saving = false;
  String? _error;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving) return;
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.repository.resetPassword(
        widget.user.id,
        _passwordController.text,
      );
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      Navigator.of(context).pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text('Contraseña de ${widget.user.username} restablecida.'),
        ),
      );
    } on ApiException catch (error) {
      if (!mounted) return;
      setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Restablecer contraseña de ${widget.user.username}'),
      scrollable: true,
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Nueva contraseña',
                  helperText: 'Mínimo 8 caracteres. Compártela en privado.',
                ),
                validator: validatePassword,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _confirmController,
                obscureText: true,
                decoration: const InputDecoration(
                  labelText: 'Confirmar contraseña',
                ),
                validator: (value) => validatePasswordConfirmation(
                  value,
                  _passwordController.text,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Guardando...' : 'Restablecer'),
        ),
      ],
    );
  }
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.cloud_off_rounded,
            size: 40,
            color: Theme.of(context).colorScheme.error,
          ),
          const SizedBox(height: 10),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('Reintentar'),
          ),
        ],
      ),
    );
  }
}
