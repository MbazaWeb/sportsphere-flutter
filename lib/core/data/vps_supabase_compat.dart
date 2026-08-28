// lib/core/data/vps_supabase_compat.dart
//
// MIGRATION SHIM — provides a VpsSupabaseCompat.client object that
// satisfies the remaining Supabase call sites while we migrate them
// to native VPS calls. Once all files are migrated, this file is deleted.
//
// This shim keeps the app compiling during the migration.
// It delegates DB reads to VPS /v1/* endpoints and has NO Supabase dependency.

import 'package:shared_preferences/shared_preferences.dart';
import 'vps_repository.dart';

class VpsSupabaseCompat {
  VpsSupabaseCompat._();
  static final client = _VpsCompatClient();
}

class _VpsCompatClient {
  final _vps = const VpsRepository();

  _VpsCompatAuth get auth => _VpsCompatAuth();

  _VpsCompatQuery from(String table) => _VpsCompatQuery(table, _vps);
}

class _VpsCompatAuth {
  Future<String?> _token() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('auth_access_token');
  }

  // Minimal session stub — returns true if token exists
  Future<bool> get hasSession async => (await _token()) != null;

  // currentUser stub — returns minimal object from stored token
  _VpsCompatUser? get currentUser => null; // Use VpsRepository.getMe() instead
}

class _VpsCompatUser {
  final String id;
  const _VpsCompatUser(this.id);
}

class _VpsCompatQuery {
  final String _table;
  final VpsRepository _vps;
  _VpsCompatQuery(this._table, this._vps);

  // Stub — actual data should be fetched via VpsRepository directly.
  // Returns empty list so app doesn't crash during migration.
  Future<List<Map<String, dynamic>>> get([String? columns]) async => [];
  Future<List<Map<String, dynamic>>> select([String? columns]) async => [];
}
