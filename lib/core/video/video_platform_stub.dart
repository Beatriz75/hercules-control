import 'package:flutter/widgets.dart';
import 'package:hercules_control/core/video/video_links.dart';

/// Non-web: no embedded player (the caller shows a link card instead).
Widget? buildPlatformVideoPlayer(String embedUrl, VideoKind kind) => null;

/// Non-web: links can't be opened from here; returns false.
bool openExternalUrl(String url) => false;
