import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

import '../../../core/theme/colors.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SHARED PROFILE WIDGETS
// Used by FanProfileView, PlayerProfileView, and future role profiles
// ══════════════════════════════════════════════════════════════════════════════

// ── Post media type ───────────────────────────────────────────────────────────

/// Identifies what kind of media a [ProfilePost] carries.
enum ProfileMediaType {
  /// Text-only post — no media section rendered.
  text,

  /// One or more image URLs.
  image,

  /// A single video URL.
  video,

  /// Mix of images and at least one video.
  mixed,
}

/// Returns true when [url] looks like a video asset.
bool _isVideoUrl(String url) {
  final u = url.toLowerCase();
  return u.endsWith('.mp4') ||
      u.endsWith('.mov') ||
      u.endsWith('.webm') ||
      u.endsWith('.m4v') ||
      u.endsWith('.mkv');
}

/// Derives a [ProfileMediaType] from a flat list of URLs.
ProfileMediaType _inferMediaType(List<String> urls) {
  if (urls.isEmpty) return ProfileMediaType.text;
  final hasVideo = urls.any(_isVideoUrl);
  final hasImage = urls.any((u) => !_isVideoUrl(u));
  if (hasVideo && hasImage) return ProfileMediaType.mixed;
  if (hasVideo) return ProfileMediaType.video;
  return ProfileMediaType.image;
}

// ── Post model ─────────────────────────────────────────────────────────────────

class ProfilePost {
  final String text;
  final List<String> hashtags;
  final String timeAgo;
  final int likes;
  final int comments;
  final int shares;

  /// Flat list of media URLs attached to the post (images and/or videos).
  final List<String> mediaUrls;

  /// Whether the post carries image/video/mixed media.
  final ProfileMediaType? mediaType;

  // ── Poll fields ────────────────────────────────────────────
  final String? pollId;
  final List<String> pollOptions;
  final int? pollTotalVotes;
  final int? myPollVote;
  final Map<int, int> pollCounts;

  // ── Prediction fields ──────────────────────────────────────
  final String? predHome;
  final String? predAway;
  final int? predHomeScore;
  final int? predAwayScore;
  final String? myPrediction;

  // ── Post type ──────────────────────────────────────────────
  final String postType; // text, media, poll, prediction, video

  /// Backwards-compatible constructor.
  ///
  /// New callers should pass [mediaUrls] (and optionally [mediaType]).
  /// Existing callers may still pass the legacy [imageUrl] / [hasImage] /
  /// [imageCount] / [hasVideo] flags — when [mediaUrls] is empty but
  /// [imageUrl] is non-null, it is folded into [mediaUrls] automatically
  /// so the post still renders with media.
  ProfilePost({
    required this.text,
    required this.hashtags,
    required this.timeAgo,
    required this.likes,
    required this.comments,
    required this.shares,
    List<String> mediaUrls = const [],
    this.mediaType,
    this.pollId,
    this.pollOptions = const [],
    this.pollTotalVotes,
    this.myPollVote,
    this.pollCounts = const {},
    this.predHome,
    this.predAway,
    this.predHomeScore,
    this.predAwayScore,
    this.myPrediction,
    this.postType = 'text',
    // ── Legacy params ──────────────────────────────────────────────────
    this.hasImage = false,
    this.imageCount = 1,
    this.hasVideo = false,
    this.imageUrl,
  })  : mediaUrls = (mediaUrls.isEmpty && imageUrl != null && imageUrl.isNotEmpty)
            ? [imageUrl]
            : mediaUrls;

  /// Legacy constructor flag — ignored when [mediaUrls] is populated.
  /// Prefer checking [effectiveMediaType] / [hasImageMedia] getter instead.
  final bool hasImage;

  /// Legacy constructor flag — ignored when [mediaUrls] is populated.
  final int imageCount;

  /// Legacy constructor flag — ignored when [mediaUrls] is populated.
  final bool hasVideo;

  /// Legacy single-image URL — folded into [mediaUrls] when [mediaUrls] is
  /// empty at construction time.
  final String? imageUrl;

  /// Convenience: true when the post has at least one image URL.
  bool get hasImageMedia {
    switch (effectiveMediaType) {
      case ProfileMediaType.image:
      case ProfileMediaType.mixed:
        return true;
      case ProfileMediaType.text:
      case ProfileMediaType.video:
        return false;
    }
  }

  /// Convenience: number of image URLs (excludes video URLs).
  int get imageCountActual {
    switch (effectiveMediaType) {
      case ProfileMediaType.image:
      case ProfileMediaType.mixed:
        return mediaUrls.where((u) => !_isVideoUrl(u)).length;
      case ProfileMediaType.text:
      case ProfileMediaType.video:
        return 0;
    }
  }

