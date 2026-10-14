import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hercules_control/core/video/video_platform.dart';
import 'package:hercules_control/core/widgets/video_embed.dart';

const _url = 'https://youtu.be/dQw4w9WgXcQ';
const _playerKey = ValueKey('fake-player');

void main() {
  setUp(() {
    debugVideoPlayerBuilder = (embedUrl, kind) =>
        const ColoredBox(key: _playerKey, color: Colors.red);
  });
  tearDown(() => debugVideoPlayerBuilder = buildPlatformVideoPlayer);

  Future<void> pumpHost(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) => Column(
              children: [
                const VideoEmbed(url: _url),
                TextButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (context) => AlertDialog(
                      title: const Text('¿Salir de la práctica?'),
                      actions: [
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Salir'),
                        ),
                      ],
                    ),
                  ),
                  child: const Text('Abrir confirmación'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('removes the player while a dialog covers it', (tester) async {
    await pumpHost(tester);
    expect(find.byKey(_playerKey), findsOneWidget);

    await tester.tap(find.text('Abrir confirmación'));
    await tester.pumpAndSettle();
    // The iframe would swallow the clicks of the dialog: it must be gone.
    expect(find.byKey(_playerKey), findsNothing);

    await tester.tap(find.text('Salir'));
    await tester.pumpAndSettle();
    expect(find.byKey(_playerKey), findsOneWidget);
  });

  testWidgets('"Ver en grande" opens a large dialog that closes', (
    tester,
  ) async {
    await pumpHost(tester);
    final inlineWidth = tester.getSize(find.byKey(_playerKey)).width;
    expect(inlineWidth, 900);

    await tester.tap(find.text('Ver en grande'));
    await tester.pumpAndSettle();
    // Only the large player is mounted, and it is bigger than the inline one.
    expect(find.byKey(_playerKey), findsOneWidget);
    expect(
      tester.getSize(find.byKey(_playerKey)).width,
      greaterThan(inlineWidth),
    );

    await tester.tap(find.text('Cerrar'));
    await tester.pumpAndSettle();
    expect(find.text('Cerrar'), findsNothing);
    expect(find.byKey(_playerKey), findsOneWidget);
  });
}
