/// 歌词模型与 LRC 解析
class LyricLine {
  const LyricLine(this.time, this.text);

  final Duration time;
  final String text;
}

class Lyric {
  const Lyric(this.lines);

  final List<LyricLine> lines;

  static const Lyric empty = Lyric(<LyricLine>[]);

  bool get isEmpty => lines.isEmpty;

  /// 解析 LRC，支持一行多个时间戳、[mm:ss.xx] / [mm:ss:xx] 两种写法
  static Lyric parse(String raw) {
    final List<LyricLine> lines = <LyricLine>[];
    final RegExp re = RegExp(r'\[(\d{1,3}):(\d{1,2})(?:[.:](\d{1,3}))?\]');

    for (final String rawLine in raw.split('\n')) {
      final List<RegExpMatch> matches = re.allMatches(rawLine).toList();
      if (matches.isEmpty) continue;

      final String text = rawLine.substring(matches.last.end).trim();
      if (text.isEmpty) continue;

      for (final RegExpMatch m in matches) {
        final int minute = int.tryParse(m.group(1) ?? '') ?? 0;
        final int second = int.tryParse(m.group(2) ?? '') ?? 0;
        final String? frac = m.group(3);
        int ms = 0;
        if (frac != null && frac.isNotEmpty) {
          if (frac.length == 1) {
            ms = int.parse(frac) * 100;
          } else if (frac.length == 2) {
            ms = int.parse(frac) * 10;
          } else {
            ms = int.parse(frac.substring(0, 3));
          }
        }
        lines.add(
          LyricLine(
            Duration(minutes: minute, seconds: second, milliseconds: ms),
            text,
          ),
        );
      }
    }

    lines.sort((LyricLine a, LyricLine b) => a.time.compareTo(b.time));
    return Lyric(lines);
  }

  /// 当前播放位置对应的歌词行下标，没有则返回 -1
  int indexAt(Duration position) {
    if (lines.isEmpty) return -1;
    int low = 0;
    int high = lines.length - 1;
    int result = -1;
    while (low <= high) {
      final int mid = (low + high) >> 1;
      if (lines[mid].time <= position) {
        result = mid;
        low = mid + 1;
      } else {
        high = mid - 1;
      }
    }
    return result;
  }
}