  /// Convenience: true when the post has at least one video URL.
  bool get hasVideoMedia {
    switch (effectiveMediaType) {
      case ProfileMediaType.video:
      case ProfileMediaType.mixed:
        return true;
      case ProfileMediaType.text:
      case ProfileMediaType.image:
        return false;
    }
  }

  /// Resolves the effective media type, inferring it from [mediaUrls] when the
  /// caller did not specify one explicitly.
  ProfileMediaType get effectiveMediaType =>
      mediaType ?? _inferMediaType(mediaUrls);
}

// ── Count formatter ────────────────────────────────────────────────────────────

String formatCount(int n) {
  if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
  if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
  return '$n';
}

// ── Cover gradient fallback ────────────────────────────────────────────────────

class ProfileCoverGradient extends StatelessWidget {
  final Color accent;
  final IconData icon;
  const ProfileCoverGradient({
    super.key,
    required this.accent,
    this.icon = Icons.groups_rounded,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF08111E),
            accent.withValues(alpha: 0.45),
            const Color(0xFF030810),
          ],
        ),
      ),
      child: Center(
        child: Icon(icon, size: 80, color: accent.withValues(alpha: 0.16)),
      ),
    );
  }
}

// ── Circular avatar ────────────────────────────────────────────────────────────

class ProfileAvatar extends StatelessWidget {
  final String? asset;
  final double radius;
  final Color accentColor;
  const ProfileAvatar({
    super.key,
    required this.asset,
    required this.radius,
    required this.accentColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SportSphereColors.background,
        border: Border.all(color: SportSphereColors.background, width: 3),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.28),
            blurRadius: 22,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: asset == null
            ? _AvatarFallback(accent: accentColor)
            : asset!.startsWith('http')
                ? Image.network(asset!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _AvatarFallback(accent: accentColor))
                : Image.asset(asset!, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _AvatarFallback(accent: accentColor)),
      ),
    );
  }
}

class _AvatarFallback extends StatelessWidget {
  final Color accent;
  const _AvatarFallback({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: accent.withValues(alpha: 0.15),
      child: Icon(Icons.person_rounded, color: accent.withValues(alpha: 0.6), size: 40),
    );
  }
}

// ── Stat column ────────────────────────────────────────────────────────────────

class ProfileStat extends StatelessWidget {
  final String value;
  final String label;
  final VoidCallback? onTap;
  const ProfileStat({
    super.key,
    required this.value,
    required this.label,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        children: [
          Text(
            value,
            style: const TextStyle(
              color: SportSphereColors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            label,
            style: const TextStyle(
              color: SportSphereColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class ProfileStatDivider extends StatelessWidget {
  const ProfileStatDivider({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 14),
      color: Colors.white.withValues(alpha: 0.10),
    );
  }
}

// ── Tab bar delegate ───────────────────────────────────────────────────────────

class ProfileTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;
  const ProfileTabBarDelegate({required this.tabBar});

  @override double get minExtent => 48;
  @override double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) =>
      tabBar;

  @override
  bool shouldRebuild(ProfileTabBarDelegate old) => false;
}

// ── Floating nav button (back / more / share) ──────────────────────────────────

class ProfileNavButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final String semanticsLabel;
  const ProfileNavButton({
    super.key,
    required this.icon,
    required this.onTap,
    required this.semanticsLabel,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semanticsLabel,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.black.withValues(alpha: 0.48),
          ),
          child: Icon(icon, color: Colors.white, size: 18),
        ),
      ),
    );
  }
}

// ── Role badge pill ────────────────────────────────────────────────────────────

class RoleBadge extends StatelessWidget {
  final String label;
  final Color color;

