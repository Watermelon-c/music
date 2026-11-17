import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../models/models.dart';

/// 播放器封装
class PlayerService extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();

  Song? current;
  String? lastError;

  PlayerService() {
    player.playerStateStream.listen((_) => notifyListeners());
    player.durationStream.listen((_) => notifyListeners());
  }

  bool get playing => player.playing;

  Duration get position => player.position;

  Duration? get duration => player.duration;

  Future<void> playUrl(
    Song song,
    String url, {
    Map<String, String>? headers,
  }) async {
    current = song;
    lastError = null;
    notifyListeners();

    await player.setAudioSource(
      AudioSource.uri(Uri.parse(url), headers: headers),
    );
    unawaited(player.play());
  }

  Future<void> toggle() async {
    if (player.playing) {
      await player.pause();
    } else {
      if (player.processingState == ProcessingState.completed) {
        await player.seek(Duration.zero);
      }
      await player.play();
    }
  }

  Future<void> seekTo(double seconds) async {
    await player.seek(Duration(milliseconds: (seconds * 1000).round()));
  }

  Future<void> stopAndClear() async {
    await player.stop();
    current = null;
    notifyListeners();
  }

  Future<void> next() async {
    if (player.hasNext) {
      await player.seekToNext();
      await player.play();
    }
  }

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }
}
