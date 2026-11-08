import 'dart:convert';

import 'package:flutter_triple/flutter_triple.dart';

import '../../domain/content_access_exception.dart';
import '../../domain/ordered_content_loader.dart';
import '../../domain/resolved_content.dart';
import '../../domain/source_ref.dart';
import '../../domain/x_content_gateway.dart';

List<String> parsePostIds(String input) {
  final entries = input
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  if (entries.isEmpty || entries.length > 10) {
    throw const FormatException('请输入 1 至 10 条 X 链接，每行一条。');
  }
  final result = <String>[];
  for (final value in entries) {
    if (RegExp(r'^[0-9]+$').hasMatch(value)) {
      result.add(value);
      continue;
    }
    final uri = Uri.tryParse(value);
    final match = uri == null
        ? null
        : RegExp(
            r'^/(?:[A-Za-z0-9_]+/status|i/web/status)/([0-9]+)(?:/(?:photo|video)/[0-9]+)?/?$',
          ).firstMatch(uri.path);
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.userInfo.isNotEmpty ||
        uri.hasPort ||
        ![
          'x.com',
          'www.x.com',
          'twitter.com',
          'www.twitter.com',
        ].contains(uri.host.toLowerCase()) ||
        match == null) {
      throw const FormatException('请输入有效的 X 帖子链接或数字帖子 ID。');
    }
    result.add(match.group(1)!);
  }
  return result.toSet().toList();
}

class ProbeState {
  final bool busy;
  final List<SourceRef> sources;
  final Set<String> selected;
  final List<ResolvedContent> contents;
  final String? message;
  final ContentAccessException? error;
  const ProbeState({
    this.busy = false,
    this.sources = const [],
    this.selected = const {},
    this.contents = const [],
    this.message,
    this.error,
  });
}

class ContentProbeController extends Store<ProbeState> {
  final XContentGateway gateway;
  final XContentInspector inspector;
  int _operation = 0;
  bool _closed = false;
  ContentRepresentation kind = ContentRepresentation.video;
  ContentProbeController({required this.gateway, required this.inspector})
    : super(const ProbeState());

  void selectKind(ContentRepresentation value) {
    kind = value;
    _operation++;
    // The selected kind changes even when the empty state is identical.
    update(const ProbeState(), force: true);
  }

  Future<void> inspect(String input, ContentRepresentation kind) async {
    this.kind = kind;
    final operation = ++_operation;
    update(const ProbeState(busy: true));
    try {
      final sources = <SourceRef>[];
      if (input.trimLeft().startsWith('[') ||
          input.trimLeft().startsWith('{')) {
        final decoded = jsonDecode(input);
        final list = decoded is List ? decoded : [decoded];
        if (list.isEmpty || list.length > 100) {
          throw const FormatException('引用数量应为 1 至 100。');
        }
        for (final entry in list) {
          if (entry is! Map<String, dynamic>) {
            throw const FormatException('引用必须为 JSON 对象。');
          }
          sources.add(SourceRef.fromJson(entry));
        }
      } else {
        for (final id in parsePostIds(input)) {
          sources.addAll(await inspector.inspectPost(id));
        }
      }
      if (_closed || operation != _operation) return;
      final matching = sources
          .where((source) => source.representation == kind)
          .toList();
      final unique = <String, SourceRef>{
        for (final ref in matching) ref.id: ref,
      }.values.toList();
      update(
        ProbeState(
          sources: unique,
          message: unique.isEmpty
              ? '没有找到这种完整内容。长帖与 Article 尚未启用。'
              : '请选择内容，再开始读取。',
        ),
      );
    } on ContentAccessException catch (error) {
      if (!_closed && operation == _operation) {
        update(ProbeState(message: error.message, error: error));
      }
    } on FormatException {
      if (!_closed && operation == _operation) {
        update(const ProbeState(message: '输入格式无效，请检查 X 链接或元数据 JSON。'));
      }
    } catch (_) {
      if (!_closed && operation == _operation) {
        update(const ProbeState(message: '无法解析来源，请检查输入后重试。'));
      }
    }
  }

  void toggle(SourceRef source) {
    if (state.busy || _closed) return;
    final selected = source.representation == ContentRepresentation.video
        ? <String>{}
        : {...state.selected};
    if (state.selected.contains(source.id)) {
      selected.remove(source.id);
    } else {
      selected.add(source.id);
    }
    update(ProbeState(sources: state.sources, selected: selected));
  }

  Future<void> readSelected() async {
    if (state.busy || _closed) return;
    final refs = state.sources
        .where((e) => state.selected.contains(e.id))
        .toList();
    if (refs.isEmpty) return;
    final operation = ++_operation;
    final previous = state;
    update(
      ProbeState(
        busy: true,
        sources: previous.sources,
        selected: previous.selected,
      ),
    );
    try {
      final content = await loadOrderedContent(refs, gateway);
      if (!_closed && operation == _operation) {
        update(
          ProbeState(
            sources: previous.sources,
            selected: previous.selected,
            contents: content,
            message: '已从 X 读取 ${content.length} 项内容。',
          ),
        );
      }
    } on ContentAccessException catch (error) {
      if (!_closed && operation == _operation) {
        update(
          ProbeState(
            sources: previous.sources,
            selected: previous.selected,
            message: error.message,
            error: error,
          ),
        );
      }
    } catch (_) {
      if (!_closed && operation == _operation) {
        update(
          ProbeState(
            sources: previous.sources,
            selected: previous.selected,
            message: '读取失败，没有显示不完整的章节。',
          ),
        );
      }
    }
  }

  String exportReferences() => const JsonEncoder.withIndent('  ').convert(
    state.sources
        .where((e) => state.selected.contains(e.id))
        .map((e) => e.toJson())
        .toList(),
  );

  void close() {
    _closed = true;
    _operation++;
    destroy();
  }
}