  const RoleBadge({
    super.key,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

// ── Post card ──────────────────────────────────────────────────────────────────

class ProfilePostCard extends StatefulWidget {
  final ProfilePost post;
  final String authorName;
  final String authorHandle;
  final String? authorAvatarAsset;
  final bool isVerified;
  final Color accentColor;

  const ProfilePostCard({
    super.key,
    required this.post,
    required this.authorName,
    required this.authorHandle,
    required this.accentColor,
    this.authorAvatarAsset,
    this.isVerified = false,
  });

  @override
  State<ProfilePostCard> createState() => _ProfilePostCardState();
}

class _ProfilePostCardState extends State<ProfilePostCard> {
  bool _liked = false;

  @override
  Widget build(BuildContext context) {
    final post = widget.post;
    final likes = post.likes + (_liked ? 1 : 0);

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xD8071422),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
        boxShadow: const [
          BoxShadow(color: Color(0x38000000), blurRadius: 20, offset: Offset(0, 8)),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Author row
            Row(
              children: [
                _AuthorAvatar(
                  asset: widget.authorAvatarAsset,
                  accent: widget.accentColor,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(widget.authorName,
                              style: const TextStyle(
                                color: SportSphereColors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                              )),
                          if (widget.isVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded,
                                color: Color(0xFFFFD700), size: 13),
                          ],
                        ],
                      ),
                      Text('${widget.authorHandle} · ${post.timeAgo}',
                          style: TextStyle(
                            color: SportSphereColors.muted.withValues(alpha: 0.75),
                            fontSize: 12,
                          )),
                    ],
                  ),
                ),
                Semantics(
                  label: 'Post options',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      showModalBottomSheet<void>(
                        context: context,
                        backgroundColor: SportSphereColors.card,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) => SafeArea(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              ListTile(
                                leading: const Icon(Icons.link_rounded,
                                    color: SportSphereColors.muted),
                                title: const Text('Copy link'),
                                onTap: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text('Link copied')),
                                  );
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.share_rounded,
                                    color: SportSphereColors.muted),
                                title: const Text('Share post'),
                                onTap: () {
                                  Navigator.pop(context);
                                  Share.share(post.text.isEmpty
                                      ? 'Check out this post on Playify'
                                      : post.text);
                                },
                              ),
                              ListTile(
                                leading: const Icon(Icons.flag_outlined,
                                    color: SportSphereColors.muted),
                                title: const Text('Report'),
                                onTap: () {
                                  Navigator.pop(context);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                        content: Text(
                                            'Report submitted — thank you')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                    child: const Icon(Icons.more_vert_rounded,
                        color: SportSphereColors.muted, size: 20),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Text + hashtags
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: SportSphereColors.white,
                  fontSize: 15,
                  height: 1.45,
                ),
                children: [
                  TextSpan(text: post.text),
                  if (post.hashtags.isNotEmpty) ...[
                    const TextSpan(text: '\n'),
                    ...post.hashtags.map((h) => TextSpan(
                          text: '$h ',
                          style: TextStyle(
                            color: widget.accentColor,
                            fontWeight: FontWeight.w600,
                          ),
                        )),
                  ],
                ],
              ),
            ),

            // Media — render based on ProfilePost.effectiveMediaType.
            //   • text   → no media section
            //   • image  → 1 image = single CachedNetworkImage,
            //              N>1 = horizontal PageView with dots indicator
            //   • video  → _ProfilePostVideo widget (uses video_player)
            //   • mixed  → render every URL in order via _ProfilePostMediaItem
            if (post.postType == 'poll' && post.pollOptions.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ProfilePollWidget(post: post),
            ] else if (post.postType == 'prediction' &&
                (post.predHome != null || post.predAway != null)) ...[
              const SizedBox(height: 12),
              _ProfilePredictionWidget(post: post),
            ] else if (post.mediaUrls.isNotEmpty) ...[
              const SizedBox(height: 12),
              _ProfilePostMedia(
                urls: post.mediaUrls,
                mediaType: post.effectiveMediaType,
                accent: widget.accentColor,
              ),
            ],

            const SizedBox(height: 14),

            // Engagement
            Row(
              children: [
                // Like
                Semantics(
                  label: _liked ? 'Unlike' : 'Like',
                  button: true,
                  child: GestureDetector(
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() => _liked = !_liked);
                    },
                    child: Row(
                      children: [
                        Icon(
                          _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                          color: _liked ? SportSphereColors.danger : SportSphereColors.muted,
                          size: 20,
                        ),
                        const SizedBox(width: 5),
                        Text(formatCount(likes),
                            style: TextStyle(
                              color: _liked ? SportSphereColors.danger : SportSphereColors.muted,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                _EngagementBtn(
                  icon: Icons.chat_bubble_outline_rounded,
                  label: formatCount(post.comments),
                  semantics: 'Comment',
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Comments coming soon')),
                    );
                  },
                ),
                // Predict button removed — only shown on prediction-type posts in feed
                const Spacer(),
                _EngagementBtn(
                  icon: Icons.ios_share_rounded,
                  label: 'Share',
                  semantics: 'Share',
                  onTap: () {
                    Share.share(post.text.isEmpty
                        ? 'Check out this post on Playify'
                        : post.text);
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorAvatar extends StatelessWidget {
  final String? asset;
  final Color accent;
  const _AuthorAvatar({required this.asset, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: accent.withValues(alpha: 0.40), width: 1.5),
      ),
      child: ClipOval(
        child: asset != null
            ? Image.asset(asset!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _fallback())
            : _fallback(),
      ),
    );
  }

  Widget _fallback() => Container(
        color: accent.withValues(alpha: 0.15),
        child: Icon(Icons.person_rounded, color: accent, size: 20),
      );
}

class _EngagementBtn extends StatelessWidget {
  const _EngagementBtn({
    required this.icon,
    required this.label,
    required this.semantics,
    this.onTap,
  });

  final IconData icon;
  final String label;
  final String semantics;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      button: true,
      child: GestureDetector(
        onTap: onTap ?? () {},
        child: Row(
          children: [
            Icon(icon, color: SportSphereColors.muted, size: 19),
            const SizedBox(width: 5),
            Text(label,
                style: const TextStyle(
                  color: SportSphereColors.muted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
          ],
        ),
      ),
    );
  }
}

// ── Post media grid ────────────────────────────────────────────────────────────

class PostMedia extends StatelessWidget {
  final int imageCount;
  final bool hasVideo;
  final Color accent;
  const PostMedia({
    super.key,
    required this.imageCount,
    required this.hasVideo,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (imageCount == 1 && !hasVideo) {
      return PostMediaTile(accent: accent, hasVideo: false, aspectRatio: 16 / 9);
    }
    return Row(
      children: [
        Expanded(child: PostMediaTile(accent: accent, hasVideo: hasVideo, aspectRatio: 1)),
        const SizedBox(width: 4),
        Expanded(child: PostMediaTile(accent: accent, hasVideo: false, aspectRatio: 1)),
      ],
    );
  }
}

class PostMediaTile extends StatelessWidget {
  final Color accent;
  final bool hasVideo;
  final double aspectRatio;
  const PostMediaTile({
    super.key,
    required this.accent,
    required this.hasVideo,
    required this.aspectRatio,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: AspectRatio(
        aspectRatio: aspectRatio,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                const Color(0xFF08111E),
                accent.withValues(alpha: 0.28),
                const Color(0xFF020810),
              ],
            ),
          ),
          child: hasVideo
              ? Center(
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.55),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: const Icon(Icons.play_arrow_rounded, color: Colors.white, size: 30),
                  ),
                )
              : Icon(Icons.image_rounded, color: accent.withValues(alpha: 0.25), size: 40),
        ),
      ),
    );
  }
}

