import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:hercules_control/core/api/api_exception.dart';
import 'package:hercules_control/core/media/media_upload.dart';
import 'package:web/web.dart' as web;

/// Web: opens the browser file picker and uploads the chosen file with an
/// XMLHttpRequest (multipart). The browser streams the file from disk, so
/// big videos are never loaded in memory, and the upload reports progress.
Future<UploadedMedia?> pickAndUploadFile({
  required Uri uri,
  required String? token,
  required String accept,
  required void Function(double progress) onProgress,
}) async {
  final file = await _pickFile(accept);
  if (file == null) return null;

  final completer = Completer<UploadedMedia>();
  final request = web.XMLHttpRequest()..open('POST', uri.toString());
  request.setRequestHeader('Accept', 'application/json');
  if (token != null) request.setRequestHeader('Authorization', 'Bearer $token');

  request.upload.addEventListener(
    'progress',
    ((web.ProgressEvent event) {
      if (event.lengthComputable && event.total > 0) {
        onProgress(event.loaded / event.total);
      }
    }).toJS,
  );
  request.addEventListener(
    'load',
    ((web.Event _) {
      final status = request.status;
      final body = request.responseText;
      if (status >= 200 && status < 300) {
        try {
          completer.complete(
            UploadedMedia.fromJson(jsonDecode(body) as Map<String, dynamic>),
          );
        } catch (_) {
          completer.completeError(
            const ApiException(0, 'El servidor no confirmó la subida.'),
          );
        }
        return;
      }
      completer.completeError(
        status == 413 && !body.trimLeft().startsWith('{')
            ? const ApiException(413, 'El archivo es demasiado grande.')
            : ApiException.fromResponse(status, body),
      );
    }).toJS,
  );
  void failed(web.Event _) {
    if (!completer.isCompleted) {
      completer.completeError(ApiException(0, ApiException.defaultMessage(0)));
    }
  }

  request.addEventListener('error', failed.toJS);
  request.addEventListener('abort', failed.toJS);
  request.addEventListener('timeout', failed.toJS);

  final form = web.FormData()..append('file', file, file.name);
  onProgress(0);
  request.send(form);
  return completer.future;
}

Future<web.File?> _pickFile(String accept) {
  final completer = Completer<web.File?>();
  final input = web.HTMLInputElement()
    ..type = 'file'
    ..accept = accept;
  input.addEventListener(
    'change',
    ((web.Event _) {
      final files = input.files;
      if (!completer.isCompleted) {
        completer.complete(
          files != null && files.length > 0 ? files.item(0) : null,
        );
      }
    }).toJS,
  );
  input.addEventListener(
    'cancel',
    ((web.Event _) {
      if (!completer.isCompleted) completer.complete(null);
    }).toJS,
  );
  input.click();
  return completer.future;
}
