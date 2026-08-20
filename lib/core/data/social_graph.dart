import 'package:supabase_flutter/supabase_flutter.dart';

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
}

class SocialGraph {
  SupabaseClient get _sb => Supabase.instance.client;
  String? get _uid => _sb.auth.currentUser?.id;
  String? get currentUid => _uid;

  Future<String> resolveId(String idOrHandle) => _resolve(idOrHandle);

  Future<bool> isFollowing(String me, String targetId) async {
    final rows = await _sb
        .from('Follow')
        .select('followerId')
        .eq('followerId', me)
        .eq('followingId', targetId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }

  Future<bool> isFan(String me, String targetId) async {
    final rows = await _sb
        .from('fans')
        .select('fan_id')
        .eq('fan_id', me)
        .eq('target_id', targetId)
        .limit(1);
    return (rows as List).isNotEmpty;
  }


  Future<void> refreshCounts(String id) async {
    try {
      await _sb.rpc('refresh_user_counts', params: {'p_id': id});
    } catch (_) {}
  }

  Future<String> _resolve(String idOrHandle) async {
    final raw = idOrHandle.replaceAll('@', '').trim();
    if (raw.contains('-') && raw.length > 20) return raw;
    final u = await _sb.from('User').select('id').eq('handle', raw).maybeSingle();
    if (u?['id'] != null) return u!['id'].toString();
    // Team accounts: handle or team id → accountUserId
    final team = await _sb
        .from('Team')
        .select('accountUserId,id')
        .or('id.eq.$raw,id.eq.tm-$raw')
        .maybeSingle();
    final aid = team?['accountUserId']?.toString();
    if (aid != null && aid.isNotEmpty) return aid;
    // Try common handle forms e.g. simba_sc
    final u2 = await _sb.from('User').select('id').ilike('handle', raw).maybeSingle();
    return u2?['id']?.toString() ?? raw;
  }

  Future<List<GraphPerson>> followers(String userId) async {
    final id = await _resolve(userId);
    final rows = await _sb.from('Follow').select('followerId').eq('followingId', id);
    return _people([for (final r in rows as List) (r as Map)['followerId']?.toString()]);
  }

  Future<List<GraphPerson>> following(String userId) async {
    final id = await _resolve(userId);
    final rows = await _sb.from('Follow').select('followingId').eq('followerId', id);
    return _people([for (final r in rows as List) (r as Map)['followingId']?.toString()]);
  }

  Future<List<GraphPerson>> fans(String userId) async {
    final id = await _resolve(userId);
    final rows = await _sb.from('fans').select('fan_id').eq('target_id', id);
    return _people([for (final r in rows as List) (r as Map)['fan_id']?.toString()]);
  }

  Future<List<GraphPerson>> _people(List<String?> ids) async {
    final clean = ids.whereType<String>().toSet().toList();
    if (clean.isEmpty) return [];
    final rows = await _sb.from('User').select('id,handle,name,avatarUrl,role').inFilter('id', clean);
    final me = _uid;
    var followed = <String>{};
    var fanned = <String>{};
    if (me != null) {
      final f = await _sb.from('Follow').select('followingId').eq('followerId', me).inFilter('followingId', clean);
      followed = {for (final r in f as List) (r as Map)['followingId'].toString()};
      final n = await _sb.from('fans').select('target_id').eq('fan_id', me).inFilter('target_id', clean);
      fanned = {for (final r in n as List) (r as Map)['target_id'].toString()};
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
  }

  bool canFan(String role) {
    const ok = {'team', 'player', 'coach', 'academy'};
    return ok.contains(role.toLowerCase());
  }

  Future<void> follow(String targetId, {required bool on}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in');
    if (on) {
      await _sb.from('Follow').upsert({'followerId': uid, 'followingId': targetId, 'createdAt': DateTime.now().toIso8601String()});
    } else {
      await _sb.from('Follow').delete().eq('followerId', uid).eq('followingId', targetId);
    }
    await refreshCounts(targetId);
    await refreshCounts(uid);
  }

  Future<void> fan(String targetId, {required bool on}) async {
    final uid = _uid;
    if (uid == null) throw StateError('Sign in');
    if (on) {
      await _sb.from('fans').upsert({'fan_id': uid, 'target_id': targetId});
    } else {
      await _sb.from('fans').delete().eq('fan_id', uid).eq('target_id', targetId);
    }
    await refreshCounts(targetId);
  }
}
