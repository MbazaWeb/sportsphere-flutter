import 'package:supabase_flutter/supabase_flutter.dart';

class NewsArticle {
  final String id;
  final String title;
  final String summary;
  final String body;
  final String category;
  final String source;
  final String? sourceUrl;
  final String? imageUrl;
  final bool isBreaking;
  final DateTime publishedAt;

  const NewsArticle({
    required this.id,
    required this.title,
    required this.summary,
    required this.body,
    required this.category,
    required this.source,
    this.sourceUrl,
    this.imageUrl,
    required this.isBreaking,
    required this.publishedAt,
  });

  factory NewsArticle.fromRow(Map<String, dynamic> r) {
    return NewsArticle(
      id: r['id']?.toString() ?? '',
      title: r['title'] as String? ?? '',
      summary: r['summary'] as String? ?? r['body'] as String? ?? '',
      body: r['body'] as String? ?? '',
      category: r['category'] as String? ?? 'updates',
      source: r['source'] as String? ?? 'SportSphere',
      sourceUrl: r['source_url'] as String?,
      imageUrl: r['imageUrl'] as String?,
      isBreaking: r['is_breaking'] == true || r['category'] == 'breaking',
      publishedAt: DateTime.tryParse(r['publishedAt']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

class NewsRepository {
  SupabaseClient get _sb => Supabase.instance.client;

  Future<List<NewsArticle>> fetch({required String category}) async {
    final rows = await _sb
        .from('NewsItem')
        .select()
        .eq('status', 'published')
        .eq('category', category)
        .order('publishedAt', ascending: false)
        .limit(40);
    return [for (final r in rows as List) NewsArticle.fromRow(Map<String, dynamic>.from(r))];
  }
}
