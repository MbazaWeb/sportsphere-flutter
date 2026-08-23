import 'package:flutter/foundation.dart';
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

  /// Returns true if the current user has liked [newsId].
  ///
  /// Alias for [isLiked], kept for API parity with the Post engagement row
  /// (`SocialRepository.hasLiked`). Callers may use either name.
  Future<bool> hasLiked(String newsId) => isLiked(newsId);

  /// Returns the current `likeCount` stored on the `NewsItem` row.
  ///
  /// Used to refresh the local UI cache after a like toggle — the DB trigger
  /// `trg_news_like_count` maintains this counter automatically, so this just
  /// reads the fresh value back.
  Future<int> likeCount(String newsId) async {
    try {
      final row = await _sb
          .from('NewsItem')
          .select('likeCount')
          .eq('id', newsId)
          .maybeSingle();
      final v = row?['likeCount'];
      if (v is int) return v;
      if (v is num) return v.toInt();
    } catch (e) {
      debugPrint('NewsRepository.likeCount($newsId): $e');
    }
    return 0;
  }

  /// Re-fetches the `NewsItem` counters from the DB so callers can re-sync
  /// their local cache after a like/comment/share toggle.
  ///
  /// The DB triggers (`trg_news_like_count`, `trg_news_comment_count`) and
  /// the `bump_news_share` RPC maintain `likeCount` / `commentCount` /
  /// `shareCount` automatically; this call was previously a verification
  /// fetch that immediately selected the counters back and threw the result
  /// away (M17 — the result was discarded by callers anyway). The trigger
  /// commits atomically inside the same statement as the upsert/delete, so
  /// the read-back served no synchronization purpose. We now keep the
  /// method as a no-op for API parity with `SocialRepository.refreshCounts`
  /// — callers that still invoke it pay no extra round-trip.
  Future<void> refreshNewsCounts(String newsId) async {
    // Intentionally empty — see method docs. The DB trigger maintains the
    // counter atomically and callers re-read via [likeCount] when they
    // need the fresh value.
  }

  Future<void> toggleLike(String newsId, {required bool like}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to like');
    if (like) {
      await _sb.from('news_likes').upsert({'news_id': newsId, 'user_id': uid});
    } else {
      await _sb.from('news_likes').delete().eq('news_id', newsId).eq('user_id', uid);
    }
    // The DB trigger `trg_news_like_count` maintains `NewsItem.likeCount`.
    // Re-fetch the row so the local UI cache can re-sync to the fresh value.
    await refreshNewsCounts(newsId);
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

  /// Records a share on the `NewsItem` by invoking the `bump_news_share`
  /// RPC, which atomically increments `NewsItem.shareCount`.
  ///
  /// The RPC signature is `bump_news_share(p_id text) returns void` (defined
  /// in migration `20260824010000_fix_all_remaining_db_issues.sql`). Errors
  /// are logged via `debugPrint` rather than swallowed silently, but are NOT
  /// rethrown — callers (e.g. `NewsTab._share`) do not wrap this in
  /// try/catch, and rethrowing would crash the tap handler.
  Future<void> share(String newsId) async {
    try {
      await _sb.rpc('bump_news_share', params: {'p_id': newsId});
    } catch (e) {
      debugPrint('NewsRepository.share($newsId) bump_news_share RPC failed: $e');
    }
  }
}
