import 'package:flutter/widgets.dart';
import 'package:hercules_control/core/api/api_client.dart';
import 'package:hercules_control/core/media/media_upload_platform.dart';

/// What the course editor uploads to Hércules (POST /media).
enum MediaKind {
  video('.mp4,.webm,video/mp4,video/webm'),
  image('.png,.jpg,.jpeg,.webp,.gif,image/png,image/jpeg,image/webp,image/gif');

  const MediaKind(this.accept);

  /// `accept` attribute of the file picker.
  final String accept;
}

/// Answer of POST /media. [url] is relative (`/media/<file>`): it is stored
/// as is and resolved against the API with [resolveMediaUrl] to show it.
class UploadedMedia {
  const UploadedMedia({
    required this.url,
    required this.size,
    required this.contentType,
  });

  factory UploadedMedia.fromJson(Map<String, dynamic> json) => UploadedMedia(
    url: json['url'] as String,
    size: (json['size'] as num?)?.toInt() ?? 0,
    contentType: json['content_type'] as String? ?? '',
  );

  final String url;
  final int size;
  final String contentType;
}

/// Lets the user choose a file and uploads it, reporting progress (0..1).
/// Returns null when the user cancels the picker; throws [ApiException] when
/// the upload fails.
typedef MediaUploader =
    Future<UploadedMedia?> Function(
      MediaKind kind,
      void Function(double progress) onProgress,
    );

/// Uploader that sends the file to POST /media of [api] with its token.
MediaUploader apiMediaUploader(ApiClient api) =>
    (kind, onProgress) => pickAndUploadFile(
      uri: api.uri('/media'),
      token: api.token,
      accept: kind.accept,
      onProgress: onProgress,
    );

/// Files uploaded to Hércules are saved as `/media/<file>` (relative to the
/// API). Anything else (http links, data URLs) is returned unchanged.
String resolveMediaUrl(String url, {String baseUrl = apiBaseUrl}) {
  final trimmed = url.trim();
  if (!trimmed.startsWith('/media/')) return url;
  final base = baseUrl.endsWith('/')
      ? baseUrl.substring(0, baseUrl.length - 1)
      : baseUrl;
  final raw = '$base$trimmed';
  return raw.startsWith('http://') || raw.startsWith('https://')
      ? raw
      : Uri.base.resolve(raw).toString();
}

/// Makes a [MediaUploader] available to the editor widgets below it. Without
/// one, the "Subir desde la computadora" buttons are hidden.
class MediaUploaderScope extends InheritedWidget {
  const MediaUploaderScope({
    super.key,
    required this.uploader,
    required super.child,
  });

  final MediaUploader? uploader;

  static MediaUploader? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<MediaUploaderScope>()
      ?.uploader;

  @override
  bool updateShouldNotify(MediaUploaderScope oldWidget) =>
      uploader != oldWidget.uploader;
}
