import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';

class LibraryPage extends StatelessWidget {
  const LibraryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(title: Text('收藏（${app.favorites.length}）')),
      body: app.favorites.isEmpty
          ? const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text('还没有收藏，去搜索页点❤️吧', textAlign: TextAlign.center),
              ),
            )
          : ListView.separated(
              itemCount: app.favorites.length,
              separatorBuilder: (_, __) => const Divider(height: 1),
              itemBuilder: (BuildContext context, int index) {
                final Song song = app.favorites[index];
                return ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.favorite, size: 18),
                  ),
                  title: Text(
                    song.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    '${song.singer} · ${song.interval}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () => app.toggleFavorite(song),
                  ),
                  onTap: () => app.play(song),
                );
              },
            ),
    );
  }
}
