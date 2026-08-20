import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Represents a person in the social graph
class GraphPerson {
  final String id;
  final String handle;
  final String name;
  final String? avatarUrl;
  final String role;
  final bool youFollow;
  final bool youFan;

  const GraphPerson({
    required this.id,
    required this.handle,
    required this.name,
    this.avatarUrl,
    required this.role,
    this.youFollow = false,
    this.youFan = false,
  });

  /// Creates a copy with updated follow/fan status
  GraphPerson copyWith({
    bool? youFollow,
    bool? youFan,
  }) {
    return GraphPerson(
      id: id,
      handle: handle,
      name: name,
      avatarUrl: avatarUrl,
      role: role,
      youFollow: youFollow ?? this.youFollow,
      youFan: youFan ?? this.youFan,
    );
  }
}

/// Social graph service for follow/fan relationships
class SocialGraph {
  const SocialGraph();

  SupabaseClient get _sb => Supabase.instance.client;

  String? get _uid => _sb.auth.currentUser?.id;
  String? get currentUid => _uid;

  /// Resolve an ID or handle to a user ID
  Future<String> resolveId(String idOrHandle) => _resolve(idOrHandle);

  /// Check if user [me] is following [targetId]
  Future<bool> isFollowing(String me, String targetId) async {
    try {
      final rows = await _sb
          .from('Follow')
          .select('followerId')
          .eq('followerId', me)
          .eq('followingId', targetId)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Check if user [me] is a fan of [targetId]
  Future<bool> isFan(String me, String targetId) async {
    try {
      final rows = await _sb
          .from('fans')
          .select('fan_id')
          .eq('fan_id', me)
          .eq('target_id', targetId)
          .limit(1);
      return (rows as List).isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  /// Refresh counts for a user
  Future<void> refreshCounts(String id) async {
    try {
      await _sb.rpc('refresh_user_counts', params: {'p_id': id});
    } catch (e) {
      // Log but don't throw - counts will update eventually
      debugPrint('Failed to refresh counts for $id: $e');
    }
  }

  /// Resolve a handle or ID to a user ID
  Future<String> _resolve(String idOrHandle) async {
    try {
      final raw = idOrHandle.replaceAll('@', '').trim();

      // If it looks like a UUID, return as-is
      if (raw.contains('-') && raw.length > 20) return raw;

      // Try User table first
      final user = await _sb
          .from('User')
          .select('id')
          .eq('handle', raw)
          .maybeSingle();
      if (user?['id'] != null) return user!['id'].toString();

      // Try Team accounts
      final team = await _sb
          .from('Team')
          .select('accountUserId,id')
          .or('id.eq.$raw,id.eq.tm-$raw')
          .maybeSingle();
      final aid = team?['accountUserId']?.toString();
      if (aid != null && aid.isNotEmpty) return aid;

      // Try case-insensitive handle match
      final user2 = await _sb
          .from('User')
          .select('id')
          .ilike('handle', raw)
          .maybeSingle();
      return user2?['id']?.toString() ?? raw;
    } catch (e) {
      debugPrint('Error resolving ID for $idOrHandle: $e');
      return idOrHandle;
    }
  }

  /// Get followers of a user
  Future<List<GraphPerson>> followers(String userId) async {
    final id = await _resolve(userId);
    final rows = await _sb
        .from('Follow')
        .select('followerId')
        .eq('followingId', id);
    final ids = [for (final r in rows as List) (r as Map)['followerId']?.toString()];
    return _people(ids);
  }

  /// Get users that a user is following
  Future<List<GraphPerson>> following(String userId) async {
    final id = await _resolve(userId);
    final rows = await _sb
        .from('Follow')
        .select('followingId')
        .eq('followerId', id);
    final ids = [for (final r in rows as List) (r as Map)['followingId']?.toString()];
    return _people(ids);
  }

  /// Get fans of a user
  Future<List<GraphPerson>> fans(String userId) async {
    final id = await _resolve(userId);
    final rows = await _sb
        .from('fans')
        .select('fan_id')
        .eq('target_id', id);
    final ids = [for (final r in rows as List) (r as Map)['fan_id']?.toString()];
    return _people(ids);
  }

  /// Fetch people by IDs with follow/fan status
  Future<List<GraphPerson>> _people(List<String?> ids) async {
    try {
      final clean = ids.whereType<String>().toSet().toList();
      if (clean.isEmpty) return [];

      // Fetch user details
      final rows = await _sb
          .from('User')
          .select('id,handle,name,avatarUrl,role')
          .inFilter('id', clean);

      final me = _uid;
      var followed = <String>{};
      var fanned = <String>{};

      // Only fetch relationships if logged in
      if (me != null) {
        // Batch fetch follows
        final followRows = await _sb
            .from('Follow')
            .select('followingId')
            .eq('followerId', me)
            .inFilter('followingId', clean);
        followed = {
          for (final r in followRows as List)
            (r as Map)['followingId'].toString()
        };

        // Batch fetch fans
        final fanRows = await _sb
            .from('fans')
            .select('target_id')
            .eq('fan_id', me)
            .inFilter('target_id', clean);
        fanned = {
          for (final r in fanRows as List)
            (r as Map)['target_id'].toString()
        };
      }

      return [
        for (final r in rows as List)
          GraphPerson(
            id: (r as Map)['id'].toString(),
            handle: r['handle']?.toString() ?? '',
            name: r['name']?.toString() ?? r['handle']?.toString() ?? '',
            avatarUrl: r['avatarUrl'] as String?,
            role: r['role']?.toString() ?? 'fan',
            youFollow: followed.contains(r['id'].toString()),
            youFan: fanned.contains(r['id'].toString()),
          )
      ];
    } catch (e) {
      debugPrint('Error fetching people: $e');
      return [];
    }
  }

  /// Check if a role can be fanned
  bool canFan(String role) {
    const ok = {'team', 'player', 'coach', 'academy'};
    return ok.contains(role.toLowerCase());
  }

  /// Follow or unfollow a target
  Future<void> follow(String targetId, {required bool on}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Please sign in to follow');

    try {
      if (on) {
        await _sb.from('Follow').upsert({
          'followerId': uid,
          'followingId': targetId,
          'createdAt': DateTime.now().toIso8601String(),
        });
      } else {
        await _sb
            .from('Follow')
            .delete()
            .eq('followerId', uid)
            .eq('followingId', targetId);
      }

      // Refresh counts for both users
      await refreshCounts(targetId);
      await refreshCounts(uid);
    } catch (e) {
      debugPrint('Failed to ${on ? 'follow' : 'unfollow'}: $e');
      rethrow;
    }
  }

  /// Fan or unfan a target
  Future<void> fan(String targetId, {required bool on}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Please sign in to fan');

    try {
      if (on) {
        await _sb.from('fans').upsert({
          'fan_id': uid,
          'target_id': targetId,
        });
      } else {
        await _sb
            .from('fans')
            .delete()
            .eq('fan_id', uid)
            .eq('target_id', targetId);
      }

      await refreshCounts(targetId);
    } catch (e) {
      debugPrint('Failed to ${on ? 'fan' : 'unfan'}: $e');
      rethrow;
    }
  }
}
