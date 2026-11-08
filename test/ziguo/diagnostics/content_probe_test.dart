import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:quax/ziguo/domain/resolved_content.dart';
import 'package:quax/ziguo/domain/source_ref.dart';
import 'package:quax/ziguo/domain/x_content_gateway.dart';
import 'package:quax/ziguo/features/diagnostics/content_probe_controller.dart';
import 'package:quax/ziguo/features/diagnostics/content_probe_screen.dart';

import '../domain/source_ref_test.dart' show refJson;

class ProbeGateway implements XContentGateway, XContentInspector {
  int reads = 0;
  @override
  Future<List<SourceRef>> inspectPost(String postId) async {
    reads++;
    return [
      SourceRef.fromJson({...refJson(), 'post_id': postId}),
    ];
  }

  @override
  Future<ResolvedContent> resolve(
    SourceRef source, {
    bool refresh = false,
  }) async => ResolvedText(source, '甲😀乙');
}

void main() {
  testWidgets('selects text sources and renders full Unicode content', (
    tester,
  ) async {
    final gateway = ProbeGateway();
    await tester.pumpWidget(
      MaterialApp(
        home: ContentProbeScreen(gateway: gateway, inspector: gateway),
      ),
    );
    await tester.tap(find.byType(DropdownButton<ContentRepresentation>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('小说 · 正文').last);
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField),
      'https://x.com/example/status/123',
    );
    await tester.tap(find.text('解析来源'));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(CheckboxListTile));
    await tester.tap(find.byType(CheckboxListTile));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.text('读取已选内容'));
    await tester.tap(find.text('读取已选内容'));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('甲😀乙'),
      250,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('甲😀乙'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  test('accepts X links, preserving supplied order, rejects foreign URLs', () {
    expect(
      parsePostIds(
        'https://x.com/example/status/123?s=20\nhttps://twitter.com/example/status/456',
      ),
      ['123', '456'],
    );
    expect(
      () => parsePostIds('https://x.com.evil.invalid/example/status/123'),
      throwsFormatException,
    );
    expect(
      () => parsePostIds('https://x.com/anything/123'),
      throwsFormatException,
    );
  });
  test('invalid JSON does not make a network request', () async {
    final gateway = ProbeGateway();
    final model = ContentProbeController(gateway: gateway, inspector: gateway);
    await model.inspect('{broken', ContentRepresentation.text);
    expect(gateway.reads, 0);
    expect(model.state.message, isNotNull);
    model.close();
  });
  test('metadata export excludes resolved content', () async {
    final gateway = ProbeGateway();
    final model = ContentProbeController(gateway: gateway, inspector: gateway);
    await model.inspect('123', ContentRepresentation.text);
    model.toggle(model.state.sources.first);
    await model.readSelected();
    expect(model.state.contents.single, isA<ResolvedText>());
    final exported = model.exportReferences();
    expect(exported, contains('post_id'));
    expect(exported, isNot(contains('甲')));
    model.close();
  });
}
