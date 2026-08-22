/// Detect image vs video from storage URL / filename.
bool isVideoMediaUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  final l = url.toLowerCase();
  if (l.contains('/videos/') || l.contains('video/')) return true;
  return l.endsWith('.mp4') ||
      l.endsWith('.mov') ||
      l.endsWith('.webm') ||
      l.endsWith('.m4v') ||
      l.contains('.mp4?') ||
      l.contains('.mov?') ||
      l.contains('.webm?');
}

bool isImageMediaUrl(String? url) {
  if (url == null || url.isEmpty) return false;
  if (isVideoMediaUrl(url)) return false;
  final l = url.toLowerCase();
  return l.endsWith('.jpg') ||
      l.endsWith('.jpeg') ||
      l.endsWith('.png') ||
      l.endsWith('.webp') ||
      l.endsWith('.gif') ||
      l.contains('.jpg?') ||
      l.contains('.jpeg?') ||
      l.contains('.png?') ||
      l.contains('/images/') ||
      l.contains('/posts/');
}

/// Prefer explicit postType, else sniff first media URL.
String resolveMediaPostType(String postType, List<String> mediaUrls) {
  final t = postType.toLowerCase();
  if (t == 'video' || t == 'image' || t == 'poll' || t == 'prediction' || t == 'welcome' || t == 'text') {
    if (t == 'media' || t.isEmpty) {
      // fall through
    } else if (t != 'media') {
      return t;
    }
  }
  if (mediaUrls.isEmpty) return t.isEmpty ? 'text' : t;
  if (mediaUrls.any(isVideoMediaUrl)) return 'video';
  return 'image';
}
