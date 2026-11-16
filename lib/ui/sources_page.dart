import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';

class SourcesPage extends StatefulWidget {
  const SourcesPage({super.key});

  @override
  State<SourcesPage> createState() => _SourcesPageState();
}

class _SourcesPageState extends State<SourcesPage> {
  bool _importing = false;

  Future<void> _import(String url) async {
    final AppState app = context.read<AppState>();
    setState(() => _importing = true);
    final String? error = await app.importSource(url);
    if (!mounted) return;
    setState(() => _importing = false);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(error ?? '导入成功，去「搜索」页听歌吧')),
    );
  }

  Future<void> _showImportDialog() async {
    final TextEditingController controller = TextEditingController();
    final String? url = await showDialog<String>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('从链接导入音源'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'https://.../latest.js',
            helperText: '粘贴 LX 自定义源脚本地址',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(controller.text),
            child: const Text('导入'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (url == null || url.trim().isEmpty) return;
    await _import(url);
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('音源'),
        actions: <Widget>[
          IconButton(
            tooltip: '从链接导入',
            icon: const Icon(Icons.add_link),
            onPressed: _showImportDialog,
          ),
        ],
      ),
      body: ListView(
        children: <Widget>[
          if (_importing) const LinearProgressIndicator(minHeight: 2),
          Card(
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 4),
            child: ListTile(
              leading: const Icon(Icons.graphic_eq),
              title: const Text('播放音质'),
              subtitle: const Text('解析失败时会自动降到 128k 再试一次'),
              trailing: DropdownButton<String>(
                value: app.quality,
                onChanged: (String? v) {
                  if (v != null) app.setQuality(v);
                },
                items: const <DropdownMenuItem<String>>[
                  DropdownMenuItem<String>(value: '128k', child: Text('128k')),
                  DropdownMenuItem<String>(value: '320k', child: Text('320k')),
                  DropdownMenuItem<String>(value: 'flac', child: Text('flac')),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Text('已导入的音源', style: text.titleSmall),
          ),
          if (app.sources.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('还没有音源。点下面任意一个「推荐音源」即可导入。'),
            ),
          ...app.sources.map((SourceEntry s) {
            return ListTile(
              leading: const Icon(Icons.extension),
              title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(
                '${s.platforms.isEmpty ? '未加载' : s.platforms.join(' / ')}'
                '\n${s.url}',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              isThreeLine: true,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Switch(
                    value: s.enabled,
                    onChanged: (bool v) => app.toggleSource(s, v),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => app.removeSource(s),
                  ),
                ],
              ),
            );
          }),
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Text('推荐音源（点击导入，来自 pdone/lx-music-source）',
                style: text.titleSmall),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: kPresetSources.map((PresetSource p) {
                return ActionChip(
                  label: Text(p.name),
                  avatar: const Icon(Icons.download, size: 18),
                  onPressed: _importing ? null : () => _import(p.url),
                );
              }).toList(),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 32),
            child: Text(
              '说明：音源脚本只负责把歌曲解析成播放地址，搜索走酷狗接口。'
              '脚本由第三方作者维护，随时可能失效，失效时换一个源即可。',
              style: TextStyle(fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}