// ── Profile post media renderer ───────────────────────────────────────────────
//
// Handles all four media types carried by [ProfilePost]:
//   • image  → 1 image = single CachedNetworkImage, N>1 = horizontal PageView
//              with a dots indicator underneath.
//   • video  → inline [_ProfilePostVideo] using the `video_player` package.
//   • mixed  → all URLs rendered in order via [_ProfilePostMediaItem].
//   • text   → caller decides not to render this widget at all.
//
// Uses `cached_network_image` for HTTP/HTTPS image caching. Non-network URLs
// fall back to Image.asset / Image.network as appropriate.

class _ProfilePostMedia extends StatelessWidget {
  final List<String> urls;
  final ProfileMediaType mediaType;
  final Color accent;

  const _ProfilePostMedia({
    required this.urls,
    required this.mediaType,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    if (urls.isEmpty) return const SizedBox.shrink();

    switch (mediaType) {
      case ProfileMediaType.image:
        final imageUrls = urls.where((u) => !_isVideoUrl(u)).toList();
        if (imageUrls.isEmpty) return const SizedBox.shrink();
        if (imageUrls.length == 1) {
          return _ProfilePostMediaItem(
            url: imageUrls.first,
            isVideo: false,
            accent: accent,
          );
        }
        return _ProfilePostImagePager(urls: imageUrls, accent: accent);
      case ProfileMediaType.video:
        final videoUrls = urls.where(_isVideoUrl).toList();
        if (videoUrls.isEmpty) return const SizedBox.shrink();
        if (videoUrls.length == 1) {
          return _ProfilePostMediaItem(
            url: videoUrls.first,
            isVideo: true,
            accent: accent,
          );
        }
        return _ProfilePostImagePager(
          urls: videoUrls,
          accent: accent,
          allVideos: true,
        );
      case ProfileMediaType.mixed:
        // Render each URL in order; videos become inline players,
        // images become cached network images.
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final u in urls) ...[
              _ProfilePostMediaItem(
                url: u,
                isVideo: _isVideoUrl(u),
                accent: accent,
              ),
              const SizedBox(height: 8),
            ],
          ],
        );
      case ProfileMediaType.text:
        return const SizedBox.shrink();
    }
  }
}

/// Horizontal pager for multiple media URLs (images or videos).
class _ProfilePostImagePager extends StatefulWidget {
  final List<String> urls;
  final Color accent;
  final bool allVideos;

  const _ProfilePostImagePager({
    required this.urls,
    required this.accent,
    this.allVideos = false,
  });

  @override
  State<_ProfilePostImagePager> createState() => _ProfilePostImagePagerState();
}

