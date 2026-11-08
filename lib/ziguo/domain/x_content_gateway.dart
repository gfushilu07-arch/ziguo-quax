import 'resolved_content.dart';
import 'source_ref.dart';

abstract interface class XContentGateway {
  Future<ResolvedContent> resolve(SourceRef source, {bool refresh = false});
}

/// Used on the publishing/diagnostic device to select explicit media identities.
abstract interface class XContentInspector {
  Future<List<SourceRef>> inspectPost(String postId);
}
