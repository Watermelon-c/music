import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../models/lyric.dart';

/// 歌词视图：自动跟随当前行；拖动后松手会跳到对应时间点
class LyricView extends StatefulWidget {
  const LyricView({
    super.key,
    required this.lyric,
    required this.player,
    required this.loading,
  });

  final Lyric lyric;
  final AudioPlayer player;
  final bool loading;

  @override
  State<LyricView> createState() => _LyricViewState();
}

class _LyricViewState extends State<LyricView> {
  static const double _rowHeight = 46;

  final ScrollController _controller = ScrollController();
  bool _autoFollow = true;
  int _lastIndex = -1;
  double _viewportHeight = 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  double _offsetForIndex(int index) {
    final double raw =
        index * _rowHeight - _viewportHeight / 2 + _rowHeight / 2;
    return raw < 0 ? 0 : raw;
  }

  int _indexForOffset(double offset) {
    if (widget.lyric.isEmpty) return 0;
    final double raw = (offset + _viewportHeight / 2 - _rowHeight / 2) / _rowHeight;
    final int index = raw.round();
    return index.clamp(0, widget.lyric.lines.length - 1);
  }

  void _follow(int index) {
    if (_lastIndex == index || !_autoFollow) return;
    _lastIndex = index;
    if (!_controller.hasClients) return;
    final double target = _offsetForIndex(index);
    _controller.animateTo(
      target,
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lyric.isEmpty) {
      return Center(
        child: Text(
          widget.loading ? '歌词加载中…' : '暂无歌词',
          style: const TextStyle(color: Colors.white70),
        ),
      );
    }

    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        _viewportHeight = constraints.maxHeight;

        return StreamBuilder<Duration>(
          stream: widget.player.positionStream,
          builder: (BuildContext context, AsyncSnapshot<Duration> snapshot) {
            final Duration position = snapshot.data ?? Duration.zero;
            final int current = widget.lyric.indexAt(position);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (mounted) _follow(current);
            });

            return NotificationListener<ScrollNotification>(
              onNotification: (ScrollNotification notification) {
                if (notification is ScrollStartNotification &&
                    notification.dragDetails != null) {
                  _autoFollow = false;
                } else if (notification is ScrollEndNotification &&
                    notification.dragDetails != null) {
                  final int index = _indexForOffset(
                      notification.metrics.pixels);
                  _autoFollow = true;
                  _lastIndex = index;
                  widget.player.seek(widget.lyric.lines[index].time);
                }
                return false;
              },
              child: ListView.builder(
                controller: _controller,
                itemExtent: _rowHeight,
                physics: const BouncingScrollPhysics(),
                padding: EdgeInsets.symmetric(
                  vertical: math.max(0.0, (_viewportHeight - _rowHeight) / 2),
                ),
                itemCount: widget.lyric.lines.length,
                itemBuilder: (BuildContext context, int index) {
                  final bool active = index == current;
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _autoFollow = true;
                      widget.player.seek(widget.lyric.lines[index].time);
                    },
                    child: Center(
                      child: Text(
                        widget.lyric.lines[index].text,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: active ? 17 : 15,
                          height: 1.25,
                          color: active ? Colors.white : Colors.white60,
                          fontWeight:
                              active ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
