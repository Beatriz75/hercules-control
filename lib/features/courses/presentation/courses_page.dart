import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hercules_control/core/api/api_client.dart';
import 'package:hercules_control/core/auth/auth_scope.dart';
import 'package:hercules_control/core/auth/current_user.dart';
import 'package:hercules_control/core/layout/breakpoints.dart';
import 'package:hercules_control/core/theme/app_theme.dart';
import 'package:hercules_control/core/media/media_upload.dart';
import 'package:hercules_control/core/widgets/app_panel.dart';
import 'package:hercules_control/core/widgets/media_upload_button.dart';
import 'package:hercules_control/core/widgets/metric_card.dart';
import 'package:hercules_control/core/widgets/page_header.dart';
import 'package:hercules_control/core/widgets/responsive_dialog.dart';
import 'package:hercules_control/core/widgets/video_embed.dart';
import 'package:hercules_control/core/video/video_links.dart';
import 'package:hercules_control/features/courses/data/course_models.dart';
import 'package:hercules_control/features/courses/data/course_search.dart';
import 'package:hercules_control/features/courses/data/courses_repository.dart';
import 'package:hercules_control/features/courses/data/question_bank.dart';
import 'package:hercules_control/app/navigation/app_section.dart';
import 'package:hercules_control/app/navigation/shell_navigation.dart';
import 'package:hercules_control/features/courses/presentation/clipboard_image_reader.dart';
import 'package:intl/intl.dart';

part 'course_attempts_review.dart';
part 'course_editor_dialog.dart';
part 'course_practice_dialog.dart';
part 'course_progress_view.dart';
part 'course_shared_widgets.dart';
part 'course_staff_view.dart';
part 'course_student_view.dart';
part 'question_bank_view.dart';

/// Entry point of the Cursos module. Staff (courses.view) get the catalog,
/// students (courses.take) get their assigned courses.
class CoursesPage extends StatelessWidget {
  const CoursesPage({super.key, this.initialCourseId});

  /// Course to select when opening the staff catalog (e.g. from the bank).
  final int? initialCourseId;

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    final repository = CoursesRepository(auth.api);

    if (auth.can(Permissions.coursesView)) {
      return _StaffCoursesView(
        repository: repository,
        canManage: auth.can(Permissions.coursesManage),
        canViewProgress: auth.can(Permissions.coursesProgressView),
        initialCourseId: initialCourseId,
      );
    }
    if (auth.can(Permissions.coursesTake)) {
      return _StudentCoursesView(
        repository: repository,
        storeCode: auth.user?.storeCode,
      );
    }
    return const _EmptyState(
      icon: Icons.lock_rounded,
      message: 'No tienes acceso al módulo de Cursos.',
    );
  }
}
