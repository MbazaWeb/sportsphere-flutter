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

  /// Upload avatar from raw bytes (used during registration before session exists).
  Future<String> uploadAvatarBytes(Uint8List bytes, {String ext = 'jpg'}) async {
    final form = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        bytes,
        filename: 'avatar.$ext',
        contentType: DioMediaType.parse(ext == 'png' ? 'image/png' : 'image/jpeg'),
      ),
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
  // ─────────────────────────────────────────────────────────────────────────
  // AUTH — VPS native (no Supabase dependency)
  // ─────────────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    String? firstName,
    String? lastName,
    String? handle,
    String? country,
    String? dob,
    String? role,
  }) async {
    final res = await _client.post<Map<String, dynamic>>('/v1/auth/register', data: {
      'email':     email.trim().toLowerCase(),
      'password':  password,
      if (firstName != null) 'firstName': firstName,
      if (lastName  != null) 'lastName':  lastName,
      if (handle    != null) 'handle':    handle,
      if (country   != null) 'country':   country,
      if (dob       != null) 'dob':       dob,
      if (role      != null) 'role':      role,
    });
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> login({
    String? email,
    String? handle,
    required String password,
  }) async {
    final res = await _client.post<Map<String, dynamic>>('/v1/auth/login', data: {
      'password': password,
      if (email  != null) 'email':  email.trim().toLowerCase(),
      if (handle != null) 'handle': handle,
    });
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> refreshToken(String refreshToken) async {
    final res = await _client.post<Map<String, dynamic>>('/v1/auth/refresh',
        data: {'refreshToken': refreshToken});
    return res.data ?? {};
  }

  Future<Map<String, dynamic>> getMe() async {
    final res = await _client.get<Map<String, dynamic>>('/v1/auth/me');
    return res.data?['user'] as Map<String, dynamic>? ?? {};
  }

  Future<void> logout() async {
    try { await _client.post<void>('/v1/auth/logout'); } catch (_) {}
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _client.post<void>('/v1/auth/change-password', data: {
      'currentPassword': currentPassword,
      'newPassword':     newPassword,
    });
  }

  Future<void> forgotPassword(String email) async {
    await _client.post<void>('/v1/auth/forgot-password',
        data: {'email': email.trim().toLowerCase()});
  }

  // ── Additional social methods ─────────────────────────────────────────────

  Future<int> sharePost(String postId) async {
    final res = await _client.post<Map<String, dynamic>>('/v1/social/posts/$postId/share');
    return res.data?['shareCount'] as int? ?? 0;
  }

  Future<bool> isPostShared(String postId) async {
    final res = await _client.get<Map<String, dynamic>>('/v1/social/posts/$postId/shared');
    return res.data?['shared'] as bool? ?? false;
  }

  Future<List<Map<String, dynamic>>> getTrendingPosts({int limit = 30}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/feed/trending', query: {'limit': limit},
    );
    return ((res.data?['posts']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  // Expose raw get/post/delete for social_repository
  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) =>
      _client.get<T>(path, query: query);
  Future<Response<T>> post<T>(String path, {dynamic data}) =>
      _client.post<T>(path, data: data);
  Future<Response<T>> delete<T>(String path) =>
      _client.delete<T>(path);
  Future<Response<T>> patch<T>(String path, {dynamic data}) =>
      _client.patch<T>(path, data: data);

  // ── Search ───────────────────────────────────────────────────────────────

  /// Search users, teams, leagues, players in one call.
  Future<List<Map<String, dynamic>>> searchAll(String q, {int limit = 50}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/social/search', query: {'q': q, 'limit': limit},
    );
    return ((res.data?['results']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  // ── Match lookups (the 4 missing routes) ──────────────────────────────────

  /// GET /v1/matches/leagues — distinct league names
  Future<List<String>> getLeagues() async {
    final res = await _client.get<Map<String, dynamic>>('/v1/matches/leagues');
    return ((res.data?['leagues']) as List? ?? []).cast<String>();
  }

  /// GET /v1/matches/all — fallback fetch all matches
  Future<List<Map<String, dynamic>>> getAllMatches({int limit = 200}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/matches/all', query: {'limit': limit},
    );
    return ((res.data?['matches']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// GET /v1/admin/teams — team list for dropdowns
  Future<List<Map<String, dynamic>>> getAdminTeams({int limit = 200}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/admin/teams', query: {'limit': limit},
    );
    return ((res.data?['teams']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// POST /v1/shop/orders — create order
  Future<Map<String, dynamic>> createOrder({
    required String itemId,
    required String itemName,
    required String kind,
    required int unitPriceTzs,
    int quantity = 1,
    String? sellerHandle,
    String? sellerName,
    String paymentMethod = 'mpesa',
  }) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/shop/orders',
      data: {
        'itemId': itemId,
        'itemName': itemName,
        'kind': kind,
        'unitPriceTzs': unitPriceTzs,
        'quantity': quantity,
        'sellerHandle': sellerHandle,
        'sellerName': sellerName,
        'paymentMethod': paymentMethod,
      },
    );
    return (res.data?['order'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  // ── Profile lookups (single entity by id or slug) ──────────────────────────

  /// GET /v1/social/profiles/:idOrSlug — batch-safe single profile lookup
  Future<Map<String, dynamic>?> getProfile(String idOrSlug) async {
    try {
      final res = await _client.get<Map<String, dynamic>>(
        '/v1/social/profiles/$idOrSlug',
      );
      return res.data?['profile'] as Map<String, dynamic>?;
    } catch (_) {
      return null;
    }
  }

  /// POST /v1/social/profiles-batch — fetch multiple profiles by IDs
  Future<List<Map<String, dynamic>>> getProfilesBatch(List<String> ids) async {
    if (ids.isEmpty) return [];
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/social/profiles-batch',
      data: {'ids': ids},
    );
    return ((res.data?['profiles']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  // ── Social: posts, likes, comments, follows, fans ──────────────────────────

  /// GET /v1/social/posts/user/:userId — user's posts
  Future<List<Map<String, dynamic>>> getUserPosts(String userId, {int limit = 50}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/social/posts/user/$userId', query: {'limit': limit},
    );
    return ((res.data?['posts']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// POST /v1/social/posts — create a post
  Future<Map<String, dynamic>> createPost(Map<String, dynamic> body) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/social/posts', data: body,
    );
    return (res.data?['post'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// DELETE /v1/social/posts/:id — delete a post
  Future<void> deletePost(String postId) async {
    await _client.delete('/v1/social/posts/$postId');
  }

  /// POST /v1/social/likes/:postId — toggle like
  Future<bool> toggleLike(String postId) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/social/likes/$postId', data: {},
    );
    return res.data?['liked'] == true;
  }

  /// GET /v1/social/likes/:postId/check — check if current user liked
  Future<bool> hasLiked(String postId) async {
    try {
      final res = await _client.get<Map<String, dynamic>>(
        '/v1/social/likes/$postId/check',
      );
      return res.data?['liked'] == true;
    } catch (_) {
      return false;
    }
  }

  /// GET /v1/social/comments/:postId — list comments
  Future<List<Map<String, dynamic>>> getComments(String postId) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/social/comments/$postId',
    );
    return ((res.data?['comments']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// POST /v1/social/comments/:postId — add comment
  Future<Map<String, dynamic>> addComment(String postId, String content) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/social/comments/$postId', data: {'content': content},
    );
    return (res.data?['comment'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// POST /v1/social/follows/:targetId — toggle follow
  Future<bool> toggleFollow(String targetId) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/social/follows/$targetId', data: {},
    );
    return res.data?['following'] == true;
  }

  /// GET /v1/social/follows/:targetId/check — check if following
  Future<bool> isFollowing(String targetId) async {
    try {
      final res = await _client.get<Map<String, dynamic>>(
        '/v1/social/follows/$targetId/check',
      );
      return res.data?['following'] == true;
    } catch (_) {
      return false;
    }
  }

  /// GET /v1/social/follows/followers/:userId — list followers
  Future<List<Map<String, dynamic>>> getFollowers(String userId) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/social/follows/followers/$userId',
    );
    return ((res.data?['followers']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// GET /v1/social/follows/following/:userId — list following
  Future<List<Map<String, dynamic>>> getFollowing(String userId) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/social/follows/following/$userId',
    );
    return ((res.data?['following']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// POST /v1/social/fans/:targetId — toggle fan
  Future<bool> toggleFan(String targetId) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/social/fans/$targetId', data: {},
    );
    return res.data?['isFan'] == true;
  }

  /// GET /v1/social/fans/:targetId/check — check if fan
  Future<bool> isFan(String targetId) async {
    try {
      final res = await _client.get<Map<String, dynamic>>(
        '/v1/social/fans/$targetId/check',
      );
      return res.data?['isFan'] == true;
    } catch (_) {
      return false;
    }
  }

  /// GET /v1/social/fans/by-teams — fans of my teams
  Future<List<Map<String, dynamic>>> getFansByTeams() async {
    final res = await _client.get<Map<String, dynamic>>('/v1/social/fans/by-teams');
    return ((res.data?['fans']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// GET /v1/social/fans/by-sports — fans of my sports
  Future<List<Map<String, dynamic>>> getFansBySports() async {
    final res = await _client.get<Map<String, dynamic>>('/v1/social/fans/by-sports');
    return ((res.data?['fans']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// GET /v1/social/fans/by-country — fans in my country
  Future<List<Map<String, dynamic>>> getFansByCountry() async {
    final res = await _client.get<Map<String, dynamic>>('/v1/social/fans/by-country');
    return ((res.data?['fans']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// GET /v1/social/my-favorites — current user's favorites
  Future<List<Map<String, dynamic>>> getMyFavorites() async {
    final res = await _client.get<Map<String, dynamic>>('/v1/social/my-favorites');
    return ((res.data?['favorites']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// GET /v1/social/my-sports — current user's sports
  Future<List<Map<String, dynamic>>> getMySports() async {
    final res = await _client.get<Map<String, dynamic>>('/v1/social/my-sports');
    return ((res.data?['sports']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  // ── Messages ──────────────────────────────────────────────────────────────

  /// GET /v1/social/messages/conversations — list conversations
  Future<List<Map<String, dynamic>>> getConversations() async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/social/messages/conversations',
    );
    return ((res.data?['conversations']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// GET /v1/social/messages/thread/:peerId — get thread with peer
  Future<List<Map<String, dynamic>>> getMessageThread(String peerId) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/social/messages/thread/$peerId',
    );
    return ((res.data?['messages']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// POST /v1/social/messages/:receiverId — send message
  Future<void> sendMessage(String receiverId, String content) async {
    await _client.post('/v1/social/messages/$receiverId', data: {'content': content});
  }

  // ── Communities ────────────────────────────────────────────────────────────

  /// POST /v1/social/communities/:id/join — join community
  Future<void> joinCommunity(String communityId) async {
    await _client.post('/v1/social/communities/$communityId/join', data: {});
  }

  /// POST /v1/social/communities/:id/leave — leave community
  Future<void> leaveCommunity(String communityId) async {
    await _client.post('/v1/social/communities/$communityId/leave', data: {});
  }

  /// GET /v1/social/communities/:id/members — list members
  Future<List<Map<String, dynamic>>> getCommunityMembers(String communityId) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/social/communities/$communityId/members',
    );
    return ((res.data?['members']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  // ── Polls & Predictions ────────────────────────────────────────────────────

  /// POST /v1/social/polls/:id/vote — vote on a poll
  Future<void> votePoll(String pollId, int optionIndex) async {
    await _client.post('/v1/social/polls/$pollId/vote', data: {'optionIndex': optionIndex});
  }

  /// POST /v1/social/predictions — create prediction
  Future<Map<String, dynamic>> createPrediction(Map<String, dynamic> body) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/social/predictions', data: body,
    );
    return (res.data?['prediction'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  // ── Shop ───────────────────────────────────────────────────────────────────

  /// GET /v1/shop/orders/mine — buyer's order history
  Future<List<Map<String, dynamic>>> getMyOrders({int limit = 50}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/shop/orders/mine', query: {'limit': limit},
    );
    return ((res.data?['orders']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// GET /v1/shop/orders/seller — seller's received orders
  Future<List<Map<String, dynamic>>> getSellerOrders({int limit = 50}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/shop/orders/seller', query: {'limit': limit},
    );
    return ((res.data?['orders']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// PATCH /v1/shop/orders/:id/confirm — mark order paid
  Future<void> confirmOrderPaid(String orderId, {String? providerRef}) async {
    await _client.patch(
      '/v1/shop/orders/$orderId/confirm',
      data: {'providerRef': providerRef},
    );
  }

  /// GET /v1/shop/tickets/:sellerHandle/stats — seller ticket stats
  Future<Map<String, int>> getSellerTicketStats(String sellerHandle) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/shop/tickets/$sellerHandle/stats',
    );
    return {
      'sold': (res.data?['sold'] as int?) ?? 0,
      'amountTzs': (res.data?['amountTzs'] as int?) ?? 0,
    };
  }

  // ── Aliases for backward compatibility with old method names ───────────────

  /// Alias for toggleLike — old callers used likePost/unlikePost
  Future<void> likePost(String postId) => toggleLike(postId);
  Future<void> unlikePost(String postId) => toggleLike(postId);
  Future<bool> isPostLiked(String postId) => hasLiked(postId);

  /// Alias for toggleFollow — old callers used followUser/unfollowUser
  Future<bool> followUser(String targetId) => toggleFollow(targetId);
  Future<bool> unfollowUser(String targetId) => toggleFollow(targetId);

  /// Update profile — delegates to auth profile update
  Future<void> updateProfile({
    required String userId,
    String? firstName,
    String? lastName,
    String? handle,
    String? country,
    String? bio,
    DateTime? dateOfBirth,
    String? avatarUrl,
    String? coverUrl,
    String? themeColor,
  }) async {
    final patch = <String, dynamic>{};
    if (firstName != null) patch['first_name'] = firstName;
    if (lastName != null) patch['last_name'] = lastName;
    if (handle != null) patch['handle'] = handle;
    if (country != null) patch['country'] = country;
    if (bio != null) patch['bio'] = bio;
    if (dateOfBirth != null) patch['date_of_birth'] = dateOfBirth.toIso8601String();
    if (avatarUrl != null) patch['avatar_url'] = avatarUrl;
    if (coverUrl != null) patch['cover_url'] = coverUrl;
    if (themeColor != null) patch['theme_color'] = themeColor;
    if (patch.isEmpty) return;
    await _client.patch('/v1/auth/profile', data: patch);
  }

  /// Update news post (for news tab)
  Future<Map<String, dynamic>> updatePost(String postId, Map<String, dynamic> body) async {
    final res = await _client.patch<Map<String, dynamic>>(
      '/v1/news/$postId', data: body,
    );
    return (res.data?['news'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Get communities list
  Future<List<Map<String, dynamic>>> getCommunities({int limit = 50}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/social/communities', query: {'limit': limit},
    );
    return ((res.data?['communities']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// Check if current user is a member of a community
  Future<bool> isCommunityMember(String communityId) async {
    try {
      final res = await _client.get<Map<String, dynamic>>(
        '/v1/social/communities/$communityId/membership',
      );
      return res.data?['isMember'] == true;
    } catch (_) {
      return false;
    }
  }

  /// Create a news post (for admin/news)
  Future<Map<String, dynamic>> createNewsPost(Map<String, dynamic> body) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/news', data: body,
    );
    return (res.data?['news'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// Search players
  Future<List<Map<String, dynamic>>> searchPlayers(String q, {int limit = 20}) async {
    // NOTE: /v1/admin/players/search is the canonical route on the VPS
    // (see vps/api/src/routes/admin.ts). The `/v1/admin/players-search`
    // variant below is kept as a fallback for older deployments.
    try {
      final res = await _client.get<Map<String, dynamic>>(
        '/v1/admin/players/search', query: {'q': q, 'limit': limit},
      );
      return ((res.data?['players']) as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      final res = await _client.get<Map<String, dynamic>>(
        '/v1/admin/players-search', query: {'q': q, 'limit': limit},
      );
      return ((res.data?['players']) as List? ?? []).cast<Map<String, dynamic>>();
    }
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ADMIN ENTITY CRUD
  //
  // These methods cover the entity CRUD operations that the admin console
  // performs: create / update / delete for League / Competition / Team /
  // Player / Coach / Match / NewsItem / Post / PlayerMatchStat, plus the
  // Become PRO queue (RoleRequest) and bulk inserts.
  //
  // The VPS admin routes (vps/api/src/routes/admin.ts) currently expose:
  //   GET    /v1/admin/stats
  //   GET    /v1/admin/claims
  //   GET    /v1/admin/users
  //   PATCH  /v1/admin/users/:id/role
  //   DELETE /v1/admin/users/:id
  //   GET    /v1/admin/matches
  //   POST   /v1/admin/matches
  //   PATCH  /v1/admin/matches/:id
  //   GET    /v1/admin/teams
  //   GET    /v1/admin/players/search
  //
  // The methods below that target routes not yet on the VPS are marked with
  // a TODO comment so the backend team can add them. They still issue the
  // request — the VPS will return 404 and the caller can fall back to the
  // compat shim or surface a friendly error. None of these methods hardcode
  // service-role credentials.
  // ─────────────────────────────────────────────────────────────────────────

  // ── Users ────────────────────────────────────────────────────────────────

  /// GET /v1/admin/users — list users (optionally filtered by role / search).
  Future<List<Map<String, dynamic>>> getAdminUsers({
    String? role,
    String? search,
    int limit = 50,
  }) async {
    final q = <String, dynamic>{'limit': limit};
    if (role != null && role.isNotEmpty)   q['role']   = role;
    if (search != null && search.isNotEmpty) q['search'] = search;
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/admin/users', query: q,
    );
    return ((res.data?['users']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// PATCH /v1/admin/users/:id/verify — set isVerified flag.
  // TODO(VPS): add `PATCH /v1/admin/users/:id/verify` route on the VPS.
  Future<void> verifyUser(String userId, bool verified) async {
    await _client.patch<void>(
      '/v1/admin/users/$userId/verify',
      data: {'isVerified': verified},
    );
  }

  // ── Leagues / Competitions ───────────────────────────────────────────────

  /// GET /v1/admin/leagues — list leagues.
  // TODO(VPS): add `GET /v1/admin/leagues` route on the VPS.
  Future<List<Map<String, dynamic>>> getAdminLeagues({int limit = 100}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/admin/leagues', query: {'limit': limit},
    );
    return ((res.data?['leagues']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// POST /v1/admin/leagues — create league.
  // TODO(VPS): add `POST /v1/admin/leagues` route on the VPS.
  Future<Map<String, dynamic>> createAdminLeague(Map<String, dynamic> body) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/admin/leagues', data: body,
    );
    return (res.data?['league'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// PATCH /v1/admin/leagues/:id — update league.
  // TODO(VPS): add `PATCH /v1/admin/leagues/:id` route on the VPS.
  Future<void> updateAdminLeague(String id, Map<String, dynamic> body) async {
    await _client.patch<void>('/v1/admin/leagues/$id', data: body);
  }

  /// DELETE /v1/admin/leagues/:id — delete league.
  // TODO(VPS): add `DELETE /v1/admin/leagues/:id` route on the VPS.
  Future<void> deleteAdminLeague(String id) async {
    await _client.delete<void>('/v1/admin/leagues/$id');
  }

  // ── Teams ────────────────────────────────────────────────────────────────

  /// POST /v1/admin/teams — create team.
  // TODO(VPS): add `POST /v1/admin/teams` route on the VPS.
  Future<Map<String, dynamic>> createAdminTeam(Map<String, dynamic> body) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/admin/teams', data: body,
    );
    return (res.data?['team'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// PATCH /v1/admin/teams/:id — update team.
  // TODO(VPS): add `PATCH /v1/admin/teams/:id` route on the VPS.
  Future<void> updateAdminTeam(String id, Map<String, dynamic> body) async {
    await _client.patch<void>('/v1/admin/teams/$id', data: body);
  }

  /// DELETE /v1/admin/teams/:id — delete team.
  // TODO(VPS): add `DELETE /v1/admin/teams/:id` route on the VPS.
  Future<void> deleteAdminTeam(String id) async {
    await _client.delete<void>('/v1/admin/teams/$id');
  }

  // ── Players ──────────────────────────────────────────────────────────────

  /// POST /v1/admin/players — create player.
  // TODO(VPS): add `POST /v1/admin/players` route on the VPS.
  Future<Map<String, dynamic>> createAdminPlayer(Map<String, dynamic> body) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/admin/players', data: body,
    );
    return (res.data?['player'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// PATCH /v1/admin/players/:id — update player.
  // TODO(VPS): add `PATCH /v1/admin/players/:id` route on the VPS.
  Future<void> updateAdminPlayer(String id, Map<String, dynamic> body) async {
    await _client.patch<void>('/v1/admin/players/$id', data: body);
  }

  /// DELETE /v1/admin/players/:id — delete player.
  // TODO(VPS): add `DELETE /v1/admin/players/:id` route on the VPS.
  Future<void> deleteAdminPlayer(String id) async {
    await _client.delete<void>('/v1/admin/players/$id');
  }

  /// POST /v1/admin/players/:id/stats — upsert a PlayerMatchStat row.
  // TODO(VPS): add `POST /v1/admin/players/:id/stats` route on the VPS.
  Future<void> upsertPlayerStat(String playerId, Map<String, dynamic> body) async {
    await _client.post<void>(
      '/v1/admin/players/$playerId/stats', data: body,
    );
  }

  // ── Coaches ──────────────────────────────────────────────────────────────

  /// GET /v1/admin/coaches — list coaches.
  // TODO(VPS): add `GET /v1/admin/coaches` route on the VPS.
  Future<List<Map<String, dynamic>>> getAdminCoaches({int limit = 100}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/admin/coaches', query: {'limit': limit},
    );
    return ((res.data?['coaches']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// POST /v1/admin/coaches — create coach.
  // TODO(VPS): add `POST /v1/admin/coaches` route on the VPS.
  Future<Map<String, dynamic>> createAdminCoach(Map<String, dynamic> body) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/admin/coaches', data: body,
    );
    return (res.data?['coach'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// PATCH /v1/admin/coaches/:id — update coach.
  // TODO(VPS): add `PATCH /v1/admin/coaches/:id` route on the VPS.
  Future<void> updateAdminCoach(String id, Map<String, dynamic> body) async {
    await _client.patch<void>('/v1/admin/coaches/$id', data: body);
  }

  /// DELETE /v1/admin/coaches/:id — delete coach.
  // TODO(VPS): add `DELETE /v1/admin/coaches/:id` route on the VPS.
  Future<void> deleteAdminCoach(String id) async {
    await _client.delete<void>('/v1/admin/coaches/$id');
  }

  // ── Matches ──────────────────────────────────────────────────────────────

  /// GET /v1/admin/matches — list matches (already on VPS).
  Future<List<Map<String, dynamic>>> getAdminMatches({int limit = 50}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/admin/matches', query: {'limit': limit},
    );
    return ((res.data?['matches']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// POST /v1/admin/matches — create match (already on VPS).
  Future<Map<String, dynamic>> createAdminMatch(Map<String, dynamic> body) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/admin/matches', data: body,
    );
    return (res.data?['match'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// PATCH /v1/admin/matches/:id — update match score/status (already on VPS).
  Future<void> updateAdminMatch(String id, Map<String, dynamic> body) async {
    await _client.patch<void>('/v1/admin/matches/$id', data: body);
  }

  /// DELETE /v1/admin/matches/:id — delete match.
  // TODO(VPS): add `DELETE /v1/admin/matches/:id` route on the VPS.
  Future<void> deleteAdminMatch(String id) async {
    await _client.delete<void>('/v1/admin/matches/$id');
  }

  // ── News ─────────────────────────────────────────────────────────────────

  /// GET /v1/admin/news — list news articles.
  // TODO(VPS): add `GET /v1/admin/news` route on the VPS.
  Future<List<Map<String, dynamic>>> getAdminNews({int limit = 50}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/admin/news', query: {'limit': limit},
    );
    return ((res.data?['news']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// POST /v1/admin/news — create news article (server-side wraps /v1/news).
  // TODO(VPS): add `POST /v1/admin/news` route on the VPS.
  Future<Map<String, dynamic>> createAdminNews(Map<String, dynamic> body) async {
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/admin/news', data: body,
    );
    return (res.data?['news'] as Map?)?.cast<String, dynamic>() ?? {};
  }

  /// DELETE /v1/admin/news/:id — delete news article.
  // TODO(VPS): add `DELETE /v1/admin/news/:id` route on the VPS.
  Future<void> deleteAdminNews(String id) async {
    await _client.delete<void>('/v1/admin/news/$id');
  }

  // ── Posts (moderation) ───────────────────────────────────────────────────

  /// GET /v1/admin/posts — list all posts for moderation.
  // TODO(VPS): add `GET /v1/admin/posts` route on the VPS.
  Future<List<Map<String, dynamic>>> getAdminPosts({int limit = 50}) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/admin/posts', query: {'limit': limit},
    );
    return ((res.data?['posts']) as List? ?? []).cast<Map<String, dynamic>>();
  }

  /// DELETE /v1/admin/posts/:id — cascade-delete a Post + its likes/comments.
  // TODO(VPS): add `DELETE /v1/admin/posts/:id` route on the VPS that
  // cascade-deletes PostLike / Comment / post_likes rows server-side.
  Future<void> deleteAdminPost(String id) async {
    await _client.delete<void>('/v1/admin/posts/$id');
  }

  // ── Become PRO queue (RoleRequest) ───────────────────────────────────────

  /// GET /v1/admin/role-requests?status=pending — list pending PRO requests.
  // TODO(VPS): add `GET /v1/admin/role-requests` route on the VPS.
  Future<List<Map<String, dynamic>>> getRoleRequests({
    String status = 'pending',
    int limit = 50,
  }) async {
    final res = await _client.get<Map<String, dynamic>>(
      '/v1/admin/role-requests',
      query: {'status': status, 'limit': limit},
    );
    return ((res.data?['requests']) as List? ?? [])
        .cast<Map<String, dynamic>>();
  }

  /// PATCH /v1/admin/role-requests/:id — approve / reject a PRO request.
  /// When approving, the VPS should cascade the role update to profiles +
  /// User tables (so the client never writes roles directly).
  // TODO(VPS): add `PATCH /v1/admin/role-requests/:id` route on the VPS.
  Future<void> decideRoleRequest(
    String id, {
    required String status, // 'approved' | 'rejected'
    String? role,
    String? userId,
    String? notes,
  }) async {
    await _client.patch<void>(
      '/v1/admin/role-requests/$id',
      data: {
        'status': status,
        if (role != null)   'role': role,
        if (userId != null) 'userId': userId,
        if (notes != null)  'reviewNotes': notes,
      },
    );
  }

  // ── Bulk inserts ─────────────────────────────────────────────────────────

  /// POST /v1/admin/teams/bulk — chunked team insert.
  // TODO(VPS): add `POST /v1/admin/teams/bulk` route on the VPS.
  Future<int> bulkCreateTeams(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return 0;
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/admin/teams/bulk', data: {'rows': rows},
    );
    return (res.data?['inserted'] as int?) ?? rows.length;
  }

  /// POST /v1/admin/players/bulk — chunked player insert.
  // TODO(VPS): add `POST /v1/admin/players/bulk` route on the VPS.
  Future<int> bulkCreatePlayers(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return 0;
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/admin/players/bulk', data: {'rows': rows},
    );
    return (res.data?['inserted'] as int?) ?? rows.length;
  }

  /// POST /v1/admin/matches/bulk — chunked fixture insert.
  // TODO(VPS): add `POST /v1/admin/matches/bulk` route on the VPS.
  Future<int> bulkCreateFixtures(List<Map<String, dynamic>> rows) async {
    if (rows.isEmpty) return 0;
    final res = await _client.post<Map<String, dynamic>>(
      '/v1/admin/matches/bulk', data: {'rows': rows},
    );
    return (res.data?['inserted'] as int?) ?? rows.length;
  }

  // ── Entity identity reconciliation ───────────────────────────────────────

  /// POST /v1/admin/entities/identity — create auth user + profile + User row
  /// for an entity (Team / Player / League). Returns the new uid.
  // TODO(VPS): add `POST /v1/admin/entities/identity` route on the VPS.
  Future<String?> createEntityIdentity(Map<String, dynamic> body) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        '/v1/admin/entities/identity', data: body,
      );
      return res.data?['uid'] as String?;
    } catch (_) {
      return null;
    }
  }

  /// POST /v1/admin/communities — create an entity fan community.
  // TODO(VPS): add `POST /v1/admin/communities` route on the VPS.
  Future<void> createEntityCommunity(Map<String, dynamic> body) async {
    try {
      await _client.post<void>('/v1/admin/communities', data: body);
    } catch (_) {
      // best-effort
    }
  }

  /// POST /v1/admin/users — create a user (auth + profiles + User row).
  // TODO(VPS): add `POST /v1/admin/users` route on the VPS.
  Future<String?> createAdminUser(Map<String, dynamic> body) async {
    try {
      final res = await _client.post<Map<String, dynamic>>(
        '/v1/admin/users', data: body,
      );
      return res.data?['uid'] as String?;
    } catch (_) {
      return null;
    }
  }

}