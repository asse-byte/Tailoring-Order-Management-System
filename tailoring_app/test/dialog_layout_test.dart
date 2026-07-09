import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:tailoring_app/core/theme/app_theme.dart';

/// Reproduces the pret-a-porter model dialog layout: the app theme gives
/// every ElevatedButton an infinite minimum width (Size.fromHeight), which
/// crashes inside a Row unless each button is wrapped in Expanded.
void main() {
  testWidgets('media buttons Row lays out under the app theme', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: const Scaffold(body: SizedBox()),
    ));

    final BuildContext ctx = tester.element(find.byType(Scaffold));
    showDialog<void>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: const Text('Nouveau Modèle'),
        content: SizedBox(
          width: 400,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const TextField(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.image_rounded, size: 16),
                        label: const Text('Image'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.videocam_rounded, size: 16),
                        label: const Text('Vidéo'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('Image'), findsOneWidget);
    expect(find.text('Vidéo'), findsOneWidget);
  });
}
