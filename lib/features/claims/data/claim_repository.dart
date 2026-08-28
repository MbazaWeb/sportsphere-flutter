// lib/features/claims/data/claim_repository.dart
// All claim ops via VPS API — no Supabase dependency.

import '../../../core/data/vps_repository.dart';

class ClaimRepository {
  static final _vps = const VpsRepository();

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
    await _vps.post<void>('/v1/claims/submit', data: {
      'profileType':  profileType,
      'profileId':    profileId,
      'profileName':  profileName,
      if (claimEmail     != null) 'claimEmail':     claimEmail,
      if (claimPhone     != null) 'claimPhone':     claimPhone,
      if (evidenceNotes  != null) 'evidenceNotes':  evidenceNotes,
      if (teamId         != null) 'teamId':         teamId,
      if (playerId       != null) 'playerId':       playerId,
      if (coachId        != null) 'coachId':        coachId,
      if (leagueId       != null) 'leagueId':       leagueId,
    });
  }

  Future<List<Map<String, dynamic>>> myClaims() async {
    try {
      final res = await _vps.get<Map<String, dynamic>>('/v1/claims/mine');
      return ((res.data?['claims']) as List? ?? []).cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
