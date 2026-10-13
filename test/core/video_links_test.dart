import 'package:flutter_test/flutter_test.dart';
import 'package:hercules_control/core/video/video_links.dart';

void main() {
  const youtubeEmbed = 'https://www.youtube.com/embed/dQw4w9WgXcQ';

  test('YouTube watch, youtu.be, shorts and embed links', () {
    for (final url in [
      'https://www.youtube.com/watch?v=dQw4w9WgXcQ',
      'https://youtube.com/watch?v=dQw4w9WgXcQ&t=30s',
      'https://m.youtube.com/watch?v=dQw4w9WgXcQ',
      'https://youtu.be/dQw4w9WgXcQ',
      'https://youtu.be/dQw4w9WgXcQ?si=abc',
      'https://www.youtube.com/shorts/dQw4w9WgXcQ',
      'https://www.youtube.com/embed/dQw4w9WgXcQ',
    ]) {
      final info = toEmbedUrl(url);
      expect(info.kind, VideoKind.youtube, reason: url);
      expect(info.embedUrl, youtubeEmbed, reason: url);
    }
  });

  test('Google Drive file and open?id links', () {
    const embed = 'https://drive.google.com/file/d/1AbC_dEf/preview';
    expect(
      toEmbedUrl('https://drive.google.com/file/d/1AbC_dEf/view?usp=sharing'),
      (kind: VideoKind.drive, embedUrl: embed),
    );
    expect(toEmbedUrl('https://drive.google.com/open?id=1AbC_dEf'), (
      kind: VideoKind.drive,
      embedUrl: embed,
    ));
  });

  test('Vimeo links', () {
    const embed = 'https://player.vimeo.com/video/76979871';
    expect(toEmbedUrl('https://vimeo.com/76979871'), (
      kind: VideoKind.vimeo,
      embedUrl: embed,
    ));
    expect(toEmbedUrl('https://player.vimeo.com/video/76979871'), (
      kind: VideoKind.vimeo,
      embedUrl: embed,
    ));
  });

  test('mp4 and webm files play in an HTML5 video', () {
    expect(
      toEmbedUrl('https://cdn.example.com/clases/intro.mp4').kind,
      VideoKind.file,
    );
    expect(
      toEmbedUrl('http://example.com/a/b/video.WEBM?x=1').embedUrl,
      'http://example.com/a/b/video.WEBM?x=1',
    );
  });

  test('invalid or unsupported links are unknown', () {
    for (final url in [
      '',
      'youtube.com/watch?v=dQw4w9WgXcQ',
      'ftp://example.com/video.mp4',
      'https://www.youtube.com/watch',
      'https://example.com/pagina',
      'https://vimeo.com/canal',
    ]) {
      expect(toEmbedUrl(url).kind, VideoKind.unknown, reason: url);
      expect(toEmbedUrl(url).embedUrl, isNull, reason: url);
    }
  });

  test('validation mirrors the server messages', () {
    expect(validateVideoUrl(null), isNull);
    expect(validateVideoUrl('  '), isNull);
    expect(validateVideoUrl('https://youtu.be/dQw4w9WgXcQ'), isNull);
    expect(validateVideoUrl('https://drive.google.com/file/d/x/view'), isNull);
    expect(validateVideoUrl('https://example.com/v.mp4'), isNull);
    expect(
      validateVideoUrl('www.youtube.com/watch?v=x'),
      'El enlace del video debe empezar con http:// o https://.',
    );
    expect(
      validateVideoUrl('https://example.com/video'),
      'El video debe ser un enlace de YouTube, Google Drive, Vimeo o un archivo .mp4 / .webm.',
    );
    expect(validateVideoTitle('x' * 161), isNotNull);
    expect(validateVideoTitle('Intro'), isNull);
  });
}
