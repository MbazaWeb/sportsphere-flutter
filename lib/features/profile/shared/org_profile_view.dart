import '../../../core/data/vps_repository.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';
import 'person_profile_view.dart' show PersonAboutField;
export 'person_profile_view.dart' show PersonAboutField;

// ── OrgProfileModel ────────────────────────────────────────────────────────────

class OrgProfileModel {
  const OrgProfileModel({
    this.id = '',
    required this.name,
    required this.handle,
    this.roleName = '',
    this.roleColor = const Color(0xFF009DFF),
    this.accentColor = const Color(0xFF009DFF),
    this.bio = '',
    this.logoAsset,
    this.avatarUrl,
    this.coverUrl,
    this.location = '',
    this.joinedDate,
    this.isVerified = false,
    this.postCount = 0,
    this.fanCount = 0,
    this.followingCount = 0,
    this.aboutFields = const [],
    this.membersLabel = 'Members',
    this.headerTrailing,
  });

  final String id;
  final String name;
  final String handle;
  final String roleName;
  final Color roleColor;
  final Color accentColor;
  final String bio;
  final String? logoAsset;
  final String? avatarUrl;   // Network URL for avatar image
  final String? coverUrl;    // Network URL for cover image
  final String location;
  final DateTime? joinedDate;
  final bool isVerified;
  final int postCount;
  final int fanCount;
  final int followingCount;
  final List<PersonAboutField> aboutFields;
  final String membersLabel;
  final Widget? headerTrailing; // e.g. Join/Leave button
}

// ── OrgProfileView ─────────────────────────────────────────────────────────────

class OrgProfileView extends StatefulWidget {
  final OrgProfileModel profile;
  const OrgProfileView({super.key, required this.profile});
  @override
  State<OrgProfileView> createState() => _OrgProfileViewState();
}

class _OrgProfileViewState extends State<OrgProfileView> {
  List<Map<String, dynamic>> _posts = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPosts();
  }

  Future<void> _fetchPosts() async {
    try {
      final profile = await const VpsRepository().getProfile(widget.profile.handle);
      final uid = profile['id']?.toString() ?? '';
      if (uid.isEmpty) { if (mounted) setState(() => _loading = false); return; }
      final posts = await const VpsRepository().getUserPosts(uid, limit: 30);
      if (mounted) {
        setState(() {
          _posts = posts;
          _loading = false;
        });
      }
    } catch (_) { if (mounted) setState(() => _loading = false); }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return Scaffold(
      backgroundColor: PlayifyColors.background,
      body: SafeArea(child: Column(children: [
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: PlayifyColors.white),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            CircleAvatar(
              radius: 28,
              backgroundColor: p.accentColor.withValues(alpha: 0.15),
              backgroundImage: p.avatarUrl != null ? NetworkImage(p.avatarUrl!) : null,
              child: p.avatarUrl == null
                  ? Icon(Icons.corporate_fare_rounded, color: p.accentColor)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(p.name, style: const TextStyle(color: PlayifyColors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                if (p.isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, color: Color(0xFFFFD700), size: 16)],
              ]),
              Text('@${p.handle}  ·  ${p.roleName}', style: const TextStyle(color: PlayifyColors.muted, fontSize: 12)),
            ])),
            if (p.headerTrailing != null) ...[const SizedBox(width: 8), p.headerTrailing!],
          ]),
        ),
        Expanded(child: _loading
            ? const Center(child: CircularProgressIndicator(color: PlayifyColors.electricBlue, strokeWidth: 2))
            : _posts.isEmpty
                ? const Center(child: Text('No posts yet', style: TextStyle(color: PlayifyColors.muted)))
                : RefreshIndicator(
                    onRefresh: _fetchPosts,
                    color: PlayifyColors.electricBlue,
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 80),
                      itemCount: _posts.length,
                      separatorBuilder: (_, __) => Divider(height: 1, color: Colors.white.withValues(alpha: 0.06)),
                      itemBuilder: (_, i) {
                        final post = _posts[i];
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text((post['content'] as String?) ?? '', style: const TextStyle(color: PlayifyColors.white, fontSize: 14)),
                        );
                      },
                    ),
                  )),
      ])),
    );
  }
}
