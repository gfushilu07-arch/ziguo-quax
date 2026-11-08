// Manual opt-in only. This uses real X and the device's own QuaX account store.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:better_player_plus/better_player_plus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/client/client.dart';
import 'package:quax/database/repository.dart';
import 'package:quax/ziguo/domain/content_access_exception.dart';
import 'package:quax/ziguo/domain/resolved_content.dart';
import 'package:quax/ziguo/domain/source_ref.dart';
import 'package:quax/ziguo/integration/quax/quax_x_content_gateway.dart';

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const enabled = bool.fromEnvironment('ZIGUO_LIVE_X');
  testWidgets(
    'live X video, ordered text and image pages',
    (tester) async {
      await Repository().migrate();
      final gateway = QuaXXContentGateway(
        loadTweet: (id) => Twitter.getTweet(id),
      );
      final cases = <(String, ContentRepresentation)>[
        ('2095920036523172091', ContentRepresentation.video),
        ('2095916385209651546', ContentRepresentation.text),
        ('2095916387017408802', ContentRepresentation.text),
        ('2095922394959421815', ContentRepresentation.image),
        ('2095918939641356306', ContentRepresentation.image),
      ];
      final results = <Map<String, Object?>>[];
      for (final sample in cases) {
        try {
          final refs = await gateway.inspectPost(sample.$1);
          final selected = refs
              .where((e) => e.representation == sample.$2)
              .toList();
          if (selected.isEmpty) {
            throw const ContentAccessException(
              ContentAccessCode.sourceIncomplete,
            );
          }
          var count = 0;
          for (final ref in selected) {
            final content = await gateway.resolve(ref);
            if (content is ResolvedText) {
              expect(content.text.trim(), isNotEmpty);
            } else if (content is ResolvedImage) {
              final client = HttpClient();
              try {
                final response = await (await client.getUrl(content.uri))
                    .close()
                    .timeout(const Duration(seconds: 30));
                expect(response.statusCode, 200);
                final bytes = <int>[];
                await for (final chunk in response) {
                  bytes.addAll(chunk);
                  if (bytes.length > 20 * 1024 * 1024) {
                    throw const ContentAccessException(
                      ContentAccessCode.unsupported,
                    );
                  }
                }
                final buffer = await ui.ImmutableBuffer.fromUint8List(
                  Uint8List.fromList(bytes),
                );
                final codec = await ui.instantiateImageCodecFromBuffer(buffer);
                final frame = await codec.getNextFrame();
                expect(frame.image.width, greaterThan(0));
                frame.image.dispose();
                codec.dispose();
              } finally {
                client.close(force: true);
              }
            } else if (content is ResolvedVideo) {
              final player = BetterPlayerController(
                const BetterPlayerConfiguration(
                  autoPlay: true,
                  autoDispose: false,
                  handleLifecycle: false,
                ),
              );
              try {
                await tester.pumpWidget(
                  MaterialApp(
                    home: Scaffold(body: BetterPlayer(controller: player)),
                  ),
                );
                await player.setupDataSource(
                  BetterPlayerDataSource.network(
                    content.variants.first.uri.toString(),
                    cacheConfiguration: const BetterPlayerCacheConfiguration(
                      useCache: false,
                    ),
                  ),
                );
                final deadline = DateTime.now().add(
                  const Duration(seconds: 40),
                );
                while ((player
                                .videoPlayerController
                                ?.value
                                .position
                                .inMilliseconds ??
                            0) <
                        500 &&
                    DateTime.now().isBefore(deadline)) {
                  await tester.pump(const Duration(milliseconds: 250));
                  await Future<void>.delayed(const Duration(milliseconds: 250));
                }
                expect(
                  player.videoPlayerController?.value.position.inMilliseconds ??
                      0,
                  greaterThanOrEqualTo(500),
                );
                await tester.pumpWidget(const SizedBox());
              } finally {
                player.dispose(forceDispose: true);
              }
            }
            count++;
          }
          results.add({
            'post_id': sample.$1,
            'kind': sample.$2.name,
            'status': 'passed',
            'items': count,
          });
        } on ContentAccessException catch (error) {
          results.add({
            'post_id': sample.$1,
            'kind': sample.$2.name,
            'status': error.code.name,
          });
          if (error.code == ContentAccessCode.authRequired ||
              error.code == ContentAccessCode.rateLimited) {
            break;
          }
        } catch (_) {
          results.add({
            'post_id': sample.$1,
            'kind': sample.$2.name,
            'status': 'render_or_network_failed',
          });
        }
      }
      binding.reportData = {'ziguo_live_x': results};
      // Metadata only; no response bodies, text, URLs with signatures or credentials.
      // ignore: avoid_print
      print('ZIGUO_LIVE_RESULT ${jsonEncode(results)}');
      expect(
        results.length,
        cases.length,
        reason: 'All sample types must be checked',
      );
      expect(
        results.every((e) => e['status'] == 'passed'),
        isTrue,
        reason: 'Live failures are not replaced with fixture successes',
      );
    },
    skip: !enabled,
    timeout: const Timeout(Duration(minutes: 8)),
  );
}
