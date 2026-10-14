import 'package:flutter/material.dart';
import 'package:hercules_control/core/api/api_exception.dart';
import 'package:hercules_control/core/media/media_upload.dart';

/// "Subir desde la computadora": picks a file, uploads it to Hércules with a
/// progress bar and hands the stored URL to [onUploaded]. Hidden when no
/// [MediaUploaderScope] provides an uploader.
class MediaUploadButton extends StatefulWidget {
  const MediaUploadButton({
    super.key,
    required this.kind,
    required this.onUploaded,
    this.label = 'Subir desde la computadora',
  });

  final MediaKind kind;
  final ValueChanged<String> onUploaded;
  final String label;

  @override
  State<MediaUploadButton> createState() => _MediaUploadButtonState();
}

class _MediaUploadButtonState extends State<MediaUploadButton> {
  bool _uploading = false;
  double? _progress;

  Future<void> _upload(MediaUploader uploader) async {
    setState(() {
      _uploading = true;
      _progress = null;
    });
    final messenger = ScaffoldMessenger.maybeOf(context);
    try {
      final uploaded = await uploader(widget.kind, (progress) {
        if (mounted) setState(() => _progress = progress.clamp(0, 1));
      });
      if (uploaded == null) return;
      widget.onUploaded(uploaded.url);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            widget.kind == MediaKind.video ? 'Video subido.' : 'Imagen subida.',
          ),
        ),
      );
    } on ApiException catch (error) {
      messenger?.showSnackBar(
        SnackBar(
          content: Text('No se pudo subir el archivo: ${error.message}'),
        ),
      );
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('No se pudo subir el archivo.')),
      );
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uploader = MediaUploaderScope.maybeOf(context);
    if (uploader == null) return const SizedBox.shrink();

    if (_uploading) {
      final progress = _progress;
      return SizedBox(
        width: 280,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              progress == null
                  ? 'Elige el archivo...'
                  : 'Subiendo... ${(progress * 100).round()} %',
            ),
            const SizedBox(height: 6),
            LinearProgressIndicator(value: progress),
          ],
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: () => _upload(uploader),
      icon: const Icon(Icons.upload_file_rounded),
      label: Text(widget.label),
    );
  }
}
