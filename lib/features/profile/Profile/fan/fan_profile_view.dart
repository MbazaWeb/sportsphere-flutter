import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/branding.dart';
import '../../../../core/data/social_graph.dart';
import '../../../../core/theme/colors.dart';
import '../../presentation/edit_profile_sheet.dart';
import '../../presentation/become_pro_sheet.dart';
import '../../shared/profile_widgets.dart';
import '../../../auth/presentation/auth_controller.dart';
import '../../../home/widgets/sportlights_tab.dart';
import '../../../../core/utils/media_type.dart';
// ══════════════════════════════════════════════════════════════════════════════
// MODEL
// ══════════════════════════════════════════════════════════════════════════════

class FanProfileModel {
  const FanProfileModel({
    required this.firstName,
    required this.lastName,
    required this.handle,
    required this.fanOf,
    required this.fanOfAccent,
    required this.bio,
    required this.sport,
    required this.location,
    required this.joinedDate,
    required this.postCount,
    required this.followerCount,
    required this.followingCount,
    this.email,
    this.avatarAsset,
    this.coverAsset,
    this.isVerified = false,
    this.isOwnProfile = false,
    this.isAdmin = false,
    this.role = 'fan',
  });

  final String firstName;
  final String lastName;
  final String handle;
  final String fanOf;
  final Color fanOfAccent;
  final String bio;
  final String sport;
  final String location;
  final DateTime joinedDate;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final String? email;
  final String? avatarAsset;
  final String? coverAsset;
  final bool isVerified;
  final bool isOwnProfile;

  /// True when this account is an app administrator (role admin/official/
  /// organization/moderator, or matches an admin email). Consumers use this
  /// to role-gate UI like the "Become PRO" button (#3.3).
  final bool isAdmin;

  /// Raw role string from the DB ('fan' | 'player' | 'admin' | 'official' | …).
  final String role;

  String get displayName => '$firstName $lastName';
  String get atHandle => '@$handle';

