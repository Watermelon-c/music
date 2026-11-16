import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';

class PlayerPage extends StatelessWidget {
  const PlayerPage({super.key});

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();
    final Song? song = app.player.current;

    if (song == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('正在播放')),
        body: const Center(child: Text('还没有播放歌曲')),
      );
    }

    final AudioPlayer player = app.player.player;
    final bool fav = app.isFavorite(song);
    final TextTheme text = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('正在播放')),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            const Spacer(),
            Container(
              width: 220,
              height: 220,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  colors: <Color>[Color(0xFF7C4DFF), Color(0xFF03A9F4)],
                ),
              ),
              child: const Icon(Icons.music_note, size: 96, color: Colors.white70),
            ),
            const SizedBox(height: 28),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                song.name,
                style: text.headlineSmall,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                '${song.singer} · ${song.album}',
                style: text.bodyMedium,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                IconButton(
                  icon: Icon(
                    fav ? Icons.favorite : Icons.favorite_border,
                    color: fav ? Colors.redAccent : null,
                  ),
                  onPressed: () => app.toggleFavorite(song),
                ),
                Text(
                  '${app.quality} · ${song.source.toUpperCase()}',
                  style: text.bodySmall,
                ),
              ],
            ),
            if (app.player.lastError != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Text(
                  app.player.lastError!,
                  style: const TextStyle(color: Colors.redAccent),
                  textAlign: TextAlign.center,
                ),
              ),
            const Spacer(),
            _buildProgress(context, player),
            _buildControls(app, player),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _buildProgress(BuildContext context, AudioPlayer player) {
    return StreamBuilder<Duration>(
      stream: player.positionStream,
      builder: (BuildContext context, AsyncSnapshot<Duration> snapshot) {
        final Duration pos = snapshot.data ?? Duration.zero;
        final Duration total = player.duration ?? Duration.zero;
        final double max =
            total.inMilliseconds > 0 ? total.inMilliseconds.toDouble() : 1;
        final double value =
            pos.inMilliseconds.toDouble().clamp(0, max).toDouble();

        return Column(
          children: <Widget>[
            Slider(
              min: 0,
              max: max,
              value: value,
              onChanged: (double v) =>
                  player.seek(Duration(milliseconds: v.round())),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(_fmt(pos), style: Theme.of(context).textTheme.bodySmall),
                  Text(_fmt(total), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls(AppState app, AudioPlayer player) {
    return StreamBuilder<PlayerState>(
      stream: player.playerStateStream,
      builder: (BuildContext context, AsyncSnapshot<PlayerState> snapshot) {
        final bool playing = snapshot.data?.playing ?? false;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            IconButton(
              iconSize: 38,
              icon: const Icon(Icons.replay_10),
              onPressed: () {
                final Duration target =
                    player.position - const Duration(seconds: 10);
                player.seek(target.isNegative ? Duration.zero : target);
              },
            ),
            const SizedBox(width: 18),
            FilledButton(
              onPressed: () => app.player.toggle(),
              style: FilledButton.styleFrom(
                shape: const CircleBorder(),
                padding: const EdgeInsets.all(18),
              ),
              child: Icon(playing ? Icons.pause : Icons.play_arrow, size: 36),
            ),
            const SizedBox(width: 18),
            IconButton(
              iconSize: 38,
              icon: const Icon(Icons.forward_30),
              onPressed: () {
                final Duration total = player.duration ?? Duration.zero;
                final Duration target =
                    player.position + const Duration(seconds: 30);
                player.seek(target > total && !total.isNegative ? total : target);
              },
            ),
          ],
        );
      },
    );
  }

  static String _fmt(Duration d) {
    final int total = d.inSeconds;
    final String m = (total ~/ 60).toString().padLeft(2, '0');
    final String s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
