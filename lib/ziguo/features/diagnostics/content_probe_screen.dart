import 'package:flutter/services.dart';
import 'package:flutter_triple/flutter_triple.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../domain/resolved_content.dart';
import '../../domain/source_ref.dart';
import '../../domain/x_content_gateway.dart';
import 'content_probe_controller.dart';
import 'probe_playback.dart';
import 'probe_video_model.dart';

class ContentProbeScreen extends StatefulWidget {
  final XContentGateway gateway;
  final XContentInspector inspector;
  final VoidCallback? onLogin;
  const ContentProbeScreen({
    super.key,
    required this.gateway,
    required this.inspector,
    this.onLogin,
  });
  @override
  State<ContentProbeScreen> createState() => _ContentProbeScreenState();
}

class _ContentProbeScreenState extends State<ContentProbeScreen> {
  late final ContentProbeController _model;
  final _input = TextEditingController();
  @override
  void initState() {
    super.initState();
    _model = ContentProbeController(
      gateway: widget.gateway,
      inspector: widget.inspector,
    );
  }

  @override
  void dispose() {
    _model.close();
    _input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('子果 · 内容验证'),
      actions: [
        if (widget.onLogin != null)
          TextButton.icon(
            onPressed: widget.onLogin,
            icon: const Icon(Icons.login),
            label: const Text('登录 X'),
          ),
      ],
    ),
    body: ScopedBuilder<ContentProbeController, ProbeState>(
      store: _model,
      onState: (context, state) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            '从 X 直接读取',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text('短剧选视频，小说按帖序读正文，漫画按页序看图片。这里只验证读取链路，不上传作品内容。'),
          const SizedBox(height: 16),
          DropdownButton<ContentRepresentation>(
            isExpanded: true,
            value: _model.kind,
            items: const [
              DropdownMenuItem(
                value: ContentRepresentation.video,
                child: Text('短剧 · 视频'),
              ),
              DropdownMenuItem(
                value: ContentRepresentation.text,
                child: Text('小说 · 正文'),
              ),
              DropdownMenuItem(
                value: ContentRepresentation.image,
                child: Text('漫画 · 图片'),
              ),
            ],
            onChanged: state.busy
                ? null
                : (value) {
                    if (value != null) _model.selectKind(value);
                  },
          ),
          TextField(
            controller: _input,
            minLines: 2,
            maxLines: 5,
            enabled: !state.busy,
            autocorrect: false,
            enableSuggestions: false,
            decoration: const InputDecoration(
              labelText: 'X 帖子链接 / 元数据 JSON',
              hintText: 'https://x.com/作者/status/帖子ID\n多个帖子按阅读顺序逐行粘贴',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: state.busy
                    ? null
                    : () => _model.inspect(_input.text, _model.kind),
                icon: const Icon(Icons.search),
                label: const Text('解析来源'),
              ),
              OutlinedButton(
                onPressed: state.busy || state.selected.isEmpty
                    ? null
                    : _model.readSelected,
                child: const Text('读取已选内容'),
              ),
              TextButton(
                onPressed: state.selected.isEmpty
                    ? null
                    : () async {
                        await Clipboard.setData(
                          ClipboardData(text: _model.exportReferences()),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('已复制引用元数据')),
                          );
                        }
                      },
                child: const Text('复制引用'),
              ),
            ],
          ),
          if (state.busy)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: LinearProgressIndicator(),
            ),
          if (state.message != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text(
                state.message!,
                key: const ValueKey('probe-status'),
                semanticsLabel: state.message,
              ),
            ),
          if (state.error?.retryAt != null)
            Text('可重试时间：${state.error!.retryAt!.toLocal()}'),
          for (var i = 0; i < state.sources.length; i++)
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(
                '${i + 1}. ${state.sources[i].representation.name} · ${state.sources[i].postId}',
              ),
              subtitle: Text(
                state.sources[i].mediaId == null
                    ? '完整正文'
                    : '媒体 ID：${state.sources[i].mediaId}',
              ),
              value: state.selected.contains(state.sources[i].id),
              onChanged: state.busy
                  ? null
                  : (_) => _model.toggle(state.sources[i]),
            ),
          if (state.sources.isNotEmpty) const Text('视频每次选择一条；正文和图片按上方顺序读取。'),
          for (var i = 0; i < state.contents.length; i++)
            _ContentCard(
              key: ValueKey(state.contents[i].sourceRefId),
              content: state.contents[i],
              ordinal: i + 1,
              gateway: widget.gateway,
            ),
        ],
      ),
    ),
  );
}

class _ContentCard extends StatelessWidget {
  final ResolvedContent content;
  final int ordinal;
  final XContentGateway gateway;
  const _ContentCard({
    super.key,
    required this.content,
    required this.ordinal,
    required this.gateway,
  });
  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.symmetric(vertical: 12),
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '$ordinal · ${content.authorName} @${content.authorHandle}',
                ),
              ),
              TextButton(
                onPressed: () => launchUrl(
                  content.source.originalPost,
                  mode: LaunchMode.externalApplication,
                ),
                child: const Text('原帖'),
              ),
            ],
          ),
          switch (content) {
            ResolvedText(:final text) => SelectableText(
              text,
              style: const TextStyle(fontSize: 19, height: 1.8),
            ),
            ResolvedImage(:final uri) => InteractiveViewer(
              minScale: 1,
              maxScale: 4,
              child: Image.network(
                uri.toString(),
                fit: BoxFit.contain,
                semanticLabel: '第 $ordinal 页',
                errorBuilder: (_, _, _) => const Text('图片读取失败，请重新读取或打开原帖。'),
              ),
            ),
            final ResolvedVideo video => _VideoPreview(
              video: video,
              gateway: gateway,
            ),
          },
        ],
      ),
    ),
  );
}

class _VideoPreview extends StatefulWidget {
  final ResolvedVideo video;
  final XContentGateway gateway;
  const _VideoPreview({required this.video, required this.gateway});
  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  late final ProbeVideoModel _model;
  @override
  void initState() {
    super.initState();
    _model = ProbeVideoModel(
      gateway: widget.gateway,
      createPlayback: BetterPlayerProbePlayback.new,
    );
    _model.open(widget.video);
  }

  @override
  void didUpdateWidget(covariant _VideoPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video != widget.video) _model.open(widget.video);
  }

  @override
  void dispose() {
    _model.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      ScopedBuilder<ProbeVideoModel, ProbeVideoState>(
        store: _model,
        onState: (_, state) => state.error != null
            ? Text(state.error!)
            : ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 440),
                child: AspectRatio(
                  aspectRatio: widget.video.aspectRatio,
                  child:
                      state.playback?.buildView() ??
                      const Center(child: CircularProgressIndicator()),
                ),
              ),
      );
}
