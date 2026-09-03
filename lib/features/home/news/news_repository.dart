import 'package:flutter/foundation.dart';
import '../../../core/data/vps_repository.dart';

class NewsArticle {

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

  factory NewsArticle.fromRow(Map<String, dynamic> r) => NewsArticle(
        id:           r['id']?.toString() ?? '',
        title:        r['title'] as String? ?? '',
        summary:      r['summary'] as String? ?? r['body'] as String? ?? '',
        body:         r['body'] as String? ?? '',
        category:     r['category'] as String? ?? 'updates',
        source:       r['source'] as String? ?? 'Playify',
        sourceUrl:    r['source_url'] as String? ?? r['sourceUrl'] as String?,
        imageUrl:     r['imageUrl'] as String? ?? r['image_url'] as String?,
        isBreaking:   r['is_breaking'] == true || r['category'] == 'breaking',
        publishedAt:  DateTime.tryParse(r['publishedAt']?.toString() ?? r['published_at']?.toString() ?? '') ?? DateTime.now(),
        likeCount:    (r['likeCount'] as int?) ?? 0,
        commentCount: (r['commentCount'] as int?) ?? 0,
        shareCount:   (r['shareCount'] as int?) ?? 0,
      );
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
}

class NewsRepository {
  static const _vps = VpsRepository();

  Future<List<NewsArticle>> fetch({required String category}) async {
    try {
      final res = await _vps.get<Map<String, dynamic>>(
        '/v1/news',
        query: {'category': category, 'status': 'published', 'limit': 40},
      );
      final rows = (res.data?['news'] as List? ?? []).cast<Map<String, dynamic>>();
      return rows.map(NewsArticle.fromRow).toList();
    } catch (e) {
      debugPrint('[NEWS] fetch failed: $e');
      return const [];
    }
  }

  Future<bool> isLiked(String newsId) async {
    try {
      final res = await _vps.get<Map<String, dynamic>>('/v1/news/$newsId/liked');
      return res.data?['liked'] as bool? ?? false;
    } catch (_) { return false; }
  }

  Future<bool> hasLiked(String newsId) => isLiked(newsId);

  Future<int> likeCount(String newsId) async {
    try {
      final res = await _vps.get<Map<String, dynamic>>('/v1/news/$newsId');
      return res.data?['news']?['likeCount'] as int? ?? 0;
    } catch (_) { return 0; }
  }

  Future<void> refreshNewsCounts(String newsId) async {}  // DB triggers handle it

  Future<void> toggleLike(String newsId, {required bool like}) async {
    if (like) {
      await _vps.post<void>('/v1/news/$newsId/like');
    } else {
      await _vps.delete<void>('/v1/news/$newsId/like');
    }
  }

  Future<List<Map<String, dynamic>>> comments(String newsId) async {
    try {
      final res = await _vps.get<Map<String, dynamic>>('/v1/news/$newsId/comments');
      return (res.data?['comments'] as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) { return []; }
  }

  Future<void> addComment(String newsId, String text) async {
    await _vps.post<void>('/v1/news/$newsId/comments',
        data: {'content': text.trim()});
  }

  Future<void> share(String newsId) async {
    try {
      await _vps.post<void>('/v1/news/$newsId/share');
    } catch (e) {
      debugPrint('NewsRepository.share: $e');
    }
  }
}
