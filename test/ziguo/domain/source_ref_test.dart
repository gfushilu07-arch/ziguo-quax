import 'package:flutter_test/flutter_test.dart';
import 'package:quax/ziguo/domain/source_ref.dart';

Map<String, Object?> refJson({String kind = 'text'}) => {
  'id': '63bd7b11-1d77-4230-9193-f20b1ac9f6a5',
  'provider': 'x',
  'post_id': '2109404168712823282',
  'representation': kind,
  'revision': 1,
  if (kind != 'text') 'media_id': '2109404168712823200',
};

void main() {
  test('large X IDs round trip as strings', () {
    final json = refJson(kind: 'video');
    expect(SourceRef.fromJson(json).toJson(), json);
  });
  test('all supported representations are typed', () {
    for (final kind in ContentRepresentation.values) {
      expect(SourceRef.fromJson(refJson(kind: kind.name)).representation, kind);
    }
  });
  for (final entry in <String, Object?>{
    'post_id': 2109404168712823282,
    'provider': 'other',
    'media_index': -1,
    'revision': 0,
    'id': 'not-a-uuid',
    'representation': 'article',
    'publisher_user_id': '',
    'body': 'must not reach metadata storage',
    'media_url': 'https://video.twimg.com/example.mp4',
  }.entries) {
    test('rejects invalid ${entry.key}', () {
      expect(
        () => SourceRef.fromJson({...refJson(), entry.key: entry.value}),
        throwsFormatException,
      );
    });
  }
  test('visual references require media ID; text excludes media selection', () {
    final video = refJson(kind: 'video')..remove('media_id');
    expect(() => SourceRef.fromJson(video), throwsFormatException);
    expect(
      () => SourceRef.fromJson({...refJson(), 'media_id': '123'}),
      throwsFormatException,
    );
    expect(
      () => SourceRef.fromJson({...refJson(), 'media_index': 0}),
      throwsFormatException,
    );
  });
}
