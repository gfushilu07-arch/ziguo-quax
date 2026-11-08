import 'package:flutter_test/flutter_test.dart';
import 'package:quax/ziguo/domain/content_access_exception.dart';
import 'package:quax/ziguo/domain/ordered_content_loader.dart';
import 'package:quax/ziguo/domain/resolved_content.dart';
import 'package:quax/ziguo/domain/source_ref.dart';
import 'package:quax/ziguo/domain/x_content_gateway.dart';

import 'source_ref_test.dart' show refJson;

class FakeGateway implements XContentGateway {
  final List<String> read = [];
  String? missing;
  @override
  Future<ResolvedContent> resolve(
    SourceRef source, {
    bool refresh = false,
  }) async {
    read.add(source.postId);
    await Future<void>.delayed(
      Duration(milliseconds: source.postId == '1' ? 20 : 1),
    );
    if (source.postId == missing) {
      throw const ContentAccessException(ContentAccessCode.sourceMissing);
    }
    return ResolvedText(source, source.postId == '1' ? '甲😀' : '乙');
  }
}

void main() {
  final refs = [
    '1',
    '2',
  ].map((id) => SourceRef.fromJson({...refJson(), 'post_id': id})).toList();
  test('preserves explicit order and Unicode', () async {
    final gateway = FakeGateway();
    final result = await loadOrderedContent(refs, gateway);
    expect(result.cast<ResolvedText>().map((e) => e.text), ['甲😀', '乙']);
    expect(gateway.read, ['1', '2']);
  });
  test(
    'does not return a partial novel or comic when a segment fails',
    () async {
      final gateway = FakeGateway()..missing = '2';
      await expectLater(
        loadOrderedContent(refs, gateway),
        throwsA(isA<ContentAccessException>()),
      );
    },
  );
}
