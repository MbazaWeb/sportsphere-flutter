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
  final int likeCount;
  final int commentCount;
  final int shareCount;

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
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
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
      likeCount: (r['likeCount'] as int?) ?? 0,
      commentCount: (r['commentCount'] as int?) ?? 0,
      shareCount: (r['shareCount'] as int?) ?? 0,
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

  String? get _uid => _sb.auth.currentUser?.id;

  Future<bool> isLiked(String newsId) async {
    final uid = _uid;
    if (uid == null) return false;
    final row = await _sb.from('news_likes').select('news_id').eq('news_id', newsId).eq('user_id', uid).maybeSingle();
    return row != null;
  }

  Future<void> toggleLike(String newsId, {required bool like}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to like');
    if (like) {
      await _sb.from('news_likes').upsert({'news_id': newsId, 'user_id': uid});
    } else {
      await _sb.from('news_likes').delete().eq('news_id', newsId).eq('user_id', uid);
    }
  }

  Future<List<Map<String, dynamic>>> comments(String newsId) async {
    final rows = await _sb.from('news_comments').select().eq('news_id', newsId).order('created_at');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> addComment(String newsId, String text) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to comment');
    await _sb.from('news_comments').insert({
      'id': 'nc-${DateTime.now().millisecondsSinceEpoch}',
      'news_id': newsId,
      'user_id': uid,
      'content': text.trim(),
    });
  }

  Future<void> share(String newsId) async {
    try {
      await _sb.rpc('bump_news_share', params: {'p_id': newsId});
    } catch (_) {}
  }
}
