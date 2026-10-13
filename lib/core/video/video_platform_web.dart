import 'dart:ui_web' as ui_web;

import 'package:flutter/widgets.dart';
import 'package:hercules_control/core/video/video_links.dart';
import 'package:web/web.dart' as web;

final _registered = <String>{};

String _viewType(String embedUrl, VideoKind kind) =>
    'hercules-video-${kind.name}-${embedUrl.hashCode}';

/// Web: an <iframe> (YouTube / Drive / Vimeo) or <video controls> (files),
/// registered once per URL.
Widget? buildPlatformVideoPlayer(String embedUrl, VideoKind kind) {
  final viewType = _viewType(embedUrl, kind);
  if (_registered.add(viewType)) {
    ui_web.platformViewRegistry.registerViewFactory(viewType, (int _) {
      if (kind == VideoKind.file) {
        final video = web.HTMLVideoElement()
          ..src = embedUrl
          ..controls = true
          ..preload = 'metadata';
        video.style
          ..width = '100%'
          ..height = '100%'
          ..border = '0'
          ..backgroundColor = '#000';
        return video;
      }
      final iframe = web.HTMLIFrameElement()
        ..src = embedUrl
        ..allow = 'autoplay; encrypted-media; picture-in-picture; fullscreen'
        ..allowFullscreen = true;
      iframe.style
        ..width = '100%'
        ..height = '100%'
        ..border = '0';
      return iframe;
    });
  }
  return HtmlElementView(viewType: viewType);
}

bool openExternalUrl(String url) {
  web.window.open(url, '_blank', 'noopener');
  return true;
}
