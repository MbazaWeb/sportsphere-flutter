// lib/core/data/vps_repository.dart
//
// Routes that benefit from server-side processing go through the VPS Hono API.
// Everything else (auth, realtime, direct DB reads) stays on Supabase.
//
// Architecture:
//   Flutter → Supabase directly  : auth, realtime, public reads (matches/posts)
//   Flutter → VPS API (this file): media upload, M-Pesa, FCM, feed, nearby fans,
//                                   notifications, admin, AI assistant
//
// The ApiClient reads API_BASE_URL from --dart-define (default: https://api.playify.app)
// and attaches the Supabase JWT as Authorization: Bearer <token> on every call.

import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';

import '../network/api_client.dart';
import '../network/api_exception.dart';

// ── Singleton provider ────────────────────────────────────────────────────────
// Use with Riverpod: final vpsProvider = Provider((_) => const VpsRepository());

class VpsRepository {
  const VpsRepository();

  static final _client = ApiClient();

  // ─────────────────────────────────────────────────────────────────────────
  // HEALTH
  // ─────────────────────────────────────────────────────────────────────────

  Future<bool> ping() async {
    try {
      final res = await _client.get<Map<String, dynamic>>('/health');
      return res.data?['ok'] == true;
    } catch (_) {
      return false;
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // MEDIA UPLOAD
  // Images are compressed server-side (Sharp → WebP, 3 variants).
  // Videos are stored raw; FFmpeg transcoding is a background job.
  // ─────────────────────────────────────────────────────────────────────────

  /// Upload an image from bytes. Returns {thumb, feed, full} CDN URLs.
  Future<Map<String, String>> uploadImageBytes({
    required Uint8List bytes,
    required String filename,
    required String folder,   // 'posts' | 'avatars' | 'covers'
    String mimeType = 'image/jpeg',
  }) async {
    final form = FormData.fromMap({
      'file':   MultipartFile.fromBytes(bytes, filename: filename,
                  contentType: DioMediaType.parse(mimeType)),
      'folder': folder,
    });
    final res = await _client.upload<Map<String, dynamic>>('/v1/media/image', form);
    final urls = (res.data?['urls'] as Map?)?.cast<String, String>() ?? {};
    if (urls.isEmpty) throw ApiException(message: 'Upload returned no URLs');
    return urls;
  }

  /// Upload a picked image file. Returns {thumb, feed, full} CDN URLs.
  Future<Map<String, String>> uploadPickedImage({
    required XFile file,
    required String folder,
  }) async {
    final bytes = await file.readAsBytes();
    final mime  = _mimeFor(file.name.split('.').last.toLowerCase());
    return uploadImageBytes(
      bytes: bytes, filename: file.name, folder: folder, mimeType: mime,
    );
  }

  /// Upload avatar. Returns single CDN URL.
  Future<String> uploadAvatar(XFile file) async {
    final bytes = await file.readAsBytes();
    final mime  = _mimeFor(file.name.split('.').last.toLowerCase());
    final form  = FormData.fromMap({
      'file': MultipartFile.fromBytes(bytes, filename: file.name,
                contentType: DioMediaType.parse(mime)),
    });
    final res = await _client.upload<Map<String, dynamic>>('/v1/media/avatar', form);
    final url = res.data?['url'] as String?;
    if (url == null || url.isEmpty) throw ApiException(message: 'Avatar upload failed');
    return url;
  }

  /// Upload a video. Returns {url, key}.
  Future<Map<String, String>> uploadVideo({
    required XFile file,
    required String postId,
  }) async {
    final bytes = await file.readAsBytes();
    final form  = FormData.fromMap({
      'file':   MultipartFile.fromBytes(bytes, filename: file.name,
                  contentType: DioMediaType.parse('video/mp4')),
      'postId': postId,
    });
    final res = await _client.upload<Map<String, dynamic>>('/v1/media/video', form);
    return {
      'url': res.data?['url'] as String? ?? '',
      'key': res.data?['key'] as String? ?? '',
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FEED  (scored, personalised — calls feed_for_user RPC via VPS)
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getFeed({int limit = 40}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/feed', query: {'limit': limit},
    );
    final posts = res.data?['posts'] as List? ?? [];
    return posts.cast<Map<String, dynamic>>();
  }

  Future<void> recordView(String postId) async {
    try {
      await _client.post<void>('/v1/feed/view', data: {'postId': postId});
    } catch (_) {} // best-effort
  }

  // ─────────────────────────────────────────────────────────────────────────
  // LIVE SCORES  (public — no JWT needed, but still goes through ApiClient)
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getLiveMatches() async {
    final res = await _client.get<Map<String, dynamic>>('/v1/matches/live');
    return ((res.data?['matches']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getTodayMatches() async {
    final res = await _client.get<Map<String, dynamic>>('/v1/matches/today');
    return ((res.data?['matches']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getUpcomingMatches() async {
    final res = await _client.get<Map<String, dynamic>>('/v1/matches/upcoming');
    return ((res.data?['matches']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getResults() async {
    final res = await _client.get<Map<String, dynamic>>('/v1/matches/results');
    return ((res.data?['matches']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getStandings(String league) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/matches/standings', query: {'league': league},
    );
    return ((res.data?['standings']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  // ─────────────────────────────────────────────────────────────────────────
  // M-PESA STK PUSH
  // Amount is ALWAYS read from DB on the server — never trusted from client.
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> initiateMpesa({
    required String orderId,
    required String phone,
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/mpesa/stk',
      data: {'orderId': orderId, 'phone': phone},
    );
    return res.data ?? {};
  }

  // ─────────────────────────────────────────────────────────────────────────
  // FCM PUSH NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> registerDeviceToken(String token, String platform) async {
    try {
      await _client.post<void>('/v1/fcm/register',
          data: {'token': token, 'platform': platform});
    } catch (e) {
      // Non-fatal — app works without push
    }
  }

  Future<void> removeDeviceToken(String token) async {
    try {
      await _client.post<void>('/v1/fcm/unregister', data: {'token': token});
    } catch (_) {}
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NEARBY FANS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNearbyFans({
    required double lat,
    required double lng,
    int radiusM = 50000,
    int limit   = 50,
  }) async {
    final res = await _client.get<Map<String, dynamic>>('/v1/nearby', query: {
      'lat': lat, 'lng': lng, 'radius': radiusM, 'limit': limit,
    });
    return ((res.data?['fans']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> updateLocation(double lat, double lng) async {
    await _client.post<void>('/v1/nearby/location', data: {'lat': lat, 'lng': lng});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // NOTIFICATIONS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getNotifications({int limit = 50}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/notifications', query: {'limit': limit},
    );
    return ((res.data?['notifications']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> markRead(String notificationId) async {
    await _client.patch<void>('/v1/notifications/$notificationId/read');
  }

  Future<void> markAllRead() async {
    await _client.patch<void>('/v1/notifications/read-all');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // AI ASSISTANT
  // ─────────────────────────────────────────────────────────────────────────

  Future<String> askAi({
    required String prompt,
    String mode     = 'chat',
    String provider = 'deepseek',
  }) async {
    final res = await _client.post<Map<String, dynamic>>('/v1/ai', data: {
      'prompt': prompt, 'mode': mode, 'provider': provider,
    });
    return res.data?['text'] as String? ?? '';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADMIN
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getAdminStats() async {
    final res = await _client.get<Map<String, dynamic>>('/v1/admin/stats');
    return res.data?['stats'] as Map<String, dynamic>? ?? {};
  }

  Future<void> deleteUser(String userId) async {
    await _client.delete<void>('/v1/admin/users/$userId');
  }

  Future<void> setUserRole(String userId, String role) async {
    await _client.patch<void>('/v1/admin/users/$userId/role', data: {'role': role});
  }

  Future<List<Map<String, dynamic>>> getClaims({String status = 'pending'}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/admin/claims', query: {'status': status},
    );
    return ((res.data?['claims']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> approveClaim(String claimId, {String? notes}) async {
    await _client.post<void>('/v1/claims/approve',
        data: {'claimId': claimId, 'reviewNotes': notes});
  }

  Future<void> rejectClaim(String claimId, {String? notes}) async {
    await _client.post<void>('/v1/claims/reject',
        data: {'claimId': claimId, 'reviewNotes': notes});
  }

  // ─────────────────────────────────────────────────────────────────────────
  // HELPERS
  // ─────────────────────────────────────────────────────────────────────────

  String _mimeFor(String ext) {
    switch (ext) {
      case 'jpg': case 'jpeg': return 'image/jpeg';
      case 'png':  return 'image/png';
      case 'webp': return 'image/webp';
      case 'gif':  return 'image/gif';
      case 'mp4':  return 'video/mp4';
      case 'mov':  return 'video/quicktime';
      case 'webm': return 'video/webm';
      case 'pdf':  return 'application/pdf';
      default:     return 'application/octet-stream';
    }
  }
}

  // ─────────────────────────────────────────────────────────────────────────
  // SOCIAL — POSTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getUserPosts(String userId, {int limit = 20}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/social/posts/user/$userId', query: {'limit': limit},
    );
    return ((res.data?['posts']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> createPost({
    required String content,
    String postType = 'post',
    List<String> mediaUrls = const [],
    List<String> hashtags  = const [],
    String? teamTag,
    String? sportTag,
  }) async {
    final res = await _client.post<Map<String, dynamic>>('/v1/social/posts', data: {
      'content':   content,
      'postType':  postType,
      'mediaUrls': mediaUrls,
      'hashtags':  hashtags,
      if (teamTag  != null) 'teamTag':  teamTag,
      if (sportTag != null) 'sportTag': sportTag,
    });
    return res.data?['post'] as Map<String, dynamic>? ?? {};
  }

  Future<void> deletePost(String postId) async {
    await _client.delete<void>('/v1/social/posts/$postId');
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCIAL — LIKES
  // ─────────────────────────────────────────────────────────────────────────

  Future<int> likePost(String postId) async {
    final res = await _client.post<Map<String, dynamic>>('/v1/social/posts/$postId/like');
    return res.data?['likeCount'] as int? ?? 0;
  }

  Future<int> unlikePost(String postId) async {
    final res = await _client.delete<Map<String, dynamic>>('/v1/social/posts/$postId/like');
    return res.data?['likeCount'] as int? ?? 0;
  }

  Future<bool> isPostLiked(String postId) async {
    final res = await _client.get<Map<String, dynamic>>('/v1/social/posts/$postId/liked');
    return res.data?['liked'] as bool? ?? false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCIAL — COMMENTS
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getComments(String postId, {int limit = 50}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/social/posts/$postId/comments', query: {'limit': limit},
    );
    return ((res.data?['comments']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> addComment(String postId, String content, {String? parentId}) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/social/posts/$postId/comments',
      data: {'content': content, if (parentId != null) 'parentId': parentId},
    );
    return res.data?['comment'] as Map<String, dynamic>? ?? {};
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCIAL — FOLLOW
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> followUser(String targetId) async {
    await _client.post<void>('/v1/social/follow/$targetId');
  }

  Future<void> unfollowUser(String targetId) async {
    await _client.delete<void>('/v1/social/follow/$targetId');
  }

  Future<bool> isFollowing(String targetId) async {
    final res = await _client.get<Map<String, dynamic>>('/v1/social/follow/$targetId/status');
    return res.data?['following'] as bool? ?? false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCIAL — FAN (become a fan of team/player/league)
  // ─────────────────────────────────────────────────────────────────────────

  Future<void> becomeFan(String entityType, String entityId) async {
    await _client.post<void>('/v1/social/fan/$entityType/$entityId');
  }

  Future<void> unfan(String entityType, String entityId) async {
    await _client.delete<void>('/v1/social/fan/$entityType/$entityId');
  }

  Future<bool> isFan(String entityType, String entityId) async {
    final res = await _client.get<Map<String, dynamic>>('/v1/social/fan/$entityType/$entityId/status');
    return res.data?['isFan'] as bool? ?? false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCIAL — MESSAGES (DM)
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getMessages(String withUserId, {int limit = 50}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/social/messages/$withUserId', query: {'limit': limit},
    );
    return ((res.data?['messages']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>> sendMessage(String receiverId, String content) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/social/messages',
      data: {'receiverId': receiverId, 'content': content},
    );
    return res.data?['message'] as Map<String, dynamic>? ?? {};
  }

  // ─────────────────────────────────────────────────────────────────────────
  // SOCIAL — COMMUNITIES
  // ─────────────────────────────────────────────────────────────────────────

  Future<List<Map<String, dynamic>>> getCommunities({int limit = 20}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/social/communities', query: {'limit': limit},
    );
    return ((res.data?['communities']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  Future<void> joinCommunity(String communityId) async {
    await _client.post<void>('/v1/social/communities/$communityId/join');
  }

  Future<void> leaveCommunity(String communityId) async {
    await _client.delete<void>('/v1/social/communities/$communityId/leave');
  }

  Future<bool> isCommunityMember(String communityId) async {
    final res = await _client.get<Map<String, dynamic>>('/v1/social/communities/$communityId/member');
    return res.data?['isMember'] as bool? ?? false;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // PROFILE
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> getProfile(String handleOrId) async {
    final res = await _client.get<Map<String, dynamic>>('/v1/social/profile/$handleOrId');
    return res.data?['user'] as Map<String, dynamic>? ?? {};
  }

  Future<void> updateProfile(Map<String, dynamic> fields) async {
    await _client.patch<void>('/v1/social/profile', data: fields);
  }
