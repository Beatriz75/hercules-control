import 'package:flutter/widgets.dart';
import 'package:hercules_control/core/api/api_client.dart';
import 'package:hercules_control/core/auth/auth_controller.dart';

/// Exposes the [AuthController] (and its [ApiClient]) to the widget tree.
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({
    super.key,
    required AuthController controller,
    required super.child,
  }) : super(notifier: controller);

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope no disponible en este contexto.');
    return scope!.notifier!;
  }

  /// Reads the controller without subscribing to changes.
  static AuthController read(BuildContext context) {
    final element = context
        .getElementForInheritedWidgetOfExactType<AuthScope>();
    assert(element != null, 'AuthScope no disponible en este contexto.');
    return (element!.widget as AuthScope).notifier!;
  }

  static ApiClient apiOf(BuildContext context) => read(context).api;
}
