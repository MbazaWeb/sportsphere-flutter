import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/theme/colors.dart';

// ══════════════════════════════════════════════════════════════════════════════
// SHARED PROFILE WIDGETS
// Used by FanProfileView, PlayerProfileView, and future role profiles
// ══════════════════════════════════════════════════════════════════════════════

// ── Post model ─────────────────────────────────────────────────────────────────

class ProfilePost {
  final String text;
  final List<String> hashtags;
  final String timeAgo;
  final int likes;
  final int comments;
  final int shares;
  final bool hasImage;
  final int imageCount;
  final bool hasVideo;

  const ProfilePost({
    required this.text,
    required this.hashtags,
    required this.timeAgo,
    required this.likes,
    required this.comments,
    required this.shares,
    this.hasImage = false,
    this.imageCount = 1,
    this.hasVideo = false,
  });
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
        child: asset != null
            ? Image.asset(asset!, fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _AvatarFallback(accent: accentColor))
            : _AvatarFallback(accent: accentColor),
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
  const ProfileStat({super.key, required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value,
            style: const TextStyle(
              color: SportSphereColors.white,
              fontSize: 17,
              fontWeight: FontWeight.w900,
            )),
        const SizedBox(height: 1),
        Text(label,
            style: const TextStyle(
              color: SportSphereColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w500,
            )),
      ],
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
                    onTap: () {},
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

            // Media
            if (post.hasImage) ...[
              const SizedBox(height: 12),
              PostMedia(
                imageCount: post.imageCount,
                hasVideo: post.hasVideo,
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
                _EngagementBtn(icon: Icons.chat_bubble_outline_rounded, label: formatCount(post.comments), semantics: 'Comment'),
                const SizedBox(width: 20),
                _EngagementBtn(icon: Icons.insights_rounded, label: 'Predict', semantics: 'Predict'),
                const Spacer(),
                _EngagementBtn(icon: Icons.ios_share_rounded, label: 'Share', semantics: 'Share'),
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
  final IconData icon;
  final String label;
  final String semantics;
  const _EngagementBtn({
    required this.icon,
    required this.label,
    required this.semantics,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: semantics,
      button: true,
      child: GestureDetector(
        onTap: () {},
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
