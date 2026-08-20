import 'package:supabase_flutter/supabase_flutter.dart';

class ClaimRepository {
  SupabaseClient get _sb => Supabase.instance.client;

  Future<void> submitClaim({
    required String profileType,
    required String profileId,
    required String profileName,
    String? claimEmail,
    String? claimPhone,
    String? evidenceNotes,
    String? teamId,
    String? playerId,
    String? coachId,
    String? leagueId,
  }) async {
    final user = _sb.auth.currentUser;
    if (user == null) {
      throw StateError('Log in to claim a profile');
    }

    final profile = await _sb.from('profiles').select().eq('id', user.id).maybeSingle();
    final first = (profile?['first_name'] as String?) ?? '';
    final last = (profile?['last_name'] as String?) ?? '';
    final handle = (profile?['handle'] as String?) ?? user.id.substring(0, 8);
    final name = ('$first $last').trim().isEmpty ? handle : ('$first $last').trim();
    final email = (profile?['email'] as String?) ?? user.email ?? '$handle@sportsphere.local';

    await _sb.from('User').upsert({
      'id': user.id,
      'name': name,
      'email': email,
      'handle': handle,
      'role': profile?['role'] ?? 'fan',
      'updatedAt': DateTime.now().toIso8601String(),
    });

    await _sb.from('ClaimRequest').insert({
      'userId': user.id,
      'profileType': profileType,
      'profileId': profileId,
      'profileName': profileName,
      'claimEmail': claimEmail,
      'claimPhone': claimPhone,
      'evidenceNotes': evidenceNotes,
      'teamId': teamId,
      'playerId': playerId,
      'coachId': coachId,
      'leagueId': leagueId,
      'status': 'pending',
    });
  }

  Future<List<Map<String, dynamic>>> myClaims() async {
    final user = _sb.auth.currentUser;
    if (user == null) return [];
    final rows = await _sb
        .from('ClaimRequest')
        .select()
        .eq('userId', user.id)
        .order('submittedAt', ascending: false);
    return List<Map<String, dynamic>>.from(rows as List);
  }
}
