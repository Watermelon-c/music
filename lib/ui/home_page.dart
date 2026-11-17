import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/models.dart';
import 'rank_page.dart';
import 'song_list_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<AppState>().loadHome();
    });
  }

  @override
  Widget build(BuildContext context) {
    final AppState app = context.watch<AppState>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('椰子音乐'),
        actions: <Widget>[
          IconButton(
            tooltip: '刷新推荐',
            icon: const Icon(Icons.refresh),
            onPressed: () => app.loadHome(force: true),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () => app.loadHome(force: true),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 24),
          children: <Widget>[
            if (app.homeLoading) const LinearProgressIndicator(minHeight: 2),
            if (app.homeError != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Text(app.homeError!,
                    style: const TextStyle(color: Colors.redAccent)),
              ),
            _buildTopCards(app),
            _sectionTitle('推荐歌单'),
            _buildRankRow(app),
            _sectionTitle('每日推荐'),
            ..._buildDailyList(app),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Text(
        text,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildTopCards(AppState app) {
    return SizedBox(
      height: 168,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
        children: <Widget>[
          _DailyCard(
            count: app.daily.length,
            onTap: () => _openDaily(app),
          ),
          ...app.ranks.take(2).map((RankInfo r) => _CoverCard(
                title: r.name,
                subtitle: '点开看看',
                cover: r.cover,
                onTap: () => _openRank(r),
              )),
        ],
      ),
    );
  }

  Widget _buildRankRow(AppState app) {
    if (app.ranks.isEmpty) {
      return const Padding(
        padding: EdgeInsets.symmetric(horizontal: 16),
        child: Text('榜单加载中…', style: TextStyle(color: Colors.black45)),
      );
    }

    return SizedBox(
      height: 186,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        itemCount: app.ranks.length,
        itemBuilder: (BuildContext context, int index) {
          final RankInfo r = app.ranks[index];
          return GestureDetector(
            onTap: () => _openRank(r),
            child: Container(
              width: 116,
              margin: const EdgeInsets.only(right: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: _cover(r.cover, 116, 116),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    r.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Widget> _buildDailyList(AppState app) {
    if (app.daily.isEmpty) {
      return <Widget>[
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: Text('正在挑歌…', style: TextStyle(color: Colors.black45)),
        ),
      ];
    }

    final AppState state = app;
    final List<Widget> tiles =
        app.daily.take(10).toList().asMap().entries.map((MapEntry<int, Song> e) {
      final Song song = e.value;
      return ListTile(
        leading: SizedBox(
          width: 24,
          child: Center(
            child: Text('${e.key + 1}',
                style: const TextStyle(color: Colors.black45)),
          ),
        ),
        title: Text(song.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text('${song.singer} · ${song.interval}',
            maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: IconButton(
          icon: const Icon(Icons.play_circle_outline),
          onPressed: () =>
              state.play(song, queue: state.daily, index: e.key),
        ),
        onTap: () => state.play(song, queue: state.daily, index: e.key),
      );
    }).toList();

    tiles.add(
      ListTile(
        title: Center(
          child: Text(
            '查看全部 ${app.daily.length} 首',
            style: const TextStyle(fontSize: 13, color: Colors.black54),
          ),
        ),
        trailing: const Icon(Icons.chevron_right, size: 18),
        onTap: () => _openDaily(app),
      ),
    );

    return tiles;
  }

  Widget _cover(String url, double width, double height) {
    if (url.isEmpty) {
      return Container(
        width: width,
        height: height,
        color: const Color(0xFFE0E0E0),
        child: const Icon(Icons.queue_music, color: Colors.white),
      );
    }
    return Image.network(
      url,
      width: width,
      height: height,
      fit: BoxFit.cover,
      errorBuilder: (BuildContext context, Object error, StackTrace? stack) {
        return Container(
          width: width,
          height: height,
          color: const Color(0xFFE0E0E0),
          child: const Icon(Icons.queue_music, color: Colors.white),
        );
      },
    );
  }

  void _openRank(RankInfo rank) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => RankPage(rank: rank)),
    );
  }

  Future<void> _openDaily(AppState app) async {
    if (app.daily.isEmpty) {
      await app.loadHome(force: true);
    }
    if (!mounted || app.daily.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => SongListPage(
          title: '每日推荐',
          songs: app.daily,
          subtitle: '按今天的日期挑的 ${app.daily.length} 首，明天会换一批',
        ),
      ),
    );
  }
}

class _DailyCard extends StatelessWidget {
  const _DailyCard({required this.count, required this.onTap});

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: <Color>[Color(0xFF7B1E1E), Color(0xFF3A0B0B)],
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            const Icon(Icons.auto_awesome, color: Colors.white70),
            const Spacer(),
            const Text('每日推荐',
                style: TextStyle(color: Colors.white, fontSize: 16)),
            const SizedBox(height: 4),
            Text('共 ${count > 0 ? count : '…'} 首 · 点开歌单',
                style: const TextStyle(color: Colors.white70, fontSize: 12)),
            const SizedBox(height: 8),
            const Align(
              alignment: Alignment.centerRight,
              child: Icon(Icons.navigate_next,
                  color: Colors.white, size: 30),
            ),
          ],
        ),
      ),
    );
  }
}

class _CoverCard extends StatelessWidget {
  const _CoverCard({
    required this.title,
    required this.subtitle,
    required this.cover,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final String cover;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 150,
        margin: const EdgeInsets.only(right: 10),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: Stack(
            fit: StackFit.expand,
            children: <Widget>[
              cover.isEmpty
                  ? Container(color: const Color(0xFF9E9E9E))
                  : Image.network(
                      cover,
                      fit: BoxFit.cover,
                      errorBuilder: (BuildContext context, Object error,
                          StackTrace? stack) {
                        return Container(color: const Color(0xFF9E9E9E));
                      },
                    ),
              const DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: <Color>[Colors.transparent, Colors.black54],
                  ),
                ),
              ),
              Positioned(
                left: 12,
                right: 12,
                bottom: 12,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                            color: Colors.white, fontSize: 15)),
                    Text(subtitle,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
