import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/colors.dart';
import 'news_repository.dart';

class NewsTab extends StatefulWidget {
  const NewsTab({super.key});

  @override
  State<NewsTab> createState() => _NewsTabState();
}

class _NewsTabState extends State<NewsTab> with SingleTickerProviderStateMixin {
  late final TabController _tabs;
  final _repo = NewsRepository();

  @override
  void initState() {
    super.initState();
    _tabs = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabs.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
          decoration: BoxDecoration(
            color: const Color(0xFF0B1626),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: TabBar(
            controller: _tabs,
            indicatorSize: TabBarIndicatorSize.tab,
            indicator: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: const Color(0xFF168CFF).withValues(alpha: 0.2),
              border: Border.all(color: const Color(0xFF168CFF).withValues(alpha: 0.45)),
            ),
            labelColor: Colors.white,
            unselectedLabelColor: SportSphereColors.muted,
            labelStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
            tabs: const [
              Tab(text: 'News Updates'),
              Tab(text: 'Rumors'),
              Tab(text: 'Breaking'),
            ],
          ),
        ),
        Expanded(
          child: TabBarView(
            controller: _tabs,
            children: [
              _NewsList(repo: _repo, category: 'updates', emptyLabel: 'No news updates yet'),
              _NewsList(repo: _repo, category: 'rumors', emptyLabel: 'No rumors right now'),
              _NewsList(repo: _repo, category: 'breaking', emptyLabel: 'No breaking stories'),
            ],
          ),
        ),
      ],
    );
  }
}

class _NewsList extends StatefulWidget {
  final NewsRepository repo;
  final String category;
  final String emptyLabel;
  const _NewsList({required this.repo, required this.category, required this.emptyLabel});

  @override
  State<_NewsList> createState() => _NewsListState();
}

class _NewsListState extends State<_NewsList> {
  late Future<List<NewsArticle>> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.repo.fetch(category: widget.category);
  }

  Future<void> _refresh() async {
    setState(() => _future = widget.repo.fetch(category: widget.category));
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<NewsArticle>>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final items = snap.data ?? const <NewsArticle>[];
        if (items.isEmpty) {
          return Center(
            child: Text(widget.emptyLabel, style: const TextStyle(color: Colors.white54)),
          );
        }
        return RefreshIndicator(
          onRefresh: _refresh,
          color: const Color(0xFF168CFF),
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
            itemCount: items.length,
            separatorBuilder: (_, __) => const SizedBox(height: 10),
            itemBuilder: (_, i) => _NewsCard(article: items[i]),
          ),
        );
      },
    );
  }
}

class _NewsCard extends StatelessWidget {
  final NewsArticle article;
  const _NewsCard({required this.article});

  @override
  Widget build(BuildContext context) {
    final time = DateFormat('MMM d · HH:mm').format(article.publishedAt.toLocal());
    return Material(
      color: const Color(0xFF0B1626),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _open(context),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: article.isBreaking
                  ? const Color(0xFFE31B23).withValues(alpha: 0.45)
                  : Colors.white.withValues(alpha: 0.06),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (article.isBreaking)
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE31B23),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('BREAKING', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w900)),
                    ),
                  if (article.category == 'rumors')
                    Container(
                      margin: const EdgeInsets.only(right: 8),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF8A00).withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('RUMOR', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w800, color: Color(0xFFFF8A00))),
                    ),
                  Expanded(
                    child: Text(
                      '${article.source} · $time',
                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(article.title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15, height: 1.25)),
              const SizedBox(height: 6),
              Text(
                article.summary,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _open(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF071422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.fromLTRB(16, 16, 16, MediaQuery.viewInsetsOf(ctx).bottom + 24),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(article.title, style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 18)),
                const SizedBox(height: 8),
                Text('${article.source} · auto feed', style: const TextStyle(color: Colors.white38, fontSize: 12)),
                const SizedBox(height: 14),
                Text(article.body, style: const TextStyle(fontSize: 14, height: 1.45)),
                if (article.sourceUrl != null) ...[
                  const SizedBox(height: 16),
                  TextButton.icon(
                    onPressed: () => launchUrl(Uri.parse(article.sourceUrl!), mode: LaunchMode.externalApplication),
                    icon: const Icon(Icons.open_in_new, size: 16),
                    label: const Text('Open source'),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}