class _ProfilePostImagePagerState extends State<_ProfilePostImagePager> {
  int _page = 0;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            height: 240,
            child: PageView.builder(
              itemCount: widget.urls.length,
              onPageChanged: (i) => setState(() => _page = i),
              itemBuilder: (_, i) => _ProfilePostMediaItem(
                url: widget.urls[i],
                isVideo: widget.allVideos,
                accent: widget.accent,
                fit: BoxFit.cover,
                height: 240,
              ),
            ),
          ),
        ),
        if (widget.urls.length > 1) ...[
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.urls.length, (i) {
              final active = i == _page;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                margin: const EdgeInsets.symmetric(horizontal: 3),
                width: active ? 7 : 5,
                height: active ? 7 : 5,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: active
                      ? widget.accent
                      : widget.accent.withValues(alpha: 0.30),
                ),
              );
            }),
          ),
        ],
      ],
    );
  }
}

/// Renders a single media URL — video or image, network or asset.
class _ProfilePostMediaItem extends StatelessWidget {
  final String url;
  final bool isVideo;
  final Color accent;
  final BoxFit fit;
  final double? height;

  const _ProfilePostMediaItem({
    required this.url,
    required this.isVideo,
    required this.accent,
    this.fit = BoxFit.cover,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    if (isVideo) {
      return _ProfilePostVideo(
        url: url,
        accent: accent,
        fit: fit,
        height: height,
      );
    }

    final isNetwork = url.startsWith('http://') || url.startsWith('https://');
    final inner = isNetwork
        ? CachedNetworkImage(
            imageUrl: url,
            fit: fit,
            placeholder: (_, __) => _mediaSkeleton(accent),
            errorWidget: (_, __, ___) =>
                _mediaErrorPlaceholder(accent),
          )
        : Image.asset(
            url,
            fit: fit,
            errorBuilder: (_, __, ___) => _mediaErrorPlaceholder(accent),
          );

    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: double.infinity,
        height: height ?? 240,
        child: inner,
      ),
    );
  }

  Widget _mediaSkeleton(Color accent) => Container(
        color: const Color(0xFF071421),
        alignment: Alignment.center,
        child: CircularProgressIndicator(
            strokeWidth: 2, color: accent.withValues(alpha: 0.6)),
      );

  Widget _mediaErrorPlaceholder(Color accent) => Container(
        color: const Color(0xFF071421),
        alignment: Alignment.center,
        padding: const EdgeInsets.all(24),
        child: Icon(Icons.broken_image_outlined,
            color: accent.withValues(alpha: 0.45), size: 40),
      );
}

/// Inline video player for a single URL using the `video_player` package.
/// Initialises lazily on first build, shows a tappable thumbnail with a
/// play button overlay until the user taps to start playback.
class _ProfilePostVideo extends StatefulWidget {
  final String url;
  final Color accent;
  final BoxFit fit;
  final double? height;

  const _ProfilePostVideo({
    required this.url,
    required this.accent,
    this.fit = BoxFit.cover,
    this.height,
  });

  @override
  State<_ProfilePostVideo> createState() => _ProfilePostVideoState();
}

class _ProfilePostVideoState extends State<_ProfilePostVideo> {
  VideoPlayerController? _controller;
  bool _initialised = false;
  bool _failed = false;
  bool _showPlayOverlay = true;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      final ctl = VideoPlayerController.networkUrl(Uri.parse(widget.url));
      await ctl.initialize();
      if (!mounted) {
        ctl.dispose();
        return;
      }
      setState(() {
        _controller = ctl;
        _initialised = true;
      });
    } catch (e) {
      debugPrint('[_ProfilePostVideo] init failed for ${widget.url}: $e');
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  void _togglePlay() {
    final ctl = _controller;
    if (ctl == null) return;
    setState(() {
      if (ctl.value.isPlaying) {
        ctl.pause();
        _showPlayOverlay = true;
      } else {
        ctl.play();
        _showPlayOverlay = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final h = widget.height ?? 240;
    if (_failed) {
      return _errorTile(h);
    }
    if (!_initialised || _controller == null) {
      return _loadingTile(h);
    }
    final ctl = _controller!;
    return ClipRRect(
      borderRadius: BorderRadius.circular(14),
      child: SizedBox(
        width: double.infinity,
        height: h,
        child: Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: _togglePlay,
              child: FittedBox(
                fit: widget.fit,
                clipBehavior: Clip.hardEdge,
                child: SizedBox(
                  width: ctl.value.size.width,
                  height: ctl.value.size.height,
                  child: VideoPlayer(ctl),
                ),
              ),
            ),
            if (_showPlayOverlay)
              Align(
                alignment: Alignment.center,
                child: GestureDetector(
                  onTap: _togglePlay,
                  child: Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.black.withValues(alpha: 0.55),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.35)),
                    ),
                    child: const Icon(Icons.play_arrow_rounded,
                        color: Colors.white, size: 32),
                  ),
                ),
              ),
            Positioned(
              bottom: 6,
              left: 6,
              right: 6,
              child: VideoProgressIndicator(
                ctl,
                allowScrubbing: true,
                colors: VideoProgressColors(
                  playedColor: widget.accent,
                  bufferedColor: widget.accent.withValues(alpha: 0.30),
                  backgroundColor: Colors.white.withValues(alpha: 0.10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _loadingTile(double h) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          height: h,
          color: const Color(0xFF071421),
          alignment: Alignment.center,
          child: CircularProgressIndicator(
              strokeWidth: 2, color: widget.accent.withValues(alpha: 0.6)),
        ),
      );

  Widget _errorTile(double h) => ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          height: h,
          color: const Color(0xFF071421),
          alignment: Alignment.center,
          child: Icon(Icons.error_outline_rounded,
              color: widget.accent.withValues(alpha: 0.45), size: 40),
        ),
      );
}

// ── About section card ─────────────────────────────────────────────────────────

class AboutSection extends StatelessWidget {
  final String title;
  final Widget child;
  const AboutSection({super.key, required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xD0071422),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.07)),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title.toUpperCase(),
              style: TextStyle(
                color: SportSphereColors.muted.withValues(alpha: 0.7),
                fontSize: 11,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.1,
              )),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class AboutRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  const AboutRow({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.valueColor,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: iconColor.withValues(alpha: 0.10),
                ),
                child: Icon(icon, color: iconColor, size: 16),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(label,
                    style: const TextStyle(
                      color: SportSphereColors.muted,
                      fontSize: 13,
                    )),
              ),
              Text(value,
                  style: TextStyle(
                    color: valueColor ?? SportSphereColors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  )),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
      ],
    );
  }
}

