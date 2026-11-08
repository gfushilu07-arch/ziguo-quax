import 'content_access_exception.dart';
import 'resolved_content.dart';
import 'source_ref.dart';
import 'x_content_gateway.dart';

Future<List<ResolvedContent>> loadOrderedContent(
  List<SourceRef> orderedSources,
  XContentGateway gateway,
) async {
  if (orderedSources.isEmpty) {
    throw const FormatException('Select at least one reference');
  }
  final results = <ResolvedContent>[];
  // Bound concurrency to one: reading a chapter must not burst through X quotas.
  for (final source in orderedSources) {
    final content = await gateway.resolve(source);
    if (content.sourceRefId != source.id ||
        content.revision != source.revision) {
      throw const ContentAccessException(ContentAccessCode.sourceChanged);
    }
    results.add(content);
  }
  return List.unmodifiable(results);
}
