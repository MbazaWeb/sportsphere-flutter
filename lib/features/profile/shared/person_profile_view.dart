import '../../../core/data/vps_repository.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/colors.dart';

// ── PersonProfileModel ─────────────────────────────────────────────────────────

class PersonProfileModel {
  const PersonProfileModel({
    this.id = '',
    required this.name,
    required this.handle,
    this.roleName = '',
    this.roleColor = const Color(0xFF009DFF),
    this.accentColor = const Color(0xFF009DFF),
    this.bio = '',
    this.avatarUrl,
    this.location = '',
    this.joinedDate,
    this.isVerified = false,
    this.hasFanOption = false,
    this.postCount = 0,
    this.followerCount = 0,
    this.followingCount = 0,
    this.aboutFields = const [],
  });

  final String id;
  final String name;
  final String handle;
  final String roleName;
  final Color roleColor;
  final Color accentColor;
  final String bio;
  final String? avatarUrl;
  final String location;
  final DateTime? joinedDate;
  final bool isVerified;
  final bool hasFanOption;
  final int postCount;
  final int followerCount;
  final int followingCount;
  final List<PersonAboutField> aboutFields;
}

// ── PersonAboutField ───────────────────────────────────────────────────────────

class PersonAboutField {
  const PersonAboutField({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
}

// ── PersonProfileView ──────────────────────────────────────────────────────────

class PersonProfileView extends StatefulWidget {
  const PersonProfileView({super.key, required this.profile});
  final PersonProfileModel profile;
  @override
  State<PersonProfileView> createState() => _PersonProfileViewState();
}

class _PersonProfileViewState extends State<PersonProfileView> {
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
      if (profile == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
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
        // Header
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
              child: p.avatarUrl == null ? Icon(Icons.person_rounded, color: p.accentColor) : null,
            ),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text(p.name, style: const TextStyle(color: PlayifyColors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                if (p.isVerified) ...[const SizedBox(width: 4), const Icon(Icons.verified_rounded, color: Color(0xFFFFD700), size: 16)],
              ]),
              Text('@${p.handle}  ·  ${p.roleName}', style: const TextStyle(color: PlayifyColors.muted, fontSize: 12)),
            ])),
          ]),
        ),
        // Posts
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
                        final content = (post['content'] as String?) ?? '';
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(content, style: const TextStyle(color: PlayifyColors.white, fontSize: 14)),
                        );
                      },
                    ),
                  )),
      ])),
    );
  }
}
