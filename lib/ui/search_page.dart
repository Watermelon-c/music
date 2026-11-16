import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import 'player_page.dart';

class SearchPage extends StatefulWidget {
  const SearchPage({super.key});

  @override
  State<SearchPage> createState() => _SearchPageState();
}

class _SearchPageState extends State<SearchPage> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit(AppState app) {
    FocusScope.of(context).unfocus();
    app.search(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('搜索'),
        actions: <Widget>[
          IconButton(
            tooltip: '正在播放',
            icon: const Icon(Icons.play_circle_outline),
            onPressed: () {
              if (app.player.current == null) {
                _toast(context, '还没有播放歌曲');
                return;
              }
              Navigator.of(context).push(
                MaterialPageRoute<void>(builder: (_) => const PlayerPage()),
              );
            },
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: TextField(
              controller: _controller,
              textInputAction: TextInputAction.search,
              onSubmitted: (_) => _submit(app),
              decoration: InputDecoration(
                hintText: '搜歌名 / 歌手，例如：晴天 周杰伦',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward),
                  onPressed: () => _submit(app),
                ),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          if (app.notice != null)
            MaterialBanner(
              content: Text(app.notice!),
              leading: const Icon(Icons.info_outline),
              actions: <Widget>[
                TextButton(
                  onPressed: app.clearNotice,
                  child: const Text('知道了'),
                ),
              ],
            ),
          if (app.searching) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: _buildBody(app)),
        ],
      ),
    );
  }

  Widget _buildBody(AppState app) {
    if (app.results.isEmpty) {
      if (app.searchError != null) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(app.searchError!, textAlign: TextAlign.center),
          ),
        );
      }
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            '输入歌名或歌手开始搜索\n\n'
            '播放需要先在「音源」页导入至少一个自定义音源',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return ListView.separated(
      itemCount: app.results.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (BuildContext context, int index) {
        final Song song = app.results[index];
        final bool fav = app.isFavorite(song);
        return ListTile(
          leading: const CircleAvatar(child: Icon(Icons.music_note, size: 18)),
          title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            '${song.singer} · ${song.album} · ${song.interval}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              IconButton(
                icon: Icon(
                  fav ? Icons.favorite : Icons.favorite_border,
                  color: fav ? Colors.redAccent : null,
                ),
                onPressed: () => app.toggleFavorite(song),
              ),
              IconButton(
                icon: const Icon(Icons.play_circle_fill),
                onPressed: () => app.play(song),
              ),
            ],
          ),
          onTap: () => app.play(song),
        );
      },
    );
  }
}

void _toast(BuildContext context, String text) {
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
}