// ── More sheet ─────────────────────────────────────────────────────────────────

class ProfileMoreSheet extends StatelessWidget {
  final bool isOwnProfile;
  final List<ProfileMoreOption> options;
  const ProfileMoreSheet({
    super.key,
    required this.isOwnProfile,
    required this.options,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: SportSphereColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 36),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.only(bottom: 18),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          ...options.map((o) => Semantics(
                label: o.label,
                button: true,
                child: GestureDetector(
                  onTap: o.onTap,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      children: [
                        Icon(o.icon,
                            color: o.destructive
                                ? SportSphereColors.danger
                                : SportSphereColors.white,
                            size: 22),
                        const SizedBox(width: 16),
                        Text(o.label,
                            style: TextStyle(
                              color: o.destructive
                                  ? SportSphereColors.danger
                                  : SportSphereColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                ),
              )),
        ],
      ),
    );
  }
}

class ProfileMoreOption {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool destructive;
  const ProfileMoreOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
  });
}

// ══ Poll widget for profile Spotlights ════════════════════════════════════════

class _ProfilePollWidget extends StatefulWidget {
  final ProfilePost post;
  const _ProfilePollWidget({required this.post});
  @override State<_ProfilePollWidget> createState() => _ProfilePollWidgetState();
}

class _ProfilePollWidgetState extends State<_ProfilePollWidget> {
  late int? _voted;
  late Map<int,int> _counts;

