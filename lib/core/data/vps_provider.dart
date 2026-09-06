// lib/core/data/vps_provider.dart
// Riverpod providers for the VPS API.
// Riverpod provider for VpsRepository — used everywhere the app talks to the VPS API.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'vps_repository.dart';

/// Singleton VPS repository — share one Dio client across the app.
final vpsRepositoryProvider = Provider<VpsRepository>((ref) {
  return const VpsRepository();
});
