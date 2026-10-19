import 'package:flutter/material.dart';
import 'package:hercules_control/core/video/video_links.dart';
import 'package:hercules_control/core/video/video_platform.dart';

/// Builds the platform player. Tests can replace it (on the VM there is no
/// web player, so the link card would be shown instead).
@visibleForTesting
Widget? Function(String embedUrl, VideoKind kind) debugVideoPlayerBuilder =
    buildPlatformVideoPlayer;

/// Embedded video (16:9, up to [maxWidth] wide, rounded) with a
/// "Ver en grande" action. On non-web platforms or for unknown formats it
/// shows a card with an "Abrir video" action.
///
/// On the web the player is an <iframe>/<video> platform view, which swallows
/// every click inside its rectangle even when a Flutter dialog is painted on
/// top of it. So while another route (confirmation, menu, dialog) covers the
/// route that holds the video, the player is removed and a placeholder of the
/// same size is shown: the buttons of that dialog always get the click and the
/// video stops. It comes back when the dialog closes.
class VideoEmbed extends StatelessWidget {
  const VideoEmbed({
    super.key,
    required this.url,
    this.title,
    this.maxWidth = 900,
  });

  final String url;
  final String? title;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final info = toEmbedUrl(url);
    final covered = !(ModalRoute.of(context)?.isCurrent ?? true);
    final livePlayer = info.embedUrl == null
        ? null
        : debugVideoPlayerBuilder(info.embedUrl!, info.kind);
    final canPlay = livePlayer != null;
    final player = covered ? null : livePlayer;
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
          if (canPlay) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: player ?? const _VideoPausedPlaceholder(),
              ),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: covered
                    ? null
                    : () => showLargeVideoDialog(context, url, title: title),
                icon: const Icon(Icons.fullscreen_rounded, size: 20),
                label: const Text('Ver en grande'),
              ),
            ),
          ] else
            _VideoLinkCard(url: url),
        ],
      ),
    );
  }
}

/// Opens the video almost full screen. The iframe also allows the player's
/// own full-screen button.
Future<void> showLargeVideoDialog(
  BuildContext context,
  String url, {
  String? title,
}) {
  return showDialog<void>(
    context: context,
    builder: (context) => _LargeVideoDialog(url: url, title: title),
  );
}

class _LargeVideoDialog extends StatelessWidget {
  const _LargeVideoDialog({required this.url, this.title});

  final String url;
  final String? title;

  @override
  Widget build(BuildContext context) {
    final title = this.title?.trim() ?? '';
    final info = toEmbedUrl(url);
    final player = info.embedUrl == null
        ? null
        : debugVideoPlayerBuilder(info.embedUrl!, info.kind);

    return Dialog(
      insetPadding: const EdgeInsets.all(16),
      backgroundColor: Colors.black,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 16),
        child: Column(
          children: [
            // Header outside the video rectangle so "Cerrar" never sits
            // under the iframe.
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.isEmpty ? 'Video' : title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton.icon(
                  style: TextButton.styleFrom(foregroundColor: Colors.white),
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  label: const Text('Cerrar'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: Center(
                child: player == null
                    ? _VideoLinkCard(url: url)
                    : AspectRatio(aspectRatio: 16 / 9, child: player),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _VideoPausedPlaceholder extends StatelessWidget {
  const _VideoPausedPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: Colors.black,
      child: Center(
        child: Icon(
          Icons.play_circle_outline_rounded,
          color: Colors.white54,
          size: 48,
        ),
      ),
    );
  }
}

class _VideoLinkCard extends StatelessWidget {
  const _VideoLinkCard({required this.url});

  /// Below this width the "Abrir video" button goes under the link.
  static const double _stackLinkBelow = 420;

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
      // Narrow screens: the button goes under the link so it stays readable.
      child: LayoutBuilder(
        builder: (context, constraints) {
          final link = Row(
            children: [
              Icon(
                Icons.play_circle_fill_rounded,
                color: colorScheme.primary,
                size: 36,
              ),
              const SizedBox(width: 12),
              Expanded(child: SelectableText(url, maxLines: 2)),
            ],
          );
          final open = TextButton.icon(
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
          );

          if (constraints.maxWidth < _stackLinkBelow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                link,
                Align(alignment: Alignment.centerRight, child: open),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: link),
              const SizedBox(width: 8),
              open,
            ],
          );
        },
      ),
    );
  }
}
