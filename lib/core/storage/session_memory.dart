/// In-memory fallback when web sessionStorage is unavailable.
class SessionMemory {
  SessionMemory._();
  static final map = <String, String>{};
}
