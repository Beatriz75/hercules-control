import 'package:flutter/material.dart';
import 'package:hercules_control/core/video/video_links.dart';
import 'package:hercules_control/core/video/video_platform.dart';

/// Embedded video (16:9, max 720 px wide, rounded). On non-web platforms or
/// for unknown formats it shows a card with an "Abrir video" action.
class VideoEmbed extends StatelessWidget {
  const VideoEmbed({
    super.key,
    required this.url,
    this.title,
    this.maxWidth = 720,
  });

  final String url;
  final String? title;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final info = toEmbedUrl(url);
    final player = info.embedUrl == null
        ? null
        : buildPlatformVideoPlayer(info.embedUrl!, info.kind);
    final title = this.title?.trim() ?? '';

    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (title.isNotEmpty) ...[
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
          ],
          if (player != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(aspectRatio: 16 / 9, child: player),
            )
          else
            _VideoLinkCard(url: url),
        ],
      ),
    );
  }
}

class _VideoLinkCard extends StatelessWidget {
  const _VideoLinkCard({required this.url});

  final String url;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: colorScheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(
            Icons.play_circle_fill_rounded,
            color: colorScheme.primary,
            size: 36,
          ),
          const SizedBox(width: 12),
          Expanded(child: SelectableText(url, maxLines: 2)),
          const SizedBox(width: 8),
          TextButton.icon(
            onPressed: () {
              if (!openExternalUrl(url)) {
                ScaffoldMessenger.maybeOf(context)?.showSnackBar(
                  const SnackBar(
                    content: Text('Copia el enlace para abrir el video.'),
                  ),
                );
              }
            },
            icon: const Icon(Icons.open_in_new_rounded, size: 18),
            label: const Text('Abrir video'),
          ),
        ],
      ),
    );
  }
}
