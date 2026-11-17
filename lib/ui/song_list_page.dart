import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';

/// 通用歌单页：每日推荐、榜单、收藏都可以复用
class SongListPage extends StatelessWidget {
  const SongListPage({
    super.key,
    required this.title,
    required this.songs,
    this.subtitle,
    this.cover,
  });

  final String title;
  final List<Song> songs;
  final String? subtitle;
  final String? cover;

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();

    if (songs.isEmpty) {
      return Scaffold(
        appBar: AppBar(title: Text(title)),
        body: const Center(child: Text('这个歌单还没有歌，下拉首页刷新试试')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView.separated(
        itemCount: songs.length + 1,
        separatorBuilder: (_, __) => const Divider(height: 1),
        itemBuilder: (BuildContext context, int index) {
          if (index == 0) return _buildHeader(context, app);

          final int i = index - 1;
          final Song song = songs[i];
          final bool fav = app.isFavorite(song);

          return ListTile(
            leading: SizedBox(
              width: 26,
              child: Center(
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(color: Colors.black45),
                ),
              ),
            ),
            title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
            subtitle: Text(
              song.album.isEmpty
                  ? '${song.singer} · ${song.interval}'
                  : '${song.singer} · ${song.album}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: Icon(
              fav ? Icons.favorite : Icons.play_circle_outline,
              color: fav ? Colors.redAccent : null,
            ),
            onTap: () => app.play(song, queue: songs, index: i),
          );
        },
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AppState app) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      child: Row(
        children: <Widget>[
          ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: (cover == null || cover!.isEmpty)
                ? Container(
                    width: 96,
                    height: 96,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: <Color>[Color(0xFF7B1E1E), Color(0xFF3A0B0B)],
                      ),
                    ),
                    child: const Icon(Icons.auto_awesome,
                        color: Colors.white70, size: 36),
                  )
                : Image.network(
                    cover!,
                    width: 96,
                    height: 96,
                    fit: BoxFit.cover,
                    errorBuilder: (BuildContext context, Object error,
                        StackTrace? stack) {
                      return Container(
                        width: 96,
                        height: 96,
                        color: const Color(0xFFE0E0E0),
                      );
                    },
                  ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      fontSize: 18, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle ?? '共 ${songs.length} 首',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 12, color: Colors.black54),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 32,
                  child: FilledButton.icon(
                    onPressed: () =>
                        app.play(songs.first, queue: songs, index: 0),
                    icon: const Icon(Icons.play_arrow, size: 18),
                    label: const Text('播放全部'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
