import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

Future<String?> readClipboardImageDataUrl() async {
  final items = await web.window.navigator.clipboard.read().toDart;

  for (final item in items.toDart) {
    final imageType = item.types.toDart
        .map((type) => type.toDart)
        .cast<String?>()
        .firstWhere(
          (type) => type?.startsWith('image/') ?? false,
          orElse: () => null,
        );
    if (imageType == null) continue;

    final blob = await item.getType(imageType).toDart;
    return _readBlobAsDataUrl(blob);
  }

  return null;
}

Future<String> _readBlobAsDataUrl(web.Blob blob) {
  final completer = Completer<String>();
  final reader = web.FileReader();

  reader.onload = ((web.Event _) {
    final result = reader.result;
    if (result != null) {
      completer.complete((result as JSString).toDart);
    } else {
      completer.completeError(StateError('No se pudo leer la imagen pegada.'));
    }
  }).toJS;
  reader.onerror = ((web.Event _) {
    completer.completeError(StateError('No se pudo leer la imagen pegada.'));
  }).toJS;
  reader.readAsDataURL(blob);

  return completer.future;
}
