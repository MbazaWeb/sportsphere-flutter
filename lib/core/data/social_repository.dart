import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SocialRepository {
  SupabaseClient get _sb => Supabase.instance.client;

  String? get _uid => _sb.auth.currentUser?.id;

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

  Future<String> uploadPickedFile({
    required String bucket,
    required String folder,
    required XFile file,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to upload');
    final bytes = await file.readAsBytes();
    final ext = file.name.split('.').last.toLowerCase();
    final name = '${DateTime.now().millisecondsSinceEpoch}.$ext';
    final path = '$folder/$uid/$name';
    final mime = _mimeFor(ext);
    return uploadBytes(bucket: bucket, path: path, bytes: bytes, contentType: mime);
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
      case 'gif':
        return 'image/gif';
      case 'pdf':
        return 'application/pdf';
      default:
        return 'image/jpeg';
    }
  }

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
    if (uid == null) throw StateError('Sign in to post');
    final id = 'post-${DateTime.now().millisecondsSinceEpoch}';
    await _sb.from('Post').insert({
      'id': id,
      'userId': uid,
      'content': content,
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
    try {
      await _sb.from('posts').insert({
        'author_id': uid,
        'body': content,
        'kind': postType,
        'media_url': mediaUrls.isEmpty ? null : mediaUrls.first,
      });
    } catch (_) {}
    try {
      await _sb.rpc('notify_followers', params: {
        'p_author_id': uid,
        'p_title': 'New post',
        'p_body': content.length > 80 ? '${content.substring(0, 80)}…' : content,
        'p_reference_id': id,
      });
    } catch (_) {
      // optional fan-out
    }
    return id;
  }

  Future<void> toggleLike(String postId, {required bool like}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to like');
    if (like) {
      await _sb.from('PostLike').upsert({
        'postId': postId,
        'userId': uid,
        'createdAt': DateTime.now().toIso8601String(),
      });
      await _sb.rpc('noop').catchError((_) => null);
      await _bumpPost(postId, 'likeCount', 1);
    } else {
      await _sb.from('PostLike').delete().eq('postId', postId).eq('userId', uid);
      await _bumpPost(postId, 'likeCount', -1);
    }
  }

  Future<void> _bumpPost(String postId, String col, int delta) async {
    try {
      final row = await _sb.from('Post').select(col).eq('id', postId).maybeSingle();
      final current = (row?[col] as int?) ?? 0;
      final next = (current + delta).clamp(0, 1 << 30);
      await _sb.from('Post').update({col: next}).eq('id', postId);
    } catch (_) {}
  }

  Future<List<Map<String, dynamic>>> listComments(String postId) async {
    final rows = await _sb
        .from('Comment')
        .select()
        .eq('postId', postId)
        .order('createdAt', ascending: true)
        .limit(100);
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<void> addComment(
    String postId,
    String content, {
    List<String> mediaUrls = const [],
    String? mediaType,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in to comment');
    if (content.trim().isEmpty && mediaUrls.isEmpty) {
      throw StateError('Write something or attach a file');
    }
    final id = 'cmt-${DateTime.now().millisecondsSinceEpoch}';
    await _sb.from('Comment').insert({
      'id': id,
      'postId': postId,
      'userId': uid,
      'content': content.trim(),
      'mediaUrls': mediaUrls,
      'mediaType': mediaType,
      'likeCount': 0,
      'createdAt': DateTime.now().toIso8601String(),
    });
    await _bumpPost(postId, 'commentCount', 1);
  }

  Future<List<String>> fanTeamNames(String userId) async {
    final fanRows = await _sb.from('fans').select('target_id').eq('fan_id', userId);
    final ids = [
      for (final r in fanRows as List) (r as Map)['target_id']?.toString()
    ].whereType<String>().toList();
    if (ids.isEmpty) return [];
    final teams = await _sb
        .from('Team')
        .select('name,accountUserId')
        .inFilter('accountUserId', ids);
    return [
      for (final t in teams as List)
        '${(t as Map)['name']}'.replaceAll(RegExp(r'\s+SC$|\s+FC$'), '').trim() + ' Fan'
    ];
  }

  Future<List<Map<String, dynamic>>> listSports() async {
    final rows = await _sb.from('Sport').select('id,name,slug').eq('isActive', true).order('name');
    return List<Map<String, dynamic>>.from(rows as List);
  }

  Future<List<String>> mySportSlugs() async {
    final uid = _uid;
    if (uid == null) return [];
    final rows = await _sb.from('UserSport').select('sportId').eq('userId', uid);
    final ids = [for (final r in rows as List) (r as Map)['sportId']?.toString()].whereType<String>().toList();
    if (ids.isEmpty) return [];
    final sports = await _sb.from('Sport').select('slug').inFilter('id', ids);
    return [for (final s in sports as List) (s as Map)['slug'] as String];
  }

  Future<void> setMySports(List<String> slugs, {String? primary}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in');
    final sports = await _sb.from('Sport').select('id,slug').inFilter('slug', slugs);
    await _sb.from('UserSport').delete().eq('userId', uid);
    for (final s in sports as List) {
      final slug = (s as Map)['slug'] as String;
      await _sb.from('UserSport').insert({
        'id': 'us-$uid-$slug',
        'userId': uid,
        'sportId': s['id'],
        'is_primary': slug == (primary ?? slugs.first),
        'weight': slug == (primary ?? slugs.first) ? 3 : 1,
      });
    }
  }

  Future<List<Map<String, dynamic>>> feedForUser() async {
    final uid = _uid;
    if (uid == null) {
      final rows = await _sb.from('Post').select().order('createdAt', ascending: false).limit(40);
      return List<Map<String, dynamic>>.from(rows as List);
    }
    try {
      final rows = await _sb.rpc('feed_for_user', params: {'p_user_id': uid, 'p_limit': 40});
      return List<Map<String, dynamic>>.from(rows as List);
    } catch (_) {
      final rows = await _sb.from('Post').select().order('createdAt', ascending: false).limit(40);
      return List<Map<String, dynamic>>.from(rows as List);
    }
  }

  Future<void> updateMediaUrls({
    String? avatarUrl,
    String? coverUrl,
    String? themeColor,
  }) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in');
    final patch = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };
    if (avatarUrl != null) patch['avatar_url'] = avatarUrl;
    if (coverUrl != null) patch['cover_url'] = coverUrl;
    if (themeColor != null) patch['theme_color'] = themeColor;
    await _sb.from('profiles').update(patch).eq('id', uid);
  }
}
