import 'dart:js_interop';
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
        ..allow = 'fullscreen; autoplay; encrypted-media; picture-in-picture'
        ..allowFullscreen = true
        ..referrerPolicy = 'strict-origin-when-cross-origin';
      iframe.style
        ..width = '100%'
        ..height = '100%'
        ..border = '0';
      // A focused (cross-origin) iframe keeps every key press, so Esc would
      // never reach the app. Give the focus back when the mouse leaves it.
      iframe.addEventListener(
        'mouseleave',
        ((web.Event _) {
          if (web.document.activeElement == iframe) iframe.blur();
        }).toJS,
      );
      return iframe;
    });
  }
  return HtmlElementView(viewType: viewType);
}

bool openExternalUrl(String url) {
  web.window.open(url, '_blank', 'noopener');
  return true;
}
