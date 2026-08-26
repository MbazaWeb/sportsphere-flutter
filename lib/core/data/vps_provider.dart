// lib/core/data/vps_provider.dart
// Riverpod providers for the VPS API.
// Import this wherever you need VPS calls instead of direct Supabase.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'vps_repository.dart';

/// Singleton VPS repository — share one Dio client across the app.
final vpsRepositoryProvider = Provider<VpsRepository>((ref) {
  return const VpsRepository();
});
