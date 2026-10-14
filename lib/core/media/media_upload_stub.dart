import 'package:hercules_control/core/api/api_exception.dart';
import 'package:hercules_control/core/media/media_upload.dart';

/// Non-web: there is no file picker here.
Future<UploadedMedia?> pickAndUploadFile({
  required Uri uri,
  required String? token,
  required String accept,
  required void Function(double progress) onProgress,
}) => Future.error(
  const ApiException(
    0,
    'Subir archivos solo está disponible en la versión web.',
  ),
);