  @override
  void initState() {
    super.initState();
    _voted = widget.post.myPollVote;
    _counts = Map<int,int>.from(widget.post.pollCounts);
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.post.pollOptions;
    final total = (widget.post.pollTotalVotes ?? 0) +
        _counts.values.fold<int>(0, (a, b) => a + b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF092B4A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SportSphereColors.electricBlue.withValues(alpha: 0.4)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.poll_rounded, color: SportSphereColors.electricBlue, size: 16),
          const SizedBox(width: 6),
          const Text('POLL', style: TextStyle(color: SportSphereColors.electricBlue,
              fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
          const Spacer(),
          if (total > 0) Text('$total vote${total == 1 ? '' : 's'}',
              style: const TextStyle(color: SportSphereColors.muted, fontSize: 11)),
        ]),
        const SizedBox(height: 10),
        ...List.generate(options.length, (i) {
          final count = _counts[i] ?? 0;
          final pct = total > 0 ? (count / total * 100).round() : 0;
          final voted = _voted == i;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: GestureDetector(
              onTap: () async {
                if (_voted != null) return;
                final pollId = widget.post.pollId;
                if (pollId == null) { setState(() => _voted = i); return; }
                try {
                  await Supabase.instance.client.rpc('increment_poll_votes', params: {
                    'p_poll_id': pollId, 'p_user_id': Supabase.instance.client.auth.currentUser?.id, 'p_option_index': i,
                  });
                  setState(() { _voted = i; _counts[i] = (_counts[i] ?? 0) + 1; });
                } catch (_) { setState(() => _voted = i); }
              },
              child: Stack(children: [
                Container(
                  height: 38,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white.withValues(alpha: 0.06),
                    border: Border.all(color: voted
                        ? SportSphereColors.electricBlue
                        : Colors.white.withValues(alpha: 0.1)),
                  ),
                ),
                if (_voted != null)
                  FractionallySizedBox(
                    widthFactor: pct / 100,
                    child: Container(
                      height: 38,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        color: voted
                            ? SportSphereColors.electricBlue.withValues(alpha: 0.25)
                            : Colors.white.withValues(alpha: 0.08),
                      ),
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  child: Row(children: [
                    if (voted) ...[
                      const Icon(Icons.check_circle_rounded,
                          color: SportSphereColors.electricBlue, size: 14),
                      const SizedBox(width: 6),
                    ],
                    Expanded(child: Text(options[i],
                        style: TextStyle(
                            color: voted ? SportSphereColors.electricBlue : SportSphereColors.white,
                            fontSize: 13, fontWeight: FontWeight.w600))),
                    if (_voted != null)
                      Text('$pct%', style: const TextStyle(
                          color: SportSphereColors.muted, fontSize: 12)),
                  ]),
                ),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ══ Prediction widget for profile Spotlights ══════════════════════════════════

class _ProfilePredictionWidget extends StatelessWidget {
  final ProfilePost post;
  const _ProfilePredictionWidget({required this.post});

  @override
  Widget build(BuildContext context) {
    final home = post.predHome ?? 'Home';
    final away = post.predAway ?? 'Away';
    final hs = post.predHomeScore ?? 0;
    final as_ = post.predAwayScore ?? 0;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
            colors: [Color(0xFF182E0E), Color(0xFF071421)]),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF7FD820).withValues(alpha: 0.5)),
      ),
      child: Column(children: [
        Row(children: [
          const Icon(Icons.analytics_outlined, color: Color(0xFF7FD820), size: 16),
          const SizedBox(width: 6),
          const Text('PREDICTION', style: TextStyle(color: Color(0xFF7FD820),
              fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.1)),
        ]),
        const SizedBox(height: 12),
        Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
          Expanded(child: Text(home, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(12)),
            child: Text('$hs  -  $as_',
                style: const TextStyle(color: Colors.white, fontSize: 24,
                    fontWeight: FontWeight.w900, letterSpacing: 3)),
          ),
          Expanded(child: Text(away, textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13))),
        ]),
        if (post.myPrediction != null) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: const Color(0xFF7FD820).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFF7FD820).withValues(alpha: 0.35)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.check_circle_rounded, color: Color(0xFF7FD820), size: 13),
              const SizedBox(width: 5),
              Text('You predicted ${post.myPrediction!.replaceAll('-', ' - ')}',
                  style: const TextStyle(color: Color(0xFF7FD820), fontSize: 11,
                      fontWeight: FontWeight.w600)),
            ]),
          ),
        ],
      ]),
    );
  }
}


// ══ Poll widget for profile Spotlights ════════════════════════════════════════

class _ProfilePollWidget extends StatefulWidget {
  final ProfilePost post;
  const _ProfilePollWidget({required this.post});
  @override State<_ProfilePollWidget> createState() => _ProfilePollWidgetState();
}

class _ProfilePollWidgetState extends State<_ProfilePollWidget> {
  late int? _voted;
  late Map<int,int> _counts;

