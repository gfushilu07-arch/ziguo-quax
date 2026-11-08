import 'source_ref.dart';

/// Ephemeral device-local values. Deliberately has no persistence/JSON API.
sealed class ResolvedContent {
  final SourceRef source;
  final String authorName;
  final String authorHandle;
  const ResolvedContent(
    this.source, {
    this.authorName = '',
    this.authorHandle = '',
  });
  String get sourceRefId => source.id;
  int get revision => source.revision;
  String get postId => source.postId;
}

final class ResolvedText extends ResolvedContent {
  final String text;
  const ResolvedText(
    super.source,
    this.text, {
    super.authorName,
    super.authorHandle,
  });
}

final class ResolvedImage extends ResolvedContent {
  final String mediaId;
  final Uri uri;
  const ResolvedImage(
    super.source, {
    required this.mediaId,
    required this.uri,
    super.authorName,
    super.authorHandle,
  });
}

final class VideoVariant {
  final Uri uri;
  final String mimeType;
  final int? bitrate;
  const VideoVariant(this.uri, this.mimeType, this.bitrate);
}

final class ResolvedVideo extends ResolvedContent {
  final String mediaId;
  final List<VideoVariant> variants;
  final double aspectRatio;
  const ResolvedVideo(
    super.source, {
    required this.mediaId,
    required this.variants,
    this.aspectRatio = 9 / 16,
    super.authorName,
    super.authorHandle,
  });
}
