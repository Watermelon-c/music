import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import 'widgets/cover_image.dart';

/// 当前播放列表：点歌切换、右侧 × 移除、右上角清空
class QueuePage extends StatelessWidget {
  const QueuePage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final List<Song> queue = app.queue;
    final Color primary = Theme.of(context).colorScheme.primary;

    return Scaffold(
      appBar: AppBar(
        title: Text('播放列表（${queue.length}）'),
        actions: <Widget>[
          IconButton(
            tooltip: '清空列表',
            icon: const Icon(Icons.delete_sweep_outlined),
            onPressed: queue.isEmpty ? null : () => _confirmClear(context, app),
          ),
        ],
      ),
      body: queue.isEmpty
          ? const Center(child: Text('播放列表是空的'))
          : ListView.separated(
              itemCount: queue.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final Song song = queue[index];
                final bool current = index == app.queueIndex;

                return ListTile(
                  selected: current,
                  leading: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CoverImage(url: song.cover, size: 42),
                      const SizedBox(width: 10),
                      Icon(
                        current ? Icons.graphic_eq : Icons.drag_handle,
                        size: 16,
                        color: current ? primary : Colors.black26,
                      ),
                    ],
                  ),
                  title: Text(
                    song.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: current ? primary : null,
                      fontWeight: current ? FontWeight.w600 : null,
                    ),
                  ),
                  subtitle: Text(
                    '${song.singer} · ${song.interval}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.close, size: 18),
                    onPressed: () => app.removeFromQueue(index),
                  ),
                  onTap: () {
                    app.playAt(index);
                    Navigator.of(context).pop();
                  },
                );
              },
            ),
    );
  }

  Future<void> _confirmClear(BuildContext context, AppState app) async {
    final bool? ok = await showDialog<bool>(
      context: context,
      builder: (BuildContext ctx) => AlertDialog(
        title: const Text('清空播放列表'),
        content: const Text('会停止当前播放并清空整个列表，确定吗？'),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok == true) {
      await app.clearQueue();
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}
