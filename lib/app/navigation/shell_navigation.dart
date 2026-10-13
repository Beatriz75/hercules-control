import 'package:flutter/widgets.dart';
import 'package:hercules_control/app/navigation/app_section.dart';

/// Lets a page switch the shell to another section (for example, from the
/// question bank to Cursos with a course selected).
class ShellNavigation extends InheritedWidget {
  const ShellNavigation({super.key, required this.goTo, required super.child});

  final void Function(AppSection section, {int? courseId}) goTo;

  static ShellNavigation? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellNavigation>();

  @override
  bool updateShouldNotify(ShellNavigation oldWidget) => false;
}
