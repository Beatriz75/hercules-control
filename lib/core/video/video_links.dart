/// Video links accepted by the API and how to embed them.
library;

import 'package:hercules_control/core/media/media_upload.dart';

enum VideoKind { youtube, drive, vimeo, file, unknown }

typedef VideoEmbedInfo = ({VideoKind kind, String? embedUrl});

const _youtubeHosts = {'youtube.com', 'www.youtube.com', 'm.youtube.com'};
const _vimeoHosts = {'vimeo.com', 'www.vimeo.com', 'player.vimeo.com'};
final _youtubeId = RegExp(r'^[A-Za-z0-9_-]{6,}$');
final _numeric = RegExp(r'^\d+$');

/// Video uploaded to Hércules (POST /media), stored as a relative path.
final uploadedVideoPath = RegExp(r'^/media/[0-9a-f]{32}\.(mp4|webm)$');

Uri? _parseHttp(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || (uri.scheme != 'http' && uri.scheme != 'https')) {
    return null;
  }
  if (uri.host.isEmpty) return null;
  return uri;
}

bool _isVideoFile(Uri uri) {
  final path = uri.path.toLowerCase();
  return path.endsWith('.mp4') || path.endsWith('.webm');
}

/// Converts a YouTube / Google Drive / Vimeo / .mp4 / .webm link to the URL
/// to embed. Unknown or invalid links return [VideoKind.unknown].
VideoEmbedInfo toEmbedUrl(String url) {
  const unknown = (kind: VideoKind.unknown, embedUrl: null);
  if (uploadedVideoPath.hasMatch(url.trim())) {
    return (kind: VideoKind.file, embedUrl: resolveMediaUrl(url.trim()));
  }
  final uri = _parseHttp(url);
  if (uri == null) return unknown;
  final host = uri.host.toLowerCase();
  final segments = uri.pathSegments.where((s) => s.isNotEmpty).toList();

  String? youtube(String? id) => id != null && _youtubeId.hasMatch(id)
      ? 'https://www.youtube.com/embed/$id'
      : null;

  if (_youtubeHosts.contains(host)) {
    String? id;
    if (segments.isNotEmpty && segments.first == 'watch') {
      id = uri.queryParameters['v'];
    } else if (segments.length >= 2 &&
        const {'shorts', 'embed', 'live', 'v'}.contains(segments.first)) {
      id = segments[1];
    }
    final embed = youtube(id);
    return embed == null ? unknown : (kind: VideoKind.youtube, embedUrl: embed);
  }
  if (host == 'youtu.be') {
    final embed = youtube(segments.isEmpty ? null : segments.first);
    return embed == null ? unknown : (kind: VideoKind.youtube, embedUrl: embed);
  }
  if (host == 'drive.google.com') {
    String? id;
    final fileIndex = segments.indexOf('d');
    if (segments.isNotEmpty &&
        segments.first == 'file' &&
        fileIndex != -1 &&
        fileIndex + 1 < segments.length) {
      id = segments[fileIndex + 1];
    } else {
      id = uri.queryParameters['id'];
    }
    if (id == null || id.isEmpty) return unknown;
    return (
      kind: VideoKind.drive,
      embedUrl: 'https://drive.google.com/file/d/$id/preview',
    );
  }
  if (_vimeoHosts.contains(host)) {
    final id = segments.lastWhere(_numeric.hasMatch, orElse: () => '');
    if (id.isEmpty) return unknown;
    return (
      kind: VideoKind.vimeo,
      embedUrl: 'https://player.vimeo.com/video/$id',
    );
  }
  if (_isVideoFile(uri)) {
    return (kind: VideoKind.file, embedUrl: uri.toString());
  }
  return unknown;
}

/// Mirrors the server validation. Empty = no video (valid).
String? validateVideoUrl(String? value) {
  final text = value?.trim() ?? '';
  if (text.isEmpty) return null;
  if (uploadedVideoPath.hasMatch(text)) return null;
  final uri = _parseHttp(text);
  if (uri == null) {
    return 'El enlace del video debe empezar con http:// o https://.';
  }
  const hosts = {
    'youtube.com',
    'www.youtube.com',
    'm.youtube.com',
    'youtu.be',
    'drive.google.com',
    'vimeo.com',
    'player.vimeo.com',
  };
  if (hosts.contains(uri.host.toLowerCase()) || _isVideoFile(uri)) {
    return null;
  }
  return 'El video debe ser un enlace de YouTube, Google Drive, Vimeo, un archivo .mp4 / .webm o un video subido a Hércules.';
}

/// Validator for the optional video title (max 160).
String? validateVideoTitle(String? value) {
  if ((value?.trim().length ?? 0) > 160) {
    return 'El título del video admite máximo 160 caracteres.';
  }
  return null;
}