  String get followerLabel {
    if (followerCount >= 1000) {
      return '${(followerCount / 1000).toStringAsFixed(1)}K';
    }
    return '$followerCount';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class FanProfileView extends StatefulWidget {
  final FanProfileModel profile;

  const FanProfileView({
    super.key,
    required this.profile,
  });

  @override
  State<FanProfileView> createState() => _FanProfileViewState();
}

class _FanProfileViewState extends State<FanProfileView>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;
  bool _following = false;
  bool _followBusy = false;

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: 2, vsync: this);
    _tabCtrl.addListener(() => setState(() {}));
    // Seed the follow toggle from the server (#7.1): we don't want the UI
    // showing "Follow" when the user already follows the target.
    if (!widget.profile.isOwnProfile) {
      _seedFollowState();
    }
  }

  Future<void> _seedFollowState() async {
    try {
      final me = Supabase.instance.client.auth.currentUser?.id;
      if (me == null) return;
      final targetHandle =
          widget.profile.handle.replaceAll('@', '').trim();
      final graph = const SocialGraph();
      final targetId = await graph.resolveId(targetHandle);
      if (targetId == null) return;
      final ok = await graph.isFollowing(me, targetId);
      if (mounted) setState(() => _following = ok);
    } catch (e) {
      debugPrint('[FanProfile] _seedFollowState error: $e');
    }
  }

  /// Toggle follow state — persists to Supabase via SocialGraph, then updates
  /// UI locally. Wrapped in try/catch so a network failure doesn't leave the
  /// button in a flipped state. (#7.1)
  Future<void> _toggleFollow() async {
    if (_followBusy) return;
    HapticFeedback.lightImpact();
    final wasFollowing = _following;
    setState(() {
      _followBusy = true;
      _following = !wasFollowing;
    });
    try {
      final me = Supabase.instance.client.auth.currentUser?.id;
      if (me == null) {
        // Not signed in — revert UI and bail.
        if (mounted) setState(() => _following = wasFollowing);
        return;
      }
      final graph = const SocialGraph();
      final targetId = await graph.resolveId(
          widget.profile.handle.replaceAll('@', '').trim());
      if (targetId == null) throw StateError('profile not found');
      await graph.follow(targetId, on: !wasFollowing);
    } catch (e) {
      debugPrint('[FanProfile] _toggleFollow error: $e');
      if (mounted) setState(() => _following = wasFollowing);
    } finally {
      if (mounted) setState(() => _followBusy = false);
    }
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  FanProfileModel get p => widget.profile;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: SportSphereColors.background,
      body: NestedScrollView(
        headerSliverBuilder: (context, innerScrolled) => [
          SliverToBoxAdapter(
            child: _ProfileHeader(
              profile: p,
              following: _following,
              followBusy: _followBusy,
              onFollow: _toggleFollow,
              onBack: () => Navigator.of(context).maybePop(),
              onMore: () => _showMoreSheet(context),
              onInfo: () => _tabCtrl.animateTo(1),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _TabBarDelegate(
              tabBar: _ProfileTabBar(controller: _tabCtrl),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabCtrl,
          children: [
            _SportlightsFeed(profile: p),
            _AboutTab(profile: p),
          ],
        ),
      ),
    );
  }

  void _showMoreSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (_) => _MoreSheet(isOwnProfile: p.isOwnProfile),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// PROFILE HEADER
// ══════════════════════════════════════════════════════════════════════════════

class _ProfileHeader extends StatelessWidget {
  final FanProfileModel profile;
  final bool following;
  final bool followBusy;
  final Future<void> Function() onFollow;
  final VoidCallback onBack;
  final VoidCallback onMore;
  final VoidCallback onInfo;

  const _ProfileHeader({
    required this.profile,
    required this.following,
    required this.onFollow,
    required this.onBack,
    required this.onMore,
    required this.onInfo,
    this.followBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    const coverH = 180.0;
    const avatarR = 44.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            SizedBox(
              height: coverH,
              width: double.infinity,
              child: profile.coverAsset != null
                  ? (profile.coverAsset!.startsWith('http')
                      ? Image.network(
                          profile.coverAsset!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _CoverGradient(
                            accent: profile.fanOfAccent,
                          ),
                        )
                      : Image.asset(
                          profile.coverAsset!,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _CoverGradient(
                            accent: profile.fanOfAccent,
                          ),
                        ))
                  : _CoverGradient(accent: profile.fanOfAccent),
            ),
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              height: 90,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      SportSphereColors.background.withValues(alpha: 0.95),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              left: 12,
              child: GestureDetector(
                onTap: onBack,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                  child: const Icon(
                    Icons.arrow_back_ios_new_rounded,
                    color: Colors.white,
                    size: 16,
                  ),
                ),
              ),
            ),
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 12,
              child: GestureDetector(
                onTap: onMore,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.black.withValues(alpha: 0.45),
                  ),
                  child: const Icon(
                    Icons.more_horiz_rounded,
                    color: Colors.white,
                    size: 20,
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -(avatarR * 0.5),
              left: 16,
              child: _Avatar(
                asset: profile.avatarAsset,
                radius: avatarR,
                accentColor: profile.fanOfAccent,
              ),
            ),
          ],
        ),
        SizedBox(height: avatarR * 0.5 + 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          profile.displayName,
                          style: const TextStyle(
                            color: SportSphereColors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        if (profile.isVerified) ...[
                          const SizedBox(width: 6),
                          const Icon(
                            Icons.verified_rounded,
                            color: Color(0xFFFFD700),
                            size: 20,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      profile.atHandle,
                      style: const TextStyle(
                        color: SportSphereColors.muted,
                        fontSize: 14,
                      ),
                    ),
                    const SizedBox(height: 6),
                    if (profile.fanOf.isNotEmpty)
                      _FanOfBadge(
                        teamName: profile.fanOf,
                        accent: profile.fanOfAccent,
                      ),
                  ],
                ),
              ),
              GestureDetector(
                onTap: onInfo,
                child: Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.07),
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                  ),
                  child: const Icon(
                    Icons.info_outline_rounded,
                    color: SportSphereColors.muted,
                    size: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _StatsRow(profile: profile),
        ),
        const SizedBox(height: 16),
        if (!profile.isOwnProfile)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _ActionButtons(
              following: following,
              followBusy: followBusy,
              onFollow: onFollow,
              fanOfAccent: profile.fanOfAccent,
            ),
          ),
        if (profile.isOwnProfile)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _EditProfileButton(),
          ),
        // PART H (rules 25-27): "Become Pro" is removed from the main profile
        // face. It now lives inside the Profile Settings sheet (see _SettingsButton
        // below). For admin / official / org / moderator accounts, PRO is hidden
        // entirely (they already have privileged roles).
        if (profile.isOwnProfile)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 4),
            child: _SettingsButton(profile: profile),
          ),
        const SizedBox(height: 4),
      ],
    );
  }
}

