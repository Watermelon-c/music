import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import 'widgets/cover_image.dart';

class RankPage extends StatefulWidget {
  const RankPage({super.key, required this.rank});

  final RankInfo rank;

  @override
  State<RankPage> createState() => _RankPageState();
}

class _RankPageState extends State<RankPage> {
  late Future<List<Song>> _future;

  @override
  void initState() {
    super.initState();
    _future = context.read<AppState>().kugou.rankSongs(widget.rank.id);
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: Text(widget.rank.name)),
      body: FutureBuilder<List<Song>>(
        future: _future,
        builder: (BuildContext context, AsyncSnapshot<List<Song>> snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text('加载失败：${snapshot.error}'));
          }

          final List<Song> songs = snapshot.data ?? <Song>[];
          if (songs.isEmpty) return const Center(child: Text('这个榜单暂时没有歌'));

          return ListView.separated(
            itemCount: songs.length + 1,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (BuildContext context, int index) {
              if (index == 0) {
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
                  child: Row(
                    children: <Widget>[
                      const Icon(Icons.queue_music),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          '${widget.rank.name} · 共 ${songs.length} 首',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.play_arrow),
                        label: const Text('播放全部'),
                        onPressed: () =>
                            app.play(songs.first, queue: songs, index: 0),
                      ),
                    ],
                  ),
                );
              }

              final int i = index - 1;
              final Song song = songs[i];
              return ListTile(
                leading: SizedBox(
                  width: 74,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      CoverImage(url: song.cover, size: 42),
                      const SizedBox(width: 8),
                      Text('${i + 1}',
                          style: const TextStyle(color: Colors.black45)),
                    ],
                  ),
                ),
                title: Text(song.name,
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                subtitle: Text('${song.singer} · ${song.interval}',
                    maxLines: 1, overflow: TextOverflow.ellipsis),
                trailing: IconButton(
                  icon: const Icon(Icons.play_circle_outline),
                  onPressed: () => app.play(song, queue: songs, index: i),
                ),
                onTap: () => app.play(song, queue: songs, index: i),
              );
            },
          );
        },
      ),
    );
  }
}
