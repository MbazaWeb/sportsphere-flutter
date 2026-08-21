import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../taxonomy/sport_catalog.dart';

/// Social repository for posts, comments, and user interactions
class SocialRepository {
  const SocialRepository();

  SupabaseClient get _sb => Supabase.instance.client;

  String? get _uid => _sb.auth.currentUser?.id;

  // ============================================================
  // STORAGE
  // ============================================================

  /// Upload bytes to storage
  Future<String> uploadBytes({
    required String bucket,
    required String path,
    required Uint8List bytes,
    required String contentType,
  }) async {
    await _sb.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: contentType, upsert: true),
        );
    return _sb.storage.from(bucket).getPublicUrl(path);
  }

  /// Upload a picked file to storage
  Future<String> uploadPickedFile({
    required String bucket,
    required String folder,
    required XFile file,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Please sign in to upload');

    final bytes = await file.readAsBytes();
    final ext = file.name.split('.').last.toLowerCase();
    final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final path = '$folder/$uid/$name';
    final mime = _mimeFor(ext);
    return uploadBytes(
      bucket: bucket,
      path: path,
      bytes: bytes,
      contentType: mime,
    );
  }

  String _mimeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'gif':
        return 'image/gif';
      case 'mp4':
        return 'video/mp4';
      case 'mov':
        return 'video/quicktime';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'image/jpeg';
    }
  }

  // ============================================================
  // POSTS
  // ============================================================



  /// Durable poll: Post (type=poll) + Poll row.
  Future<String> createPollWithPost({
    required String question,
    required List<String> options,
    DateTime? endsAt,
  }) async {
    final opts = options.map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
    if (question.trim().isEmpty) throw StateError('Poll needs a question');
    if (opts.length < 2) throw StateError('Poll needs at least 2 options');
    final postId = await createPost(
      content: question.trim(),
      postType: 'poll',
    );
    final pollId = 'poll-${DateTime.now().millisecondsSinceEpoch}';
    await _sb.from('Poll').insert({
      'id': pollId,
      'postId': postId,
      'question': question.trim(),
      'options': opts,
      'totalVotes': 0,
      if (endsAt != null) 'endsAt': endsAt.toIso8601String(),
      'createdAt': DateTime.now().toIso8601String(),
    });
    return postId;
  }

  Future<void> votePoll(String pollId, int optionIdx) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to vote');
    await _sb.from('PollVote').upsert({
      'id': 'pv-$pollId-$uid',
      'pollId': pollId,
      'userId': uid,
      'optionIdx': optionIdx,
      'createdAt': DateTime.now().toIso8601String(),
    });
    try {
      final row = await _sb.from('Poll').select('totalVotes').eq('id', pollId).maybeSingle();
      final n = ((row?['totalVotes'] as int?) ?? 0) + 1;
      await _sb.from('Poll').update({'totalVotes': n}).eq('id', pollId);
    } catch (e) {
      debugPrint('poll vote count: $e');
    }
  }

  /// Durable prediction linked to optional match + post.
  Future<String> createPrediction({
    required String homeTeam,
    required String awayTeam,
    required int predictedHome,
    required int predictedAway,
    String? matchId,
    String? note,
    String confidence = 'medium',
  }) async {
    final content = note?.trim().isNotEmpty == true
        ? note!.trim()
        : 'Prediction: $homeTeam $predictedHome-$predictedAway $awayTeam';
    final postId = await createPost(content: content, postType: 'prediction');
    final id = 'pred-${DateTime.now().millisecondsSinceEpoch}';
    await _sb.from('Prediction').insert({
      'id': id,
      'userId': _uid,
      'matchId': matchId,
      'postId': postId,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'predictedHome': predictedHome,
      'predictedAway': predictedAway,
      'confidence': confidence,
      'createdAt': DateTime.now().toIso8601String(),
    });
    return postId;
  }

  /// Create a new post
  Future<String> createPost({
    required String content,
    List<String> mediaUrls = const [],
    String postType = 'text',
    List<String> hashtags = const [],
    String? teamTag,
    String sportTag = 'football',
    bool isBreaking = false,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Please sign in to post');

    // Validate input
    if (content.trim().isEmpty && mediaUrls.isEmpty) {
      throw StateError('Post must have content or media');
    }

    // Generate unique ID
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    final id = 'post-$timestamp-$random';

    await _sb.from('Post').insert({
      'id': id,
      'userId': uid,
      'content': content.trim(),
      'postType': postType,
      'mediaUrls': mediaUrls,
      'hashtags': hashtags,
      'sportTag': sportTag,
      if (teamTag != null) 'teamTag': teamTag,
      'isBreaking': isBreaking,
      'likeCount': 0,
      'commentCount': 0,
      'shareCount': 0,
      'createdAt': DateTime.now().toIso8601String(),
      'updatedAt': DateTime.now().toIso8601String(),
    });

    // Notify followers (non-blocking)
    try {
      await _sb.rpc('notify_followers', params: {
        'p_author_id': uid,
        'p_title': 'New post',
        'p_body': content.length > 80 ? '${content.substring(0, 80)}…' : content,
        'p_reference_id': id,
      });
    } catch (e) {
      debugPrint('Failed to notify followers: $e');
    }

    return id;
  }



  /// Admin / author: update post text and flags.
  Future<void> updatePost(
    String postId, {
    String? content,
    bool? isBreaking,
    String? postType,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Please sign in');
    final patch = <String, dynamic>{
      'updatedAt': DateTime.now().toIso8601String(),
    };
    if (content != null) patch['content'] = content.trim();
    if (isBreaking != null) patch['isBreaking'] = isBreaking;
    if (postType != null) patch['postType'] = postType;
    await _sb.from('Post').update(patch).eq('id', postId);
  }

  /// Admin / author: delete post and related likes/comments best-effort.
  Future<void> deletePost(String postId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Please sign in');
    try {
      await _sb.from('PostLike').delete().eq('postId', postId);
    } catch (_) {}
    try {
      await _sb.from('Comment').delete().eq('postId', postId);
    } catch (_) {}
    await _sb.from('Post').delete().eq('id', postId);
  }

  /// Toggle like on a post
  Future<void> toggleLike(String postId, {required bool like}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Please sign in to like');

    try {
      if (like) {
        await _sb.from('PostLike').upsert({
          'postId': postId,
          'userId': uid,
          'createdAt': DateTime.now().toIso8601String(),
        });
      } else {
        await _sb
            .from('PostLike')
            .delete()
            .eq('postId', postId)
            .eq('userId', uid);
      }
      await recountPostCounters(postId);
    } catch (e) {
      debugPrint('Failed to toggle like: $e');
      rethrow;
    }
  }

  /// Recompute like/comment/share from source tables (fixes drift).
  Future<void> recountPostCounters(String postId) async {
    try {
      final likes = await _sb
          .from('PostLike')
          .select('userId')
          .eq('postId', postId);
      final comments = await _sb
          .from('Comment')
          .select('id')
          .eq('postId', postId);
      int shares = 0;
      try {
        final sh = await _sb.from('PostShare').select('userId').eq('postId', postId);
        shares = (sh as List).length;
      } catch (e) {
        debugPrint('recount shares: $e');
      }
      await _sb.from('Post').update({
        'likeCount': (likes as List).length,
        'commentCount': (comments as List).length,
        'shareCount': shares,
      }).eq('id', postId);
    } catch (e) {
      debugPrint('recountPostCounters: $e');
    }
  }

  Future<Map<int, int>> pollOptionCounts(String pollId) async {
    try {
      final rows = await _sb.from('PollVote').select('optionIdx').eq('pollId', pollId);
      final counts = <int, int>{};
      for (final r in rows as List) {
        final i = (r as Map)['optionIdx'] as int? ?? 0;
        counts[i] = (counts[i] ?? 0) + 1;
      }
      return counts;
    } catch (e) {
      debugPrint('pollOptionCounts: $e');
      return {};
    }
  }

  // ============================================================
  // COMMENTS
  // ============================================================



  /// Unique share: one row per user per post.
  Future<bool> toggleShare(String postId) async {
    final uid = _uid;
    if (uid == null) throw StateError('Please sign in to share');
    final existing = await _sb
        .from('PostShare')
        .select()
        .eq('postId', postId)
        .eq('userId', uid)
        .maybeSingle();
    if (existing != null) {
      await _sb
          .from('PostShare')
          .delete()
          .eq('postId', postId)
          .eq('userId', uid);
      await recountPostCounters(postId);
      return false;
    }
    await _sb.from('PostShare').upsert({
      'postId': postId,
      'userId': uid,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await recountPostCounters(postId);
    return true;
  }

  Future<bool> hasShared(String postId) async {
    final uid = _uid;
    if (uid == null) return false;
    final row = await _sb
        .from('PostShare')
        .select()
        .eq('postId', postId)
        .eq('userId', uid)
        .maybeSingle();
    return row != null;
  }

  /// Get comments for a post
  Future<List<Map<String, dynamic>>> listComments(String postId) async {
    try {
      final rows = await _sb
          .from('Comment')
          .select()
          .eq('postId', postId)
          .order('createdAt', ascending: true)
          .limit(100);
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      debugPrint('Failed to list comments: $e');
      return [];
    }
  }

  /// Add a comment to a post
  Future<void> addComment(
    String postId,
    String content, {
    List<String> mediaUrls = const [],
    String? mediaType,
    String? parentId,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Please sign in to comment');

    if (content.trim().isEmpty && mediaUrls.isEmpty) {
      throw StateError('Comment must have content or media');
    }

    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final random = DateTime.now().microsecondsSinceEpoch % 10000;
    final id = 'cmt-$timestamp-$random';

    await _sb.from('Comment').insert({
      'id': id,
      'postId': postId,
      'userId': uid,
      if (parentId != null) 'parentId': parentId,
      'content': content.trim(),
      'mediaUrls': mediaUrls,
      'mediaType': mediaType,
      'likeCount': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });

    await recountPostCounters(postId);
  }

  // ============================================================
  // FANS & TEAMS
  // ============================================================

  /// Get fan team names for a user
  Future<List<String>> fanTeamNames(String userId) async {
    try {
      final fanRows = await _sb
          .from('fans')
          .select('target_id')
          .eq('fan_id', userId);
      final ids = [
        for (final r in fanRows as List)
          (r as Map)['target_id']?.toString()
      ].whereType<String>().toList();

      if (ids.isEmpty) return [];

      final teams = await _sb
          .from('Team')
          .select('name,accountUserId')
          .inFilter('accountUserId', ids);

      return [
        for (final t in teams as List)
          '${(t as Map)['name']}'
              .replaceAll(RegExp(r'\s+SC$|\s+FC$'), '')
              .trim()
      ];
    } catch (e) {
      debugPrint('Failed to get fan team names: $e');
      return [];
    }
  }

  // ============================================================
  // SPORTS
  // ============================================================

  /// List all active sports
  Future<List<Map<String, dynamic>>> listSports() async {
    try {
      final rows = await _sb
          .from('Sport')
          .select('id,name,slug')
          .eq('isActive', true)
          .order('name');
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (e) {
      debugPrint('Failed to list sports: $e');
      return [];
    }
  }

  /// Get the current user's sport slugs.
  /// Admin / official accounts always get all sports (no selection required).
  Future<List<String>> mySportSlugs() async {
    try {
      final uid = _uid;
      if (uid == null) return [];

      // Admin special case: unlock all sports, label as All Sports
      try {
        final meta = _sb.auth.currentUser?.userMetadata ?? {};
        final handle =
            '${meta['handle'] ?? ''}'.toLowerCase().replaceAll('@', '');
        final role = '${meta['role'] ?? ''}'.toLowerCase();
        final email = (_sb.auth.currentUser?.email ?? '').toLowerCase();
        final isAdmin = role == 'admin' ||
            role == 'official' ||
            handle == 'sportsphere' ||
            handle == 'sportsphere_official' ||
            handle == 'sportsphere_app' ||
            email == 'sportsphere.app@sportsphere.com';
        if (isAdmin) {
          return List<String>.from(kAllSports);
        }
      } catch (_) {}

      final rows = await _sb
          .from('UserSport')
          .select('sportId')
          .eq('userId', uid);
      final ids = [
        for (final r in rows as List)
          (r as Map)['sportId']?.toString()
      ].whereType<String>().toList();

      if (ids.isEmpty) return [];

      final sports = await _sb
          .from('Sport')
          .select('slug')
          .inFilter('id', ids);
      return [
        for (final s in sports as List)
          (s as Map)['slug'] as String
      ];
    } catch (e) {
      debugPrint('Failed to get sport slugs: $e');
      return [];
    }
  }

  /// Set the current user's sports
  Future<void> setMySports(List<String> slugs, {String? primary}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Please sign in');

    if (slugs.isEmpty) {
      throw StateError('At least one sport is required');
    }

    try {
      final sports = await _sb
          .from('Sport')
          .select('id,slug')
          .inFilter('slug', slugs);

      // Delete existing
      await _sb.from('UserSport').delete().eq('userId', uid);

      // Insert new
      for (final s in sports as List) {
        final slug = (s as Map)['slug'] as String;
        final isPrimary = slug == (primary ?? slugs.first);
        await _sb.from('UserSport').insert({
          'id': 'us-$uid-${DateTime.now().millisecondsSinceEpoch}',
          'userId': uid,
          'sportId': s['id'],
          'is_primary': isPrimary,
          'weight': isPrimary ? 3 : 1,
        });
      }
    } catch (e) {
      debugPrint('Failed to set sports: $e');
      rethrow;
    }
  }

  // ============================================================
  // FEED
  // ============================================================

  /// Get the user's feed
  Future<List<Map<String, dynamic>>> feedForUser() async {
    final uid = _uid;

    try {
      if (uid == null) {
        // Public feed for unauthenticated users
        final rows = await _sb
            .from('Post')
            .select()
            .order('createdAt', ascending: false)
            .limit(40);
        return List<Map<String, dynamic>>.from(rows as List);
      }

      // Personalized feed using RPC
      try {
        final rows = await _sb.rpc(
          'feed_for_user',
          params: {'p_user_id': uid, 'p_limit': 40},
        );
        return List<Map<String, dynamic>>.from(rows as List);
      } catch (_) {
        // Fallback to public feed
        final rows = await _sb
            .from('Post')
            .select()
            .order('createdAt', ascending: false)
            .limit(40);
        return List<Map<String, dynamic>>.from(rows as List);
      }
    } catch (e) {
      debugPrint('Failed to get feed: $e');
      return [];
    }
  }

  // ============================================================
  // PROFILE
  // ============================================================

  /// Update user media URLs
  Future<void> updateMediaUrls({
    String? avatarUrl,
    String? coverUrl,
    String? themeColor,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Please sign in');

    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (avatarUrl != null) patch['avatar_url'] = avatarUrl;
    if (coverUrl != null) patch['cover_url'] = coverUrl;
    if (themeColor != null) patch['theme_color'] = themeColor;

    try {
      await _sb.from('profiles').update(patch).eq('id', uid);
    } catch (e) {
      debugPrint('Failed to update media URLs: $e');
      rethrow;
    }
  }
}