class _CoverGradient extends StatelessWidget {
  final Color accent;
  const _CoverGradient({required this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF08111E),
            accent.withValues(alpha: 0.40),
            const Color(0xFF030810),
          ],
        ),
      ),
      child: Center(
        child: Icon(
          Icons.groups_rounded,
          size: 72,
          color: accent.withValues(alpha: 0.18),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? asset;
  final double radius;
  final Color accentColor;
  const _Avatar({required this.asset, required this.radius, required this.accentColor});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: SportSphereColors.background,
        border: Border.all(
          color: SportSphereColors.background,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.30),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: ClipOval(
        child: asset != null
            ? (asset!.startsWith('http')
                ? Image.network(
                    asset!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _AvatarFallback(accent: accentColor),
                  )
                : Image.asset(
                    asset!,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => _AvatarFallback(accent: accentColor),
                  ))
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

class _FanOfBadge extends StatelessWidget {
  final String teamName;
  final Color accent;
  const _FanOfBadge({required this.teamName, required this.accent});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          'Fan of ',
          style: const TextStyle(
            color: SportSphereColors.muted,
            fontSize: 13,
          ),
        ),
        Text(
          teamName,
          style: TextStyle(
            color: accent,
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 5),
        Container(
          width: 18,
          height: 18,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: accent.withValues(alpha: 0.15),
            border: Border.all(color: accent.withValues(alpha: 0.4)),
          ),
          child: Icon(Icons.shield_rounded, color: accent, size: 10),
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  final FanProfileModel profile;
  const _StatsRow({required this.profile});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _Stat(value: '${profile.postCount}', label: 'Posts'),
        _Divider(),
        _Stat(value: profile.followerLabel, label: 'Followers'),
        _Divider(),
        _Stat(value: '${profile.followingCount}', label: 'Following'),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  const _Stat({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: SportSphereColors.white,
            fontSize: 18,
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
    );
  }
}

class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 28,
      margin: const EdgeInsets.symmetric(horizontal: 20),
      color: Colors.white.withValues(alpha: 0.10),
    );
  }
}

class _ActionButtons extends StatelessWidget {
  final bool following;
  final bool followBusy;
  final Future<void> Function() onFollow;
  final Color fanOfAccent;
  const _ActionButtons({
    required this.following,
    required this.onFollow,
    required this.fanOfAccent,
    this.followBusy = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: followBusy ? null : () => onFollow(),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(20),
                gradient: following
                    ? null
                    : const LinearGradient(
                        colors: [
                          SportSphereColors.electricBlue,
                          Color(0xFF0066DD),
                        ],
                      ),
                color: following
                    ? Colors.white.withValues(alpha: 0.06)
                    : null,
                border: following
                    ? Border.all(
                        color: Colors.white.withValues(alpha: 0.18),
                      )
                    : null,
                boxShadow: following
                    ? null
                    : [
                        BoxShadow(
                          color: SportSphereColors.electricBlue
                              .withValues(alpha: 0.30),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
              ),
              child: Center(
                child: followBusy
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        following ? 'Following' : 'Follow',
                        style: TextStyle(
                          color: following
                              ? SportSphereColors.muted
                              : Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {},
          child: Container(
            height: 40,
            width: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withValues(alpha: 0.06),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.14),
              ),
            ),
            child: const Icon(
              Icons.mail_outline_rounded,
              color: SportSphereColors.muted,
              size: 18,
            ),
          ),
        ),
      ],
    );
  }
}

