enum ContentRepresentation { video, text, image }

/// Persistent metadata. Content bytes, credentials and resolved URLs do not belong here.
final class SourceRef {
  final String id;
  final String postId;
  final ContentRepresentation representation;
  final String? mediaId;
  final int? mediaIndex;
  final String? publisherUserId;
  final int revision;

  const SourceRef._(
    this.id,
    this.postId,
    this.representation,
    this.mediaId,
    this.mediaIndex,
    this.publisherUserId,
    this.revision,
  );

  static final _digits = RegExp(r'^[0-9]+$');
  static final _uuid = RegExp(
    r'^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$',
  );
  static const _fields = {
    'id',
    'provider',
    'post_id',
    'representation',
    'media_id',
    'media_index',
    'publisher_user_id',
    'revision',
  };

  factory SourceRef.fromJson(Map<String, Object?> json) {
    if (json.keys.any((key) => !_fields.contains(key))) {
      throw const FormatException('SourceRef contains unsupported fields');
    }
    final id = json['id'];
    final postId = json['post_id'];
    final kind = json['representation'];
    final media = json['media_id'];
    final index = json['media_index'];
    final publisher = json['publisher_user_id'];
    final revision = json['revision'];
    if (id is! String ||
        !_uuid.hasMatch(id) ||
        json['provider'] != 'x' ||
        postId is! String ||
        !_digits.hasMatch(postId) ||
        !ContentRepresentation.values.any((e) => e.name == kind) ||
        revision is! int ||
        revision < 1 ||
        (index != null && (index is! int || index < 0)) ||
        (publisher != null &&
            (publisher is! String || !_digits.hasMatch(publisher)))) {
      throw const FormatException('Invalid X content reference');
    }
    final representation = ContentRepresentation.values.byName(kind as String);
    if (representation == ContentRepresentation.text) {
      if (media != null || index != null) {
        throw const FormatException('Text cannot select media');
      }
    } else if (media is! String || !_digits.hasMatch(media)) {
      throw const FormatException('Visual content requires a media ID');
    }
    return SourceRef._(
      id,
      postId,
      representation,
      media as String?,
      index as int?,
      publisher as String?,
      revision,
    );
  }

  Map<String, Object?> toJson() => {
    'id': id,
    'provider': 'x',
    'post_id': postId,
    'representation': representation.name,
    'revision': revision,
    if (mediaId != null) 'media_id': mediaId,
    if (mediaIndex != null) 'media_index': mediaIndex,
    if (publisherUserId != null) 'publisher_user_id': publisherUserId,
  };

  Uri get originalPost => Uri.https('x.com', '/i/status/$postId');
}
