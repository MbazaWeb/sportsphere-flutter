import 'dart:typed_data';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';


import 'vps_repository.dart';
import '../taxonomy/sport_catalog.dart';

/// Social repository — all data ops route through VPS API.
/// Supabase is used ONLY for:
///   - auth.currentUser (JWT identity)
///   - storage.uploadBinary (media upload, proxied to R2 via VPS)
class SocialRepository {
  const SocialRepository();

  static final _vps = VpsRepository();

  Future<String?> _getUid() async {
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('auth_user_id');
    return token;
  }

  // ── Storage (still via Supabase Storage → will move to VPS /v1/media) ──────
  Future<String> uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    // Upload via VPS /v1/media/image → MinIO storage
    final urls = await _vps.uploadImageBytes(
      bytes: bytes,
      filename: path.split('/').last,
      folder: bucket,
      mimeType: contentType,
    );
    return urls['full'] ?? urls['feed'] ?? urls['thumb'] ?? '';
  }

  Future<String> uploadPickedFile({
    required String bucket,
    required String folder,
    required XFile file,
  }) async {
    final urls = await _vps.uploadPickedImage(file: file, folder: folder);
    return urls['full'] ?? urls['feed'] ?? urls['thumb'] ?? '';
  }

  // ── Feed ──────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> feedForUser({int limit = 50}) async {
    try {
      return await _vps.getFeed(limit: limit);
    } catch (e) {
      debugPrint('[FEED] VPS feed failed: $e');
      return [];
    }
  }

  Future<List<Map<String, dynamic>>> getTrending({int limit = 30}) async {
    try {
      return await _vps.getTrendingPosts(limit: limit);
    } catch (e) {
      debugPrint('[TRENDING] $e');
      return [];
    }
  }

  // ── Posts ─────────────────────────────────────────────────────────────────
  Future<String> createPost({
    required String content,
    String postType = 'post',
    List<String> mediaUrls = const [],
    List<String> hashtags  = const [],
    String? teamTag,
    String? sportTag,
    String? communityId,
  }) async {
    final result = await _vps.createPost(
      content:     content,
      postType:    postType,
      mediaUrls:   mediaUrls,
      hashtags:    hashtags,
      teamTag:     teamTag,
      sportTag:    sportTag,
    );
    return result['id']?.toString() ?? '';
  }

  Future<void> updatePost(String postId, Map<String, dynamic> patch) async {
    await _vps.patch<void>('/v1/social/posts/$postId', data: patch);
  }

  Future<void> deletePost(String postId) async {
    await _vps.deletePost(postId);
  }

  // ── Likes ─────────────────────────────────────────────────────────────────
  Future<void> toggleLike(String postId, {required bool like}) async {
    if (like) {
      await _vps.likePost(postId);
    } else {
      await _vps.unlikePost(postId);
    }
  }

  Future<bool> hasLiked(String postId) async {
    return _vps.isPostLiked(postId);
  }

  Future<void> incrementPostCounter(String postId, String column, int delta) async {
    try {
      await _vps.post<void>('/v1/feed/view', data: {'postId': postId});
    } catch (_) {}
  }

  Future<void> recountPostCounters(String postId) async {
    // Handled by DB triggers on VPS — no-op on client
  }

  // ── Shares ────────────────────────────────────────────────────────────────
  Future<bool> toggleShare(String postId) async {
    try {
      final shared = await _vps.isPostShared(postId);
      if (shared) {
        await _vps.delete<void>('/v1/social/posts/$postId/share');
        return false;
      } else {
        await _vps.sharePost(postId);
        return true;
      }
    } catch (e) {
      debugPrint('toggleShare: $e');
      rethrow;
    }
  }

  Future<bool> hasShared(String postId) async {
    return _vps.isPostShared(postId);
  }

  // ── Comments ──────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> listComments(String postId, {int limit = 50}) async {
    return _vps.getComments(postId, limit: limit);
  }

  Future<void> addComment(
    String postId,
    String content, {
    String? parentId,
    List<String> mentionedUserIds = const [],
    List<String> mediaUrls = const [],
    String? mediaType,
  }) async {
    await _vps.addComment(postId, content, parentId: parentId);
  }

  // ── Polls ─────────────────────────────────────────────────────────────────
  Future<String> createPollWithPost({
    required String question,
    required List<String> options,
    String? postContent,
    String? sportTag,
    String? matchId,
  }) async {
    // Create post first, then poll
    final postId = await createPost(
      content:  postContent ?? question,
      postType: 'poll',
      sportTag: sportTag,
    );
    if (postId.isEmpty) throw StateError('Post creation failed');
    await _vps.post<void>('/v1/social/polls', data: {
      'postId':   postId,
      'question': question,
      'options':  options.map((o) => {'label': o, 'votes': 0}).toList(),
      if (matchId != null) 'matchId': matchId,
    });
    return postId;
  }

  Future<void> votePoll(String pollId, int optionIdx) async {
    await _vps.post<void>('/v1/social/polls/$pollId/vote',
        data: {'optionIndex': optionIdx});
  }

  Future<Map<int, int>> pollOptionCounts(String pollId) async {
    try {
      final res = await _vps.get<Map<String, dynamic>>('/v1/social/polls/$pollId/my-vote');
      // Return counts from poll
      final poll = await _vps.get<Map<String, dynamic>>('/v1/social/polls/by-poll/$pollId');
      final opts = (poll.data?['poll']?['options'] as List? ?? []);
      final counts = <int, int>{};
      for (int i = 0; i < opts.length; i++) {
        counts[i] = (opts[i] as Map?)?['votes'] as int? ?? 0;
      }
      return counts;
    } catch (_) {
      return {};
    }
  }

  // ── Predictions ───────────────────────────────────────────────────────────
  Future<String> createPrediction({
    required String homeTeam,
    required String awayTeam,
    required int predictedHome,
    required int predictedAway,
    String? outcome,
    String? confidence,
    String? matchId,
  }) async {
    final res = await _vps.post<Map<String, dynamic>>('/v1/social/predictions', data: {
      'homeTeam':      homeTeam,
      'awayTeam':      awayTeam,
      'predictedHome': predictedHome,
      'predictedAway': predictedAway,
      if (outcome    != null) 'outcome':    outcome,
      if (confidence != null) 'confidence': confidence,
      if (matchId    != null) 'matchId':    matchId,
    });
    return res.data?['id']?.toString() ?? '';
  }

  // ── Batch profile fetch (N+1 fix) ─────────────────────────────────────────
  Future<Map<String, Map<String, dynamic>>> batchProfiles(List<String> uids) async {
    if (uids.isEmpty) return {};
    try {
      final res = await _vps.post<Map<String, dynamic>>(
        '/v1/social/profiles/batch',
        data: {'ids': uids.toSet().toList()},
      );
      final profiles = res.data?['profiles'] as Map? ?? {};
      return profiles.map((k, v) => MapEntry(k.toString(), Map<String, dynamic>.from(v as Map)));
    } catch (e) {
      debugPrint('batchProfiles: $e');
      return {};
    }
  }

  // ── Fans ──────────────────────────────────────────────────────────────────
  Future<List<String>> fanTeamNames(String userId) async {
    try {
      final res = await _vps.get<Map<String, dynamic>>(
        '/v1/social/fans/$userId/teams',
      );
      final list = res.data?['teams'] as List? ?? [];
      return list.map((e) => e.toString()).toList();
    } catch (_) {
      return [];
    }
  }

  // ── Sports ────────────────────────────────────────────────────────────────
  Future<List<Map<String, dynamic>>> listSports() async {
    try {
      final res = await _vps.get<Map<String, dynamic>>('/v1/social/sports');
      return ((res.data?['sports']) as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      return SportCatalog.all.map((s) => {'id': s.slug, 'name': s.name, 'slug': s.slug, 'icon': s.icon}).toList();
    }
  }

  Future<List<String>> mySportSlugs() async {
    final uid = _uid;
    if (uid == null) return [];
    try {
      final res = await _vps.get<Map<String, dynamic>>('/v1/social/my-sports');
      return ((res.data?['slugs']) as List? ?? []).cast<String>();
    } catch (_) {
      return [];
    }
  }

  Future<void> setMySports(List<String> slugs, {String? primary}) async {
    await _vps.post<void>('/v1/social/my-sports', data: {'slugs': slugs, 'primary': primary});
  }

  // ── Profile ───────────────────────────────────────────────────────────────
  Future<void> updateMediaUrls({String? avatarUrl, String? coverUrl, String? themeColor}) async {
    final patch = <String, dynamic>{};
    if (avatarUrl  != null) patch['avatar_url']  = avatarUrl;
    if (coverUrl   != null) patch['cover_url']   = coverUrl;
    if (themeColor != null) patch['theme_color'] = themeColor;
    if (patch.isNotEmpty) await _vps.updateProfile(patch);
  }

  // ── MIME helper ───────────────────────────────────────────────────────────
  String _mimeFor(String ext) {
    switch (ext) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'webp': return 'image/webp';
      case 'gif':  return 'image/gif';
      case 'mp4': case 'm4v': return 'video/mp4';
      case 'mov':  return 'video/quicktime';
      case 'mkv':  return 'video/x-matroska';
      case 'webm': return 'video/webm';
      case 'pdf':  return 'application/pdf';
      default:     return 'application/octet-stream';
    }
  }
}