  @override
  void initState() {
    super.initState();
    _voted = widget.post.myPollVote;
    _counts = Map<int,int>.from(widget.post.pollCounts);
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.post.pollOptions;
    final total = widget.post.pollTotalVotes ?? _counts.values.fold<int>(0, (a,b)=>a+b);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF092B4A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SportSphereColors.electricBlue.withValues(alpha:0.4)),
      ),
      child: Column(crossAxisAlignment:CrossAxisAlignment.start, children:[
        Row(children:[
          const Icon(Icons.poll_rounded, color:SportSphereColors.electricBlue, size:16),
          const SizedBox(width:6),
          const Text('POLL', style:TextStyle(color:SportSphereColors.electricBlue,
              fontSize:11, fontWeight:FontWeight.w800, letterSpacing:1.1)),
          const Spacer(),
          if(total>0) Text('$total vote${total==1?"":"s"}',
              style:const TextStyle(color:SportSphereColors.muted, fontSize:11)),
        ]),
        const SizedBox(height:10),
        ...List.generate(options.length, (i) {
          final count = _counts[i]??0;
          final pct = total>0 ? (count/total*100).round() : 0;
          final voted = _voted==i;
          return Padding(
            padding:const EdgeInsets.only(bottom:8),
            child:GestureDetector(
              onTap:() async {
                if(_voted!=null) return;
                final pollId=widget.post.pollId;
                if(pollId==null){setState(()=>_voted=i);return;}
                try {
                  await Supabase.instance.client.rpc('increment_poll_votes', params:{
                    'p_poll_id':pollId,
                    'p_user_id':Supabase.instance.client.auth.currentUser?.id,
                    'p_option_index':i,
                  });
                  setState((){_voted=i;_counts[i]=(_counts[i]??0)+1;});
                } catch(_){setState(()=>_voted=i);}
              },
              child:Stack(children:[
                Container(height:38, decoration:BoxDecoration(
                  borderRadius:BorderRadius.circular(8),
                  color:Colors.white.withValues(alpha:0.06),
                  border:Border.all(color:voted
                      ?SportSphereColors.electricBlue
                      :Colors.white.withValues(alpha:0.1)),
                )),
                if(_voted!=null) FractionallySizedBox(
                  widthFactor:pct/100,
                  child:Container(height:38, decoration:BoxDecoration(
                    borderRadius:BorderRadius.circular(8),
                    color:voted
                        ?SportSphereColors.electricBlue.withValues(alpha:0.25)
                        :Colors.white.withValues(alpha:0.08),
                  )),
                ),
                Padding(
                  padding:const EdgeInsets.symmetric(horizontal:12,vertical:10),
                  child:Row(children:[
                    if(voted)...[
                      const Icon(Icons.check_circle_rounded,color:SportSphereColors.electricBlue,size:14),
                      const SizedBox(width:6),
                    ],
                    Expanded(child:Text(options[i], style:TextStyle(
                        color:voted?SportSphereColors.electricBlue:SportSphereColors.white,
                        fontSize:13,fontWeight:FontWeight.w600))),
                    if(_voted!=null) Text('$pct%',
                        style:const TextStyle(color:SportSphereColors.muted,fontSize:12)),
                  ]),
                ),
              ]),
            ),
          );
        }),
      ]),
    );
  }
}

// ══ Prediction widget for profile Spotlights ══════════════════════════════════

class _ProfilePredictionWidget extends StatelessWidget {
  final ProfilePost post;
  const _ProfilePredictionWidget({required this.post});
  @override
  Widget build(BuildContext context) {
    final home=post.predHome??'Home';
    final away=post.predAway??'Away';
    final hs=post.predHomeScore??0;
    final as_=post.predAwayScore??0;
    return Container(
      padding:const EdgeInsets.all(16),
      decoration:BoxDecoration(
        gradient:const LinearGradient(colors:[Color(0xFF182E0E),Color(0xFF071421)]),
        borderRadius:BorderRadius.circular(16),
        border:Border.all(color:const Color(0xFF7FD820).withValues(alpha:0.5)),
      ),
      child:Column(children:[
        Row(children:[
          const Icon(Icons.analytics_outlined,color:Color(0xFF7FD820),size:16),
          const SizedBox(width:6),
          const Text('PREDICTION',style:TextStyle(color:Color(0xFF7FD820),
              fontSize:11,fontWeight:FontWeight.w800,letterSpacing:1.1)),
        ]),
        const SizedBox(height:12),
        Row(mainAxisAlignment:MainAxisAlignment.spaceEvenly, children:[
          Expanded(child:Text(home,textAlign:TextAlign.center,
              style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:13))),
          Container(
            padding:const EdgeInsets.symmetric(horizontal:14,vertical:8),
            decoration:BoxDecoration(color:Colors.black.withValues(alpha:0.3),borderRadius:BorderRadius.circular(12)),
            child:Text('$hs  -  $as_',style:const TextStyle(
                color:Colors.white,fontSize:22,fontWeight:FontWeight.w900,letterSpacing:3)),
          ),
          Expanded(child:Text(away,textAlign:TextAlign.center,
              style:const TextStyle(color:Colors.white,fontWeight:FontWeight.w700,fontSize:13))),
        ]),
        if(post.myPrediction!=null)...[
          const SizedBox(height:10),
          Container(
            padding:const EdgeInsets.symmetric(horizontal:10,vertical:5),
            decoration:BoxDecoration(
              color:const Color(0xFF7FD820).withValues(alpha:0.12),
              borderRadius:BorderRadius.circular(20),
              border:Border.all(color:const Color(0xFF7FD820).withValues(alpha:0.35)),
            ),
            child:Row(mainAxisSize:MainAxisSize.min,children:[
              const Icon(Icons.check_circle_rounded,color:Color(0xFF7FD820),size:13),
              const SizedBox(width:5),
              Text('You predicted ${post.myPrediction!.replaceAll('-',' - ')}',
                  style:const TextStyle(color:Color(0xFF7FD820),fontSize:11,fontWeight:FontWeight.w600)),
            ]),
          ),
        ],
      ]),
    );
  }
}