class _EditProfileButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(authControllerProvider).user;
    return GestureDetector(
      onTap: () async {
        if (user != null) {
          await showEditProfileSheet(context, user);
          // Refresh profile from DB so avatar/cover/bio/counts update immediately
          if (context.mounted) {
            await ref.read(authControllerProvider.notifier).refreshProfile();
          }
        }
      },
      child: Container(
        width: double.infinity,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: const Center(
          child: Text(
            'Edit Profile',
            style: TextStyle(
              color: SportSphereColors.white,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _BecomeProButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => showBecomeProSheet(context),
      child: Container(
        width: double.infinity,
        height: 38,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: const LinearGradient(
            colors: [Color(0xFF009DFF), Color(0xFF7B4FFF)],
          ),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.star_rounded, color: Colors.white, size: 16),
              SizedBox(width: 6),
              Text('Become PRO', style: TextStyle(
                  color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// SETTINGS BUTTON + SETTINGS SHEET
// ══════════════════════════════════════════════════════════════════════════════
// PART G (rules 23-24) + PART H (rules 25-27):
//   - Profile provides a Settings entry.
//   - "Become Pro" lives inside Settings, NOT on the main profile face.
//   - Only options actually supported by the current app are shown — no
//     fake settings that do nothing.

class _SettingsButton extends StatelessWidget {
  final FanProfileModel profile;
  const _SettingsButton({required this.profile});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showSettingsSheet(context),
      child: Container(
        width: double.infinity,
        height: 40,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          color: Colors.white.withValues(alpha: 0.06),
          border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
        ),
        child: const Center(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.settings_rounded, color: SportSphereColors.white, size: 16),
              SizedBox(width: 6),
              Text('Settings',
                  style: TextStyle(
                      color: SportSphereColors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }

  void _showSettingsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF071422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                child: Row(
                  children: [
                    const Icon(Icons.settings_rounded, color: SportSphereColors.white),
                    const SizedBox(width: 10),
                    const Text('Settings',
                        style: TextStyle(
                            color: SportSphereColors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w800)),
                    const Spacer(),
                    GestureDetector(
                      onTap: () => Navigator.pop(sheetCtx),
                      child: const Icon(Icons.close_rounded,
                          color: SportSphereColors.muted, size: 22),
                    ),
                  ],
                ),
              ),
              const Divider(color: Colors.white10, height: 1),

              // ── Account ──
              _SettingsTile(
                icon: Icons.person_outline_rounded,
                label: 'Account',
                subtitle: 'Edit profile, handle, email',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  // Re-use the existing Edit Profile flow
                  _openEditProfile(context);
                },
              ),

              // ── Become Pro (hidden for admins/officials — see rule 27) ──
              if (!profile.isAdmin)
                _SettingsTile(
                  icon: Icons.star_rounded,
                  iconColor: const Color(0xFFFFD700),
                  label: 'Become PRO',
                  subtitle: 'Apply for a Pro account',
                  onTap: () {
                    Navigator.pop(sheetCtx);
                    showBecomeProSheet(context);
                  },
                ),

              // ── Notifications (placeholder — no real notification prefs UI exists yet) ──
              _SettingsTile(
                icon: Icons.notifications_outlined,
                label: 'Notifications',
                subtitle: 'Push notification preferences',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Notification preferences coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),

              // ── Privacy ──
              _SettingsTile(
                icon: Icons.lock_outline_rounded,
                label: 'Privacy',
                subtitle: 'Who can see your posts and profile',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Privacy settings coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),

              // ── Security ──
              _SettingsTile(
                icon: Icons.security_outlined,
                label: 'Security',
                subtitle: 'Password and account security',
                onTap: () {
                  Navigator.pop(sheetCtx);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Security settings coming soon'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                },
              ),

              const Divider(color: Colors.white10, height: 1),

              // ── Logout ──
              _SettingsTile(
                icon: Icons.logout_rounded,
                iconColor: const Color(0xFFFF3B30),
                label: 'Log out',
                subtitle: 'Sign out of your account',
                onTap: () async {
                  Navigator.pop(sheetCtx);
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (d) => AlertDialog(
                      backgroundColor: const Color(0xFF071422),
                      title: const Text('Log out?',
                          style: TextStyle(color: SportSphereColors.white)),
                      content: const Text('You will be signed out of this account.',
                          style: TextStyle(color: SportSphereColors.muted)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(d, false),
                            child: const Text('Cancel')),
                        TextButton(
                            onPressed: () => Navigator.pop(d, true),
                            child: const Text('Log out',
                                style: TextStyle(color: Color(0xFFFF3B30)))),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    // Use the same auth controller flow that the rest of the app uses
                    final container = ProviderScope.containerOf(context, listen: false);
                    await container.read(authControllerProvider.notifier).signOut();
                  }
                },
              ),

              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  void _openEditProfile(BuildContext context) async {
    // The Edit Profile sheet requires a ConsumerWidget context to read the
    // auth controller. We use ProviderScope.containerOf to get the user
    // without needing a WidgetRef.
    final container = ProviderScope.containerOf(context, listen: false);
    final user = container.read(authControllerProvider).user;
    if (user != null) {
      await showEditProfileSheet(context, user);
      await container.read(authControllerProvider.notifier).refreshProfile();
    }
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String label;
  final String? subtitle;
  final VoidCallback? onTap;
  const _SettingsTile({
    required this.icon,
    this.iconColor,
    required this.label,
    this.subtitle,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon, color: iconColor ?? const Color(0xFF168CFF)),
      title: Text(label,
          style: const TextStyle(
              color: SportSphereColors.white, fontWeight: FontWeight.w600)),
      subtitle: subtitle != null
          ? Text(subtitle!,
              style: const TextStyle(color: SportSphereColors.muted, fontSize: 12))
          : null,
      trailing: const Icon(Icons.chevron_right_rounded, color: SportSphereColors.muted),
      onTap: onTap,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// TAB BAR
// ══════════════════════════════════════════════════════════════════════════════

class _ProfileTabBar extends StatelessWidget {
  final TabController controller;
  const _ProfileTabBar({required this.controller});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: SportSphereColors.background,
      child: TabBar(
        controller: controller,
        labelColor: SportSphereColors.white,
        unselectedLabelColor: SportSphereColors.muted,
        labelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
        unselectedLabelStyle: const TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w500,
        ),
        indicator: UnderlineTabIndicator(
          borderSide: const BorderSide(
            color: SportSphereColors.sportGreen,
            width: 2.5,
          ),
          borderRadius: BorderRadius.circular(4),
          insets: const EdgeInsets.symmetric(horizontal: 20),
        ),
        tabs: const [
          Tab(text: 'Spotlights'),
          Tab(text: 'About'),
        ],
      ),
    );
  }
}

class _TabBarDelegate extends SliverPersistentHeaderDelegate {
  final Widget tabBar;
  const _TabBarDelegate({required this.tabBar});

  @override
  double get minExtent => 48;
  @override
  double get maxExtent => 48;

  @override
  Widget build(BuildContext context, double shrinkOffset, bool overlaps) {
    return tabBar;
  }

  @override
  bool shouldRebuild(_TabBarDelegate old) => false;
}

// ══════════════════════════════════════════════════════════════════════════════
// SPOTLIGHTS FEED TAB
// ══════════════════════════════════════════════════════════════════════════════

class _SportlightsFeed extends StatefulWidget {
  final FanProfileModel profile;
  const _SportlightsFeed({required this.profile});
  @override
  State<_SportlightsFeed> createState() => _SportlightsFeedState();
}

class _SportlightsFeedState extends State<_SportlightsFeed> {
  List<SpotlightItem> _items = [];
  bool _loading = true;

  @override
  void initState() { super.initState(); _fetchPosts(); }

  Future<void> _fetchPosts() async {
    setState(() => _loading = true);
    try {
      final handle = widget.profile.handle.replaceAll('@', '').trim();
      final ids = <String>{};

      // Resolve user id from User table by handle
      try {
        final rows = await Supabase.instance.client
            .from('User').select('id').ilike('handle', handle);
        for (final r in rows as List) {
          final id = (r as Map)['id']?.toString();
          if (id != null) ids.add(id);
        }
      } catch (_) {}
      try {
        final rows = await Supabase.instance.client
            .from('profiles').select('id').ilike('handle', handle);
        for (final r in rows as List) {
          final id = (r as Map)['id']?.toString();
          if (id != null) ids.add(id);
        }
      } catch (_) {}

      // Always include auth uid for own profile
      if (widget.profile.isOwnProfile) {
        final authId = Supabase.instance.client.auth.currentUser?.id;
        if (authId != null) ids.add(authId);
      }

      if (ids.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }

      final idList = ids.toList();
      List rows;
      try {
        rows = await Supabase.instance.client
            .from('Post').select()
            .inFilter('userId', idList)
            .order('createdAt', ascending: false)
            .limit(40) as List;
      } catch (_) {
        rows = [];
        for (final id in idList) {
          try {
            final part = await Supabase.instance.client
                .from('Post').select().eq('userId', id)
                .order('createdAt', ascending: false).limit(40);
            rows.addAll(List<Map<String,dynamic>>.from(part as List));
          } catch (_) {}
        }
        final seen = <String>{};
        final deduped = <Map<String,dynamic>>[];
        for (final r in rows) {
          final pid = (r as Map)['id']?.toString() ?? '';
          if (seen.add(pid)) deduped.add(Map<String,dynamic>.from(r));
        }
        rows = deduped;
      }

      // Build SpotlightItems — reuse the same model as the home feed
      final items = <SpotlightItem>[];
      for (final raw in rows) {
        final r = Map<String,dynamic>.from(raw as Map);
        final postType = (r['postType'] as String?) ?? 'text';
        final media = r['mediaUrls'] ?? r['media_urls'];
        String? asset;
        if (media is List && media.isNotEmpty) asset = media.first.toString();
        else if (media is String && media.isNotEmpty) asset = media;

        String? pollId;
        List<String> pollOptions = [];
        int? pollVotes, myVote;
        Map<int,int> pollCounts = {};
        String? predHome, predAway;
        int? predHs, predAs;

        if (postType == 'poll') {
          try {
            final poll = await Supabase.instance.client
                .from('Poll').select().eq('postId', r['id']).maybeSingle();
            if (poll != null) {
              pollId = poll['id']?.toString();
              final opts = poll['options'];
              if (opts is List) pollOptions = opts.map((e) => e.toString()).toList();
              pollVotes = poll['totalVotes'] as int?;
              final me = Supabase.instance.client.auth.currentUser?.id;
              if (me != null && pollId != null) {
                final v = await Supabase.instance.client.from('PollVote')
                    .select().eq('pollId', pollId).eq('userId', me).maybeSingle();
                myVote = v?['optionIdx'] as int?;
                final allVotes = await Supabase.instance.client
                    .from('PollVote').select('optionIdx').eq('pollId', pollId);
                for (final vr in allVotes as List) {
                  final idx = (vr as Map)['optionIdx'] as int?;
                  if (idx != null) pollCounts[idx] = (pollCounts[idx] ?? 0) + 1;
                }
              }
            }
          } catch (_) {}
        }

        if (postType == 'prediction') {
          try {
            final pred = await Supabase.instance.client
                .from('Prediction').select().eq('postId', r['id']).maybeSingle();
            if (pred != null) {
              predHome = pred['homeTeam'] as String?;
              predAway = pred['awayTeam'] as String?;
              predHs = pred['predictedHome'] as int?;
              predAs = pred['predictedAway'] as int?;
            }
          } catch (_) {}
        }

        // Determine SpotlightType using public helper from sportlights_tab
        final type = spotlightTypeFromPostType(postType, assetUrl: asset);

        final createdAt = r['createdAt'] ?? r['created_at'];
        final dt = DateTime.tryParse(createdAt?.toString() ?? '')?.toLocal();
        String age = '';
        if (dt != null) {
          final d = DateTime.now().difference(dt);
          if (d.inMinutes < 1) age = 'now';
          else if (d.inMinutes < 60) age = '${d.inMinutes}m';
          else if (d.inHours < 24) age = '${d.inHours}h';
          else if (d.inDays < 7) age = '${d.inDays}d';
          else age = '${dt.day}/${dt.month}';
        }

        items.add(SpotlightItem(
          type: type,
          author: widget.profile.displayName,
          role: widget.profile.role,
          handle: widget.profile.handle,
          postId: r['id']?.toString(),
          matchId: (r['matchId'] ?? r['match_id'])?.toString(),
          age: age,
          asset: asset,
          likes: (r['likeCount'] as int?) ?? 0,
          comments: (r['commentCount'] as int?) ?? 0,
          shares: (r['shareCount'] as int?) ?? 0,
          accent: widget.profile.fanOfAccent,
          content: (r['content'] as String?) ?? '',
          pollId: pollId,
          pollOptions: pollOptions,
          pollTotalVotes: pollVotes,
          myPollVote: myVote,
          pollCounts: pollCounts,
          predHome: predHome,
          predAway: predAway,
          predHomeScore: predHs,
          predAwayScore: predAs,
          myPrediction: (predHs != null && predAs != null) ? '$predHs-$predAs' : null,
        ));
      }

      if (mounted) setState(() { _items = items; _loading = false; });
    } catch (e) {
      debugPrint('[SportlightsFeed] error: $e');
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator(
          color: SportSphereColors.electricBlue, strokeWidth: 2));
    }
    if (_items.isEmpty) {
      return Center(child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.bolt_rounded, size: 48,
              color: widget.profile.fanOfAccent.withValues(alpha: 0.35)),
          const SizedBox(height: 16),
          const Text('No posts yet',
              style: TextStyle(color: SportSphereColors.white,
                  fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Text('Posts from ${widget.profile.displayName} will appear here.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: SportSphereColors.muted, fontSize: 14)),
        ]),
      ));
    }

    return RefreshIndicator(
      onRefresh: _fetchPosts,
      color: SportSphereColors.electricBlue,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 120),
        itemCount: _items.length,
        itemBuilder: (_, i) => SpotlightCard(
          item: _items[i],
          isAdmin: widget.profile.isAdmin,
        ),
      ),
    );
  }
}

class _AboutTab extends StatelessWidget {
  final FanProfileModel profile;
  const _AboutTab({required this.profile});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      children: [
        if (profile.bio.isNotEmpty) ...[
          _AboutSection(
            title: 'Bio',
            child: Text(
              profile.bio,
              style: const TextStyle(
                color: SportSphereColors.white,
                fontSize: 15,
                height: 1.5,
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        _AboutSection(
          title: 'Details',
          child: Column(
            children: [
              if (profile.fanOf.isNotEmpty)
                _AboutRow(
                  icon: Icons.favorite_rounded,
                  iconColor: profile.fanOfAccent,
                  label: 'Fan of',
                  value: profile.fanOf,
                  valueColor: profile.fanOfAccent,
                ),
              _AboutRow(
                icon: Icons.sports_soccer_rounded,
                iconColor: SportSphereColors.electricBlue,
                label: 'Favourite sport',
                value: profile.sport,
              ),
              if (profile.location.isNotEmpty)
                _AboutRow(
                  icon: Icons.place_rounded,
                  iconColor: SportSphereColors.sportOrange,
                  label: 'Location',
                  value: profile.location,
                ),
              if (profile.isOwnProfile && (profile.email?.isNotEmpty ?? false))
                _AboutRow(
                  icon: Icons.email_outlined,
                  iconColor: SportSphereColors.brightBlue,
                  label: 'Email',
                  value: profile.email!,
                ),
              _AboutRow(
                icon: Icons.calendar_today_rounded,
                iconColor: SportSphereColors.sportGreen,
                label: 'Joined SportSphere',
                value: DateFormat('MMMM yyyy').format(profile.joinedDate),
                isLast: true,
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AboutSection extends StatelessWidget {
  final String title;
  final Widget child;
  const _AboutSection({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xD0071422),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.07),
        ),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: TextStyle(
              color: SportSphereColors.muted.withValues(alpha: 0.7),
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.1,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _AboutRow extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final Color? valueColor;
  final bool isLast;

  const _AboutRow({
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
                child: Text(
                  label,
                  style: const TextStyle(
                    color: SportSphereColors.muted,
                    fontSize: 13,
                  ),
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: valueColor ?? SportSphereColors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(
            height: 1,
            color: Colors.white.withValues(alpha: 0.06),
          ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
// MORE SHEET
// ══════════════════════════════════════════════════════════════════════════════

class _MoreSheet extends ConsumerWidget {
  final bool isOwnProfile;
  const _MoreSheet({required this.isOwnProfile});

  Future<void> _doLogout(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        backgroundColor: const Color(0xFF0C1A2A),
        title: const Text('Log Out', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure you want to log out?', style: TextStyle(color: Color(0xFF8A9BB0))),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel', style: TextStyle(color: Color(0xFF8A9BB0)))),
          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Log Out', style: TextStyle(color: SportSphereColors.danger))),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(authControllerProvider.notifier).signOut();
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
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
          if (isOwnProfile) ...[
            _SheetOption(icon: Icons.edit_outlined, label: 'Edit Profile', onTap: () => Navigator.pop(context)),
            _SheetOption(icon: Icons.share_outlined, label: 'Share Profile', onTap: () => Navigator.pop(context)),
            _SheetOption(icon: Icons.qr_code_rounded, label: 'QR Code', onTap: () => Navigator.pop(context)),
            const SizedBox(height: 8),
            Container(
              height: 1,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              color: Colors.white.withValues(alpha: 0.08),
            ),
            const SizedBox(height: 8),
            _SheetOption(
              icon: Icons.logout_rounded,
              label: 'Log Out',
              isDestructive: true,
              onTap: () {
                Navigator.pop(context);
                _doLogout(context, ref);
              },
            ),
          ] else ...[
            _SheetOption(icon: Icons.share_outlined, label: 'Share Profile', onTap: () => Navigator.pop(context)),
            _SheetOption(icon: Icons.block_rounded, label: 'Block', onTap: () => Navigator.pop(context)),
            _SheetOption(icon: Icons.flag_outlined, label: 'Report', onTap: () => Navigator.pop(context), isDestructive: true),
          ],
        ],
      ),
    );
  }
}

class _SheetOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;
  const _SheetOption({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? SportSphereColors.danger : SportSphereColors.white;
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14),
        child: Row(
          children: [
            Icon(icon, color: color, size: 22),
            const SizedBox(width: 16),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}