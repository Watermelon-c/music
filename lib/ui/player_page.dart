import 'dart:async';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import 'lyric_view.dart';

class PlayerPage extends StatefulWidget {
  const PlayerPage({super.key});

  @override
  State<PlayerPage> createState() => _PlayerPageState();
}

class _PlayerPageState extends State<PlayerPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spin;
  AudioPlayer? _player;
  StreamSubscription<PlayerState>? _sub;
  bool _showLyric = false;

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 24),
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final AudioPlayer p = context.read<AppState>().player.player;
    if (!identical(_player, p)) {
      _sub?.cancel();
      _player = p;
      _sub = p.playerStateStream.listen((PlayerState state) {
        if (state.playing) {
          if (!_spin.isAnimating) _spin.repeat();
        } else {
          _spin.stop();
        }
      });
      if (p.playing) _spin.repeat();
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _spin.dispose();
    super.dispose();
  }

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

    return Scaffold(
      body: GestureDetector(
        onVerticalDragEnd: (DragEndDetails details) {
          final double v = details.primaryVelocity ?? 0;
          if (v < -250) {
            app.nextSong();
          } else if (v > 250) {
            app.previousSong();
          }
        },
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[Color(0xFF4A3423), Color(0xFF1B120B)],
            ),
          ),
          child: SafeArea(
            child: Column(
              children: <Widget>[
                _buildTopBar(context, app, song),
                Expanded(
                  child: _showLyric
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 28),
                          child: LyricView(
                            lyric: app.lyric,
                            player: player,
                            loading: app.lyricLoading,
                            onTap: () => setState(() => _showLyric = false),
                          ),
                        )
                      : _buildCover(app, song),
                ),
                if (app.busy)
                  const Padding(
                    padding: EdgeInsets.only(bottom: 6),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                      ),
                    ),
                  ),
                _buildInfo(context, app, song),
                _buildProgress(context, player),
                _buildControls(app, song),
                const SizedBox(height: 18),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, AppState app, Song song) {
    return Row(
      children: <Widget>[
        IconButton(
          icon: const Icon(Icons.keyboard_arrow_down, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        Expanded(
          child: Column(
            children: <Widget>[
              Text(
                _showLyric ? song.name : '正在播放',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white, fontSize: 16),
              ),
              if (_showLyric)
                Text(
                  song.singer,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white60, fontSize: 12),
                ),
            ],
          ),
        ),
        IconButton(
          tooltip: _showLyric ? '看封面' : '看歌词',
          icon: Icon(
            _showLyric ? Icons.album_outlined : Icons.lyrics_outlined,
            color: Colors.white,
          ),
          onPressed: () => setState(() => _showLyric = !_showLyric),
        ),
      ],
    );
  }

  Widget _buildCover(AppState app, Song song) {
    return GestureDetector(
      onTap: () => setState(() => _showLyric = true),
      child: Center(
        child: SizedBox(
          width: 300,
          height: 300,
          child: Stack(
            alignment: Alignment.center,
            children: <Widget>[
              RotationTransition(
                turns: _spin,
                child: Container(
                  width: 290,
                  height: 290,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: <Color>[Color(0xFF2A2A2A), Color(0xFF0B0B0B)],
                    ),
                    boxShadow: <BoxShadow>[
                      BoxShadow(
                        color: Colors.black.withOpacity(0.45),
                        blurRadius: 24,
                        offset: const Offset(0, 12),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 148,
                      height: 148,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: <Color>[Color(0xFFF3E0C4), Color(0xFF8C6B47)],
                        ),
                      ),
                      child: const Icon(
                        Icons.music_note,
                        size: 64,
                        color: Colors.white70,
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                top: 2,
                right: 24,
                child: Transform.rotate(
                  angle: 0.55,
                  alignment: Alignment.topCenter,
                  child: Container(
                    width: 9,
                    height: 112,
                    decoration: BoxDecoration(
                      color: Colors.white70,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfo(BuildContext context, AppState app, Song song) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 4),
      child: Column(
        children: <Widget>[
          Text(
            song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Flexible(
                child: Text(
                  '${song.singer} · ${song.album}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${app.quality} · ${song.source.toUpperCase()}',
                  style: const TextStyle(color: Colors.white70, fontSize: 10),
                ),
              ),
            ],
          ),
        ],
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
            SliderTheme(
              data: SliderTheme.of(context).copyWith(
                trackHeight: 2,
                thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
                activeTrackColor: Colors.white,
                inactiveTrackColor: Colors.white24,
                thumbColor: Colors.white,
              ),
              child: Slider(
                min: 0,
                max: max,
                value: value,
                onChanged: (double v) =>
                    player.seek(Duration(milliseconds: v.round())),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: <Widget>[
                  Text(
                    _fmt(pos),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                  Text(
                    _fmt(total),
                    style: const TextStyle(color: Colors.white54, fontSize: 11),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildControls(AppState app, Song song) {
    final AudioPlayer player = app.player.player;
    final bool fav = app.isFavorite(song);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: <Widget>[
        IconButton(
          iconSize: 24,
          tooltip: _modeLabel(app.playMode),
          icon: Icon(_modeIcon(app.playMode), color: Colors.white70),
          onPressed: () => app.cyclePlayMode(),
        ),
        IconButton(
          iconSize: 30,
          color: Colors.white,
          icon: const Icon(Icons.skip_previous),
          onPressed: () => app.previousSong(),
        ),
        StreamBuilder<PlayerState>(
          stream: player.playerStateStream,
          builder: (BuildContext context, AsyncSnapshot<PlayerState> snapshot) {
            final bool playing = snapshot.data?.playing ?? false;
            return GestureDetector(
              onTap: () => app.player.toggle(),
              child: Container(
                width: 68,
                height: 68,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  playing ? Icons.pause : Icons.play_arrow,
                  size: 40,
                  color: const Color(0xFF1B120B),
                ),
              ),
            );
          },
        ),
        IconButton(
          iconSize: 30,
          color: Colors.white,
          icon: const Icon(Icons.skip_next),
          onPressed: () => app.nextSong(),
        ),
        IconButton(
          iconSize: 24,
          tooltip: fav ? '取消收藏' : '收藏',
          icon: Icon(
            fav ? Icons.favorite : Icons.favorite_border,
            color: fav ? Colors.redAccent : Colors.white70,
          ),
          onPressed: () => app.toggleFavorite(song),
        ),
      ],
    );
  }

  static IconData _modeIcon(PlayMode mode) {
    switch (mode) {
      case PlayMode.shuffle:
        return Icons.shuffle;
      case PlayMode.repeatOne:
        return Icons.repeat_one;
      case PlayMode.sequence:
        return Icons.repeat;
    }
  }

  static String _modeLabel(PlayMode mode) {
    switch (mode) {
      case PlayMode.shuffle:
        return '随机播放';
      case PlayMode.repeatOne:
        return '单曲循环';
      case PlayMode.sequence:
        return '顺序播放';
    }
  }

  static String _fmt(Duration d) {
    final int total = d.inSeconds;
    final String m = (total ~/ 60).toString().padLeft(2, '0');
    final String s = (total % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }
}
