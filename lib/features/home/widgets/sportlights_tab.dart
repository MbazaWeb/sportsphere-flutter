import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/admin/app_admin.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/data/social_graph.dart';
import '../../../core/data/social_repository.dart';
import '../../../core/data/commerce_repository.dart';
import '../../../core/theme/colors.dart';
import '../../auth/presentation/auth_controller.dart';
import '../../shell/media/media_tools.dart';
import '../../shell/media/pdf_viewer_page.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/branding.dart';
import '../../../core/utils/friendly_error.dart';
import '../../../core/utils/media_type.dart';

// ============================================================
// ROLE CONFIGURATION
// ============================================================
//
// Controls which action buttons appear on a post card.
//
// hasFanOption   → shows "Become Fan" (secondary) + "Follow" (primary)
// followOnly     → shows only "Follow" (full-width)
// community      → shows "Join Community" (full-width)
// commerce       → shows commerce-specific buttons (Buy Now, Watch, etc.)
// poll/prediction/video → their own fixed buttons
//
// To add a new role: add it to the appropriate set below.
// ============================================================

enum _SpotlightType {
  team,
  player,
  coach,
  scout,
  agent,
  academy,
  // "follow only" roles — no fan option
  journalist,
  analyst,
  commentator,
  creator,
  moderator,
  official,
  organization,
  league,
  competition,
  // community origin
  community,
  fan,
  // commerce
  business,
  sponsor,
  commercialPartner,
  venue,
  // content types
  match,
  video,
  poll,
  prediction,
  liveCoverage,
}

/// Roles where "Become Fan" appears alongside "Follow".
const _fanRoles = {
  _SpotlightType.team,
  _SpotlightType.player,
  _SpotlightType.coach,
  _SpotlightType.scout,
  _SpotlightType.agent,
  _SpotlightType.academy,
};

/// Roles that only show "Follow" — no fan option.
const _followOnlyRoles = {
  _SpotlightType.journalist,
  _SpotlightType.analyst,
  _SpotlightType.commentator,
  _SpotlightType.creator,
  _SpotlightType.moderator,
  _SpotlightType.official,
  _SpotlightType.organization,
  _SpotlightType.league,
  _SpotlightType.competition,
  _SpotlightType.fan,
};

/// Community-origin posts — show "Join Community".
const _communityRoles = {
  _SpotlightType.community,
};

/// Commerce roles — show "Buy Now" / "Shop" buttons.
const _commerceRoles = {
  _SpotlightType.business,
  _SpotlightType.sponsor,
  _SpotlightType.commercialPartner,
  _SpotlightType.venue,
};

// ============================================================
// MODEL
// ============================================================

class _SpotlightItem {
  final _SpotlightType type;
  final String author;
  final String role;
  final String handle;
  final String? targetUserId;
  final String? postId;
  final String age;
  final String? asset;
  final int likes;
  final int comments;
  final int shares;
  final Color accent;
  final String? content;
  final String? pollId;
  final List<String> pollOptions;
  final int? pollTotalVotes;
  final int? myPollVote;
  final Map<int, int> pollCounts;
  final String? predHome;
  final String? predAway;
  final int? predHomeScore;
  final int? predAwayScore;
  final String? myPrediction;  // "homeScore-awayScore" if current user already predicted

  const _SpotlightItem({
    required this.type,
    required this.author,
    required this.role,
    this.handle = 'playify',
    this.targetUserId,
    this.postId,
    required this.age,
    this.asset,
    required this.likes,
    required this.comments,
    required this.shares,
    required this.accent,
    this.content,
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
  });

  String get profilePath {
    final h = handle.replaceAll('@', '');
    switch (type) {
      case _SpotlightType.team:
        return '/team/$h';
      case _SpotlightType.player:
        return '/player/$h';
      case _SpotlightType.coach:
        return '/role/coach/$h';
      case _SpotlightType.scout:
        return '/role/scout/$h';
      case _SpotlightType.agent:
        return '/role/agent/$h';
      case _SpotlightType.journalist:
        return '/role/journalist/$h';
      case _SpotlightType.analyst:
        return '/role/analyst/$h';
      case _SpotlightType.commentator:
        return '/role/commentator/$h';
      case _SpotlightType.creator:
        return '/role/creator/$h';
      case _SpotlightType.moderator:
        return '/role/moderator/$h';
      case _SpotlightType.official:
        return '/role/official/$h';
      case _SpotlightType.organization:
        return '/role/organization/$h';
      case _SpotlightType.league:
        return '/role/league/$h';
      case _SpotlightType.community:
        return '/role/community/$h';
      case _SpotlightType.business:
        return '/role/business/$h';
      case _SpotlightType.sponsor:
        return '/role/sponsor/$h';
      case _SpotlightType.fan:
        return '/profile/$h';
      default:
        return '/role/${role.toLowerCase()}/$h';
    }
  }
}

// ============================================================
final _feedItems = <_SpotlightItem>[];

// ============================================================
// MAIN WIDGET
// ============================================================

String _handleFromTeamTag(String? tag) {
  if (tag == null || tag.isEmpty) return 'simba_sc';
  final raw = tag.replaceFirst('tm-', '').replaceAll('-', '_');
  const aliases = {
    'simba': 'simba_sc',
    'yanga': 'yanga_sc',
    'azam': 'azam_fc',
  };
  return aliases[raw] ?? raw;
}

_SpotlightType _typeForRole(String role) {
  switch (role.toLowerCase()) {
    case 'team':
      return _SpotlightType.team;
    case 'player':
      return _SpotlightType.player;
    case 'coach':
      return _SpotlightType.coach;
    case 'official':
      return _SpotlightType.official;
    case 'organization':
      return _SpotlightType.organization;
    case 'fan':
      return _SpotlightType.fan;
    default:
      return _SpotlightType.official;
  }
}

class SportlightsTab extends StatefulWidget {
  const SportlightsTab({super.key});

  @override
  State<SportlightsTab> createState() => _SportlightsTabState();
}

class _SportlightsTabState extends State<SportlightsTab> {
  bool _isAdmin = false;
  bool _loading = true;
  String? _loadError;
  final ScrollController _scrollController = ScrollController();
  List<_SpotlightItem> _live = const [];
  RealtimeChannel? _channel;

  @override
  void initState() {
    super.initState();
    AppAdmin.resolveIsAdmin().then((v) {
      if (mounted) setState(() => _isAdmin = v);
    });
    _loadPosts();
    _channel = Supabase.instance.client
        .channel('public-post')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'Post',
          callback: (_) => _loadPosts(silent: true),
        )
        .subscribe();
  }

  /// Batch-load profiles for all author IDs in one query (avoids N+1 delay).
  Future<Map<String, Map<String, dynamic>>> _batchProfiles(
      List<String> uids) async {
    final out = <String, Map<String, dynamic>>{};
    if (uids.isEmpty) return out;
    final unique = uids.toSet().toList();
    try {
      final rows = await Supabase.instance.client
          .from('profiles')
          .select('id, handle, first_name, last_name, role')
          .inFilter('id', unique);
      for (final r in rows as List) {
        final m = Map<String, dynamic>.from(r as Map);
        final id = m['id']?.toString();
        if (id != null) out[id] = m;
      }
    } catch (e) {
      debugPrint('batch profiles: $e');
      try {
        final rows = await Supabase.instance.client
            .from('User')
            .select('id, handle, first_name, last_name, role, name')
            .inFilter('id', unique);
        for (final r in rows as List) {
          final m = Map<String, dynamic>.from(r as Map);
          final id = m['id']?.toString();
          if (id != null) out[id] = m;
        }
      } catch (e2) {
        debugPrint('batch User profiles: $e2');
      }
    }
    return out;
  }

  Future<void> _loadPosts({bool silent = false}) async {
    if (!silent && mounted) {
      setState(() {
        _loading = true;
        _loadError = null;
      });
    }
    try {
      final rows = await SocialRepository().feedForUser();
      debugPrint('sportlights feed rows: ${rows.length}');

      // Collect author ids for one batched lookup
      final uids = <String>[];
      for (final raw in rows) {
        final r = Map<String, dynamic>.from(raw);
        final uid = (r['userId'] ?? r['authorId'] ?? r['user_id'])?.toString();
        if (uid != null && uid.isNotEmpty) uids.add(uid);
      }
      final profiles = await _batchProfiles(uids);

      final items = <_SpotlightItem>[];
      for (final raw in rows) {
        final r = Map<String, dynamic>.from(raw);
        final media = r['mediaUrls'] ?? r['media_urls'];
        String? asset;
        if (media is List && media.isNotEmpty) {
          asset = media.first.toString();
        } else if (media is String && media.isNotEmpty) {
          asset = media;
        }

        final uid =
            (r['userId'] ?? r['authorId'] ?? r['user_id'])?.toString();
        String author = 'Playify Official';
        String handle = 'playify';
        String roleLabel = (r['postType'] as String?) ??
            (r['post_type'] as String?) ??
            'Official';
        var type = _SpotlightType.official;

        if (uid != null && profiles.containsKey(uid)) {
          final p = profiles[uid]!;
          handle = (p['handle'] as String?) ?? handle;
          final fn = p['first_name'] as String? ?? '';
          final ln = p['last_name'] as String? ?? '';
          final name = '$fn $ln'.trim();
          final full = (p['name'] as String?)?.trim();
          if (name.isNotEmpty) {
            author = name;
          } else if (full != null && full.isNotEmpty) {
            author = full;
          } else if (handle.isNotEmpty) {
            author = handle;
          }
          roleLabel = (p['role'] as String?) ?? roleLabel;
          type = _typeForRole(roleLabel);
        }

        final postType = (r['postType'] as String?) ??
            (r['post_type'] as String?) ??
            '';
        final teamTag = r['teamTag']?.toString() ?? r['team_tag']?.toString();
        String? targetUserId = uid;

        if (postType == 'live_coverage') {
          type = _SpotlightType.liveCoverage;
          roleLabel = 'LIVE';
        } else if (postType == 'welcome' ||
            (teamTag != null &&
                teamTag.isNotEmpty &&
                !teamTag.startsWith('match:'))) {
          type = _SpotlightType.team;
          roleLabel = 'Team';
          handle = _handleFromTeamTag(teamTag);
        } else if (postType == 'poll') {
          type = _SpotlightType.poll;
        } else if (postType == 'prediction') {
          type = _SpotlightType.prediction;
        } else if (postType == 'video' ||
            (postType == 'media' && isVideoMediaUrl(asset))) {
          type = _SpotlightType.video;
        } else if (postType == 'image' ||
            (postType == 'media' && asset != null && asset.isNotEmpty)) {
          // Keep role-based type for author badge; media still shows as image
          // via _MediaArea default branch when not video.
        }

        final contentText = (r['content'] as String?) ?? '';

        // Poll / prediction enrichment (best-effort, non-blocking failures)
        String? pollId;
        List<String>? pollOptions;
        int? pollVotes;
        int? myVote;
        Map<int, int>? pollCountsMap;
        String? predHome;
        String? predAway;
        int? predHs;
        int? predAs;

        if (postType == 'poll' || type == _SpotlightType.poll) {
          type = _SpotlightType.poll;
          try {
            final poll = await Supabase.instance.client
                .from('Poll')
                .select()
                .eq('postId', r['id'])
                .maybeSingle();
            if (poll != null) {
              pollId = poll['id']?.toString();
              final opts = poll['options'];
              if (opts is List) {
                pollOptions = opts.map((e) => e.toString()).toList();
              }
              pollVotes = poll['totalVotes'] as int?;
              final me = Supabase.instance.client.auth.currentUser?.id;
              if (me != null && pollId != null) {
                final v = await Supabase.instance.client
                    .from('PollVote')
                    .select()
                    .eq('pollId', pollId)
                    .eq('userId', me)
                    .maybeSingle();
                myVote = v?['optionIdx'] as int?;
              }
              try {
                if (pollId != null) {
                  pollCountsMap =
                      await SocialRepository().pollOptionCounts(pollId);
                }
              } catch (e) {
                debugPrint('poll counts: $e');
              }
            }
          } catch (e) {
            debugPrint('poll load: $e');
          }
        }

        if (postType == 'prediction' || type == _SpotlightType.prediction) {
          type = _SpotlightType.prediction;
          try {
            final pred = await Supabase.instance.client
                .from('Prediction')
                .select()
                .eq('postId', r['id'])
                .maybeSingle();
            if (pred != null) {
              predHome = pred['homeTeam'] as String?;
              predAway = pred['awayTeam'] as String?;
              predHs = pred['predictedHome'] as int?;
              predAs = pred['predictedAway'] as int?;
            }
            // Load current user's prediction for this post
            final me2 = Supabase.instance.client.auth.currentUser?.id;
            if (me2 != null) {
              try {
                final myPred = await Supabase.instance.client
                    .from('Prediction')
                    .select('predictedHome, predictedAway')
                    .eq('postId', r['id'])
                    .eq('userId', me2)
                    .maybeSingle();
                if (myPred != null) {
                  final ph = myPred['predictedHome'];
                  final pa = myPred['predictedAway'];
                  predHs ??= ph as int?;
                  predAs ??= pa as int?;
                }
              } catch (_) {}
            }
          } catch (e) {
            debugPrint('prediction load: $e');
          }
        }

        items.add(_SpotlightItem(
          type: type,
          author: author,
          handle: handle,
          targetUserId: targetUserId,
          postId: r['id']?.toString(),
          role: roleLabel,
          age: _ageLabel(r['createdAt'] ?? r['created_at']),
          asset: asset,
          likes: (r['likeCount'] as int?) ?? (r['like_count'] as int?) ?? 0,
          comments:
              (r['commentCount'] as int?) ?? (r['comment_count'] as int?) ?? 0,
          shares:
              (r['shareCount'] as int?) ?? (r['share_count'] as int?) ?? 0,
          accent: const Color(0xFF168CFF),
          content: contentText,
          pollId: pollId,
          pollOptions: pollOptions ?? const <String>[],
          pollTotalVotes: pollVotes,
          myPollVote: myVote,
          pollCounts: pollCountsMap ?? const <int, int>{},
          predHome: predHome,
          predAway: predAway,
          predHomeScore: predHs,
          predAwayScore: predAs,
          myPrediction: (predHs != null && predAs != null &&
              Supabase.instance.client.auth.currentUser != null)
              ? '$predHs-$predAs' : null,
        ));
      }

      if (mounted) {
        setState(() {
          _live = items;
          _loading = false;
          _loadError = null;
        });
      }
    } catch (e) {
      debugPrint('feed load: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = e.toString();
        });
      }
    }
  }

  String _ageLabel(dynamic raw) {
    if (raw == null) return '';
    final dt = DateTime.tryParse(raw.toString())?.toLocal();
    if (dt == null) return '';
    final d = DateTime.now().difference(dt);
    if (d.inMinutes < 1) return 'now';
    if (d.inMinutes < 60) return '${d.inMinutes}m';
    if (d.inHours < 24) return '${d.inHours}h';
    if (d.inDays < 7) return '${d.inDays}d';
    return '${dt.day}/${dt.month}';
  }

  @override
  void dispose() {
    if (_channel != null) {
      Supabase.instance.client.removeChannel(_channel!);
    }
    _scrollController.dispose();
    super.dispose();
  }

  List<_SpotlightItem> get _items =>
      _live.isEmpty ? _feedItems : [..._live, ..._feedItems];

  @override
  Widget build(BuildContext context) {
    if (_loading && _live.isEmpty) {
      return const Center(
        child: CircularProgressIndicator(
          color: Color(0xFF168CFF),
          strokeWidth: 2.5,
        ),
      );
    }

    final items = _items;

    if (!_loading && items.isEmpty) {
      return RefreshIndicator(
        color: const Color(0xFF168CFF),
        backgroundColor: const Color(0xFF091522),
        onRefresh: _loadPosts,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(24, 80, 24, 40),
          children: [
            const Icon(Icons.bolt_rounded, size: 48, color: Color(0xFF8FA3B8)),
            const SizedBox(height: 16),
            Text(
              _loadError != null ? 'Could not load Sportlights' : 'No Sportlights yet',
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFF7FAFF),
                fontWeight: FontWeight.w800,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _loadError ??
                  'Posts from the community will appear here. Pull to refresh, or create the first post.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: Color(0xFF8FA3B8), fontSize: 13),
            ),
            if (_loadError != null) ...[
              const SizedBox(height: 20),
              Center(
                child: FilledButton(
                  onPressed: _loadPosts,
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFF168CFF),
                  ),
                  child: const Text('Retry'),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return RefreshIndicator(
      color: const Color(0xFF168CFF),
      backgroundColor: const Color(0xFF091522),
      onRefresh: _loadPosts,
      child: ScrollConfiguration(
        behavior: const ScrollBehavior().copyWith(scrollbars: false),
        child: ListView.builder(
          controller: _scrollController,
          physics: const BouncingScrollPhysics(
            parent: AlwaysScrollableScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 110),
          itemCount: items.length,
          itemBuilder: (context, index) {
            return _SpotlightCard(
              item: items[index],
              isAdmin: _isAdmin,
              onDeleted: () => _loadPosts(silent: true),
            );
          },
        ),
      ),
    );
  }
}

// ============================================================
// CARD
// ============================================================

class _SpotlightCard extends StatelessWidget {
  final _SpotlightItem item;
  final bool isAdmin;
  final VoidCallback? onDeleted;
  const _SpotlightCard({required this.item, this.isAdmin = false, this.onDeleted});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        color: const Color(0xD8071422),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.075)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x42000000),
            blurRadius: 28,
            offset: Offset(0, 12),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 12, 12, 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _AuthorHeader(item: item, isAdmin: isAdmin, onDeleted: onDeleted),
            const SizedBox(height: 12),
            _MediaArea(item: item),
            const SizedBox(height: 10),
            _EngagementRow(item: item),
            const SizedBox(height: 11),
            _ActionRow(item: item, isAdmin: isAdmin, onDeleted: onDeleted),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// AUTHOR HEADER
// ============================================================

class _AuthorHeader extends StatelessWidget {
  final _SpotlightItem item;
  final bool isAdmin;
  final VoidCallback? onDeleted;
  const _AuthorHeader({
    required this.item,
    this.isAdmin = false,
    this.onDeleted,
  });

  Future<void> _adminMenu(BuildContext context) async {
    final id = item.postId;
    if (id == null || id.isEmpty) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF071422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const ListTile(
              title: Text('Admin · Manage post',
                  style: TextStyle(fontWeight: FontWeight.w800)),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit post'),
              onTap: () => Navigator.pop(ctx, 'edit'),
            ),
            ListTile(
              leading: const Icon(Icons.flash_on_rounded, color: Colors.orange),
              title: const Text('Toggle breaking'),
              onTap: () => Navigator.pop(ctx, 'breaking'),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline, color: Colors.redAccent),
              title: const Text('Delete post'),
              onTap: () => Navigator.pop(ctx, 'delete'),
            ),
          ],
        ),
      ),
    );
    if (!context.mounted || action == null) return;
    final social = SocialRepository();
    try {
      if (action == 'delete') {
        final ok = await showDialog<bool>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('Delete post?'),
            content: const Text('This cannot be undone.'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('Cancel')),
              TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('Delete')),
            ],
          ),
        );
        if (ok == true) {
          await social.deletePost(id);
          onDeleted?.call();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post deleted')),
            );
          }
        }
      } else if (action == 'breaking') {
        await social.updatePost(id, isBreaking: true);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Marked as breaking')),
          );
        }
      } else if (action == 'edit') {
        final ctrl = TextEditingController();
        final text = await showDialog<String>(
          context: context,
          builder: (d) => AlertDialog(
            title: const Text('Edit post'),
            content: TextField(
              controller: ctrl,
              maxLines: 5,
              decoration: const InputDecoration(hintText: 'New content'),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(d), child: const Text('Cancel')),
              TextButton(
                onPressed: () => Navigator.pop(d, ctrl.text),
                child: const Text('Save'),
              ),
            ],
          ),
        );
        if (text != null && text.trim().isNotEmpty) {
          await social.updatePost(id, content: text);
          onDeleted?.call();
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Post updated')),
            );
          }
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(item.profilePath),
      behavior: HitTestBehavior.opaque,
      child: Row(
      children: [
        Container(
          width: 46,
          height: 46,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          clipBehavior: Clip.antiAlias,
          child: Image.network(
                  kOfficialAvatarUrl,
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => Image.asset(
                    kOfficialAvatarAsset,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: const Color(0xFF102033),
                      alignment: Alignment.center,
                      child: const Icon(Icons.sports_soccer, color: Colors.white70, size: 24),
                    ),
                  ),
                ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                item.author,
                softWrap: true,
                maxLines: 3,
                overflow: TextOverflow.visible,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  height: 1.25,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(
                    Icons.verified_rounded,
                    color: Color(0xFF168CFF),
                    size: 15,
                  ),
                  const SizedBox(width: 6),
                  Flexible(child: _RoleBadge(label: item.role)),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                item.type == _SpotlightType.team
                    ? '@${item.handle} · Become a fan of this team'
                    : '·  ${item.age}',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.48),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        if (isAdmin && (item.postId?.isNotEmpty ?? false))
          IconButton(
            onPressed: () => _adminMenu(context),
            splashRadius: 22,
            icon: Icon(
              Icons.more_vert_rounded,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          )
        else
          IconButton(
            onPressed: () {},
            splashRadius: 22,
            icon: Icon(
              Icons.bookmark_border_rounded,
              color: Colors.white.withValues(alpha: 0.88),
            ),
          ),
      ],
    ),
    );
  }
}

class _RoleBadge extends StatelessWidget {
  final String label;
  const _RoleBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.065),
        borderRadius: BorderRadius.circular(50),
      ),
      child: Text(
        label,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: Colors.white.withValues(alpha: 0.88),
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

// ============================================================
// MEDIA AREA
// ============================================================

class _MediaArea extends StatelessWidget {
  final _SpotlightItem item;
  const _MediaArea({required this.item});

  @override
  Widget build(BuildContext context) {
    switch (item.type) {
      case _SpotlightType.poll:
        return _PollContent(item: item);
      case _SpotlightType.prediction:
        return _PredictionContent(item: item);
      case _SpotlightType.video:
        return _VideoContent(item: item);
      default:
        return _ImageContent(item: item);
    }
  }
}

class _ImageContent extends StatelessWidget {
  final _SpotlightItem item;
  const _ImageContent({required this.item});

  @override
  Widget build(BuildContext context) {
    final asset = item.asset;
    if (asset == null) return _GeneratedContent(item: item);

    final lower = asset.toLowerCase();
    final isPdf = lower.endsWith('.pdf') || lower.contains('application/pdf');
    if (isPdf) {
      return GestureDetector(
        onTap: () => openMediaUrl(context, asset, title: 'Post PDF'),
        child: Container(
          height: 120,
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0B1626),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white12),
          ),
          child: const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.picture_as_pdf, color: Color(0xFFE31B23), size: 36),
              SizedBox(width: 12),
              Text('Open PDF', style: TextStyle(fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      );
    }

    final isNetwork = asset.startsWith('http');
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: isNetwork
          ? Container(
              height: 280,
              width: double.infinity,
              color: const Color(0xFF071421),
              child: Image.network(
                asset,
                fit: BoxFit.cover,
                width: double.infinity,
                height: 280,
                filterQuality: FilterQuality.high,
                errorBuilder: (_, __, ___) => _GeneratedContent(item: item),
              ),
            )
          : AspectRatio(
              aspectRatio: 1.02,
              child: Image.asset(
                asset,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => _GeneratedContent(item: item),
              ),
            ),
    );
  }
}

class _VideoContent extends StatelessWidget {
  final _SpotlightItem item;
  const _VideoContent({required this.item});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 0.86,
        child: Stack(
          fit: StackFit.expand,
          children: [
            _GeneratedContent(item: item),
            Center(
              child: Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.55),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.35),
                  ),
                ),
                child: const Icon(
                  Icons.play_arrow_rounded,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
            const Positioned(
              left: 16,
              bottom: 16,
              child: _ContentLabel(text: 'VIDEO'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollContent extends StatefulWidget {
  final _SpotlightItem item;
  const _PollContent({required this.item});

  @override
  State<_PollContent> createState() => _PollContentState();
}

class _PollContentState extends State<_PollContent> {
  int? _voted;
  late int _total;
  late Map<int, int> _counts;
  bool _busy = false;
  final _social = SocialRepository();

  @override
  void initState() {
    super.initState();
    _voted = widget.item.myPollVote;
    _total = widget.item.pollTotalVotes ?? 0;
    _counts = Map<int, int>.from(widget.item.pollCounts);
  }

  Future<void> _onVote(int i) async {
    final pollId = widget.item.pollId;
    if (pollId == null) {
      setState(() => _voted = i);
      return;
    }
    if (_busy) return;

    // If tapping the already-voted option → un-vote
    if (_voted == i) {
      setState(() => _busy = true);
      try {
        final uid = Supabase.instance.client.auth.currentUser?.id;
        if (uid != null) {
          await Supabase.instance.client
              .from('PollVote')
              .delete()
              .eq('pollId', pollId)
              .eq('userId', uid);
          // Decrement totalVotes on Poll
          try {
            await Supabase.instance.client.rpc('increment_poll_votes', params: {
              'p_poll_id': pollId,
              'p_user_id': uid,
              'p_option_index': -1, // signal removal
            });
          } catch (_) {}
        }
        final fresh = await _social.pollOptionCounts(pollId);
        if (mounted) {
          setState(() {
            _voted = null;
            _counts = fresh;
            _total = fresh.values.fold<int>(0, (a, b) => a + b);
            _busy = false;
          });
        }
      } catch (e) {
        if (mounted) setState(() => _busy = false);
      }
      return;
    }

    if (_voted != null) return; // already voted on different option
    setState(() => _busy = true);
    try {
      await _social.votePoll(pollId, i);
      final fresh = await _social.pollOptionCounts(pollId);
      if (mounted) {
        setState(() {
          _voted = i;
          _counts = fresh;
          _total = fresh.values.fold<int>(0, (a, b) => a + b);
          _busy = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final options = widget.item.pollOptions.isNotEmpty
        ? widget.item.pollOptions
        : const <String>['Option A', 'Option B'];
    final question = (widget.item.content ?? '').trim().isEmpty
        ? 'Poll'
        : widget.item.content!;
    final total = _total > 0
        ? _total
        : _counts.values.fold<int>(0, (a, b) => a + b);
    final pct = List<int>.generate(options.length, (i) {
      if (total <= 0) return 0;
      final c = _counts[i] ?? 0;
      return ((c / total) * 100).round();
    });
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF092B4A), Color(0xFF071421)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF168CFF), width: 0.7),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ContentLabel(text: 'POLL'),
          const SizedBox(height: 12),
          Text(
            question,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          for (var i = 0; i < options.length; i++) ...[
            _PollOption(
              label: options[i],
              percentage: pct[i],
              voted: _voted == i,
              revealed: _voted != null,
              onTap: !_busy ? () => _onVote(i) : null,
            ),
            if (i < options.length - 1) const SizedBox(height: 10),
          ],
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Text(
              '$_total votes',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.45),
                fontSize: 11,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PollOption extends StatelessWidget {
  final String label;
  final int percentage;
  final bool voted;
  final bool revealed;
  final VoidCallback? onTap;

  const _PollOption({
    required this.label,
    required this.percentage,
    required this.voted,
    required this.revealed,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        height: 48,
        decoration: BoxDecoration(
          color: voted
              ? const Color(0xFF168CFF).withValues(alpha: 0.18)
              : Colors.white.withValues(alpha: 0.055),
          borderRadius: BorderRadius.circular(13),
          border: Border.all(
            color: voted
                ? const Color(0xFF168CFF).withValues(alpha: 0.7)
                : Colors.white.withValues(alpha: 0.08),
          ),
        ),
        child: Stack(
          children: [
            if (revealed)
              FractionallySizedBox(
                widthFactor: percentage / 100,
                child: Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF168CFF).withValues(alpha: 0.22),
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
              ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: Row(
                children: [
                  if (voted)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Icon(
                        Icons.check_circle_rounded,
                        color: const Color(0xFF168CFF),
                        size: 16,
                      ),
                    ),
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight:
                            voted ? FontWeight.w800 : FontWeight.w600,
                      ),
                    ),
                  ),
                  if (revealed)
                    Text(
                      '$percentage%',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PredictionContent extends StatelessWidget {
  final _SpotlightItem item;
  const _PredictionContent({required this.item});

  @override
  Widget build(BuildContext context) {
    final home = item.predHome ?? 'Home';
    final away = item.predAway ?? 'Away';
    final hs = item.predHomeScore ?? 0;
    final as_ = item.predAwayScore ?? 0;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF182E0E), Color(0xFF071421)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF7FD820).withValues(alpha: 0.6),
        ),
      ),
      child: Column(
        children: [
          const Row(
            children: [
              _ContentLabel(text: 'PREDICTION'),
              Spacer(),
              Icon(Icons.analytics_outlined, color: Color(0xFF7FD820)),
            ],
          ),
          if ((item.content ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.content!,
              style: const TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _PredictionTeam(name: home.toUpperCase()),
              Text(
                'VS',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.5),
                  fontWeight: FontWeight.w800,
                ),
              ),
              _PredictionTeam(name: away.toUpperCase()),
            ],
          ),
          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '$hs  -  $as_',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w900,
                letterSpacing: 4,
              ),
            ),
          ),
          if (item.myPrediction != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF7FD820).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: const Color(0xFF7FD820).withValues(alpha: 0.4)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                const Icon(Icons.check_circle_rounded, color: Color(0xFF7FD820), size: 14),
                const SizedBox(width: 6),
                Text('You predicted ${item.myPrediction!.replaceAll('-', ' - ')}',
                    style: const TextStyle(color: Color(0xFF7FD820),
                        fontSize: 12, fontWeight: FontWeight.w600)),
              ]),
            ),
          ],
        ],
      ),
    );
  }
}

class _PredictionTeam extends StatelessWidget {
  final String name;
  const _PredictionTeam({required this.name});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Icon(Icons.shield_rounded, color: Colors.white70, size: 38),
        const SizedBox(height: 6),
        Text(
          name,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _GeneratedContent extends StatelessWidget {
  final _SpotlightItem item;
  const _GeneratedContent({required this.item});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 1.02,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              const Color(0xFF061321),
              Color.lerp(const Color(0xFF061321), item.accent, 0.32)!,
              const Color(0xFF02060D),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                _typeIcon(item.type),
                color: Colors.white,
                size: 58,
              ),
              const SizedBox(height: 12),
              Text(
                _typeLabel(item.type).toUpperCase(),
                style: TextStyle(
                  color: item.accent,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}



IconData _typeIcon(_SpotlightType type) {
  switch (type) {
    case _SpotlightType.team:
      return Icons.groups_rounded;
    case _SpotlightType.player:
      return Icons.person_rounded;
    case _SpotlightType.coach:
      return Icons.sports_rounded;
    case _SpotlightType.scout:
      return Icons.search_rounded;
    case _SpotlightType.agent:
      return Icons.handshake_rounded;
    case _SpotlightType.academy:
      return Icons.school_rounded;
    case _SpotlightType.journalist:
      return Icons.newspaper_rounded;
    case _SpotlightType.analyst:
      return Icons.analytics_rounded;
    case _SpotlightType.commentator:
      return Icons.mic_rounded;
    case _SpotlightType.creator:
      return Icons.play_circle_fill_rounded;
    case _SpotlightType.moderator:
      return Icons.shield_moon_rounded;
    case _SpotlightType.official:
      return Icons.gavel_rounded;
    case _SpotlightType.organization:
      return Icons.corporate_fare_rounded;
    case _SpotlightType.league:
      return Icons.emoji_events_rounded;
    case _SpotlightType.competition:
      return Icons.sports_score_rounded;
    case _SpotlightType.community:
      return Icons.groups_rounded;
    case _SpotlightType.fan:
      return Icons.favorite_rounded;
    case _SpotlightType.business:
      return Icons.storefront_rounded;
    case _SpotlightType.sponsor:
      return Icons.local_offer_rounded;
    case _SpotlightType.commercialPartner:
      return Icons.handshake_rounded;
    case _SpotlightType.venue:
      return Icons.stadium_rounded;
    case _SpotlightType.match:
      return Icons.stadium_rounded;
    case _SpotlightType.video:
      return Icons.play_circle_fill_rounded;
    case _SpotlightType.poll:
      return Icons.poll_rounded;
    case _SpotlightType.prediction:
      return Icons.insights_rounded;
    case _SpotlightType.liveCoverage:
      return Icons.sensors;
  }
}

String _typeLabel(_SpotlightType type) {
  switch (type) {
    case _SpotlightType.team:
      return 'Team';
    case _SpotlightType.player:
      return 'Player';
    case _SpotlightType.coach:
      return 'Coach';
    case _SpotlightType.scout:
      return 'Scout';
    case _SpotlightType.agent:
      return 'Agent';
    case _SpotlightType.academy:
      return 'Academy';
    case _SpotlightType.journalist:
      return 'Journalist';
    case _SpotlightType.analyst:
      return 'Analyst';
    case _SpotlightType.commentator:
      return 'Commentator';
    case _SpotlightType.creator:
      return 'Creator';
    case _SpotlightType.moderator:
      return 'Moderator';
    case _SpotlightType.official:
      return 'Official';
    case _SpotlightType.organization:
      return 'Organization';
    case _SpotlightType.league:
      return 'League';
    case _SpotlightType.competition:
      return 'Competition';
    case _SpotlightType.community:
      return 'Community';
    case _SpotlightType.fan:
      return 'Fan';
    case _SpotlightType.business:
      return 'Business';
    case _SpotlightType.sponsor:
      return 'Sponsor';
    case _SpotlightType.commercialPartner:
      return 'Partner';
    case _SpotlightType.venue:
      return 'Venue';
    case _SpotlightType.match:
      return 'Match';
    case _SpotlightType.video:
      return 'Video';
    case _SpotlightType.poll:
      return 'Poll';
    case _SpotlightType.prediction:
      return 'Prediction';
    case _SpotlightType.liveCoverage:
      return 'LIVE';
  }
}

// ============================================================
// ENGAGEMENT ROW
// ============================================================

class _EngagementRow extends ConsumerStatefulWidget {
  final _SpotlightItem item;
  const _EngagementRow({required this.item});

  @override
  ConsumerState<_EngagementRow> createState() => _EngagementRowState();
}

class _EngagementRowState extends ConsumerState<_EngagementRow> {
  bool _liked = false;
  bool _shared = false;
  late int _likes;
  late int _comments;
  late int _shares;
  final _social = SocialRepository();

  @override
  void initState() {
    super.initState();
    _likes = widget.item.likes;
    _comments = widget.item.comments;
    _shares = widget.item.shares;
    final id = widget.item.postId;
    if (id != null) {
      _social.hasShared(id).then((v) {
        if (mounted) setState(() => _shared = v);
      });
      // #7.6: also load the like state from the DB so the heart icon reflects
      // the user's actual like state on first paint (was previously hard-coded
      // to `false`, causing the icon to flash from outlined to filled).
      _hasLikedPost(id).then((v) {
        if (mounted) setState(() => _liked = v);
      });
    }
  }

  @override
  void didUpdateWidget(covariant _EngagementRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // #7.19: when the parent rebuilds this row with a fresh `_SpotlightItem`
    // (e.g. after a realtime `Post` change or pull-to-refresh), re-sync the
    // local counter caches from the new widget values. We deliberately do
    // NOT touch `_liked` / `_shared` here — those reflect the current user's
    // own actions and shouldn't be reset just because the post counters
    // changed.
    final next = widget.item;
    if (oldWidget.item.likes != next.likes ||
        oldWidget.item.comments != next.comments ||
        oldWidget.item.shares != next.shares) {
      _likes = next.likes;
      _comments = next.comments;
      _shares = next.shares;
    }
  }

  /// Queries the `PostLike` table directly to check whether the current user
  /// has liked the given post.
  ///
  /// `SocialRepository` doesn't expose a `hasLiked` method yet (owned by
  /// Agent S6), and `_SpotlightItem` is always a Post (never a `NewsItem` —
  /// news lives in `news_tab.dart` with its own `_NewsCard`), so we just hit
  /// `PostLike` here. When `SocialRepository.hasLiked` lands we can delegate.
  Future<bool> _hasLikedPost(String postId) async {
    final sb = Supabase.instance.client;
    final uid = sb.auth.currentUser?.id;
    if (uid == null) return false;
    try {
      final row = await sb
          .from('PostLike')
          .select('userId')
          .eq('postId', postId)
          .eq('userId', uid)
          .maybeSingle();
      return row != null;
    } catch (e) {
      debugPrint('_EngagementRow._hasLikedPost($postId): $e');
      return false;
    }
  }

  Future<void> _onShare() async {
    final id = widget.item.postId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Share available on live posts')),
      );
      return;
    }

    // #7.7 + #7.8: tapping Share ALWAYS opens the OS share sheet first.
    // Only after the sheet returns successfully do we record the PostShare
    // row — this matches user expectations (a cancel/failure does NOT count
    // as a share) and prevents phantom share-count increments.
    final text = widget.item.content?.trim().isNotEmpty == true
        ? widget.item.content!
        : '${widget.item.author} on Playify';
    try {
      await Share.share(text, subject: 'SportSphere');
    } catch (e) {
      // OS share sheet failed or was cancelled — bail out WITHOUT inserting
      // a PostShare row.
      debugPrint('_EngagementRow._onShare OS sheet failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
      return;
    }

    // OS sheet returned successfully. If we've already recorded this share,
    // don't insert a duplicate row — just leave the local state as-is.
    if (_shared) return;

    // Insert a fresh PostShare row. We use `upsert` (idempotent on the
    // `(postId, userId)` PK) so a race with another device doesn't throw;
    // the `trg_post_share_count` DB trigger bumps `Post.shareCount` on
    // INSERT, so we mirror that locally with `_shares + 1`.
    try {
      final sb = Supabase.instance.client;
      final uid = sb.auth.currentUser?.id;
      if (uid == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sign in to record share')),
          );
        }
        return;
      }
      await sb.from('PostShare').upsert({
        'postId': id,
        'userId': uid,
        'createdAt': DateTime.now().toIso8601String(),
      });
      if (!mounted) return;
      setState(() {
        _shared = true;
        _shares = _shares + 1;
      });
    } catch (e) {
      debugPrint('_EngagementRow._onShare insert PostShare failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  Future<void> _onLike() async {
    final next = !_liked;
    setState(() {
      _liked = next;
      _likes += next ? 1 : -1;
    });
    final id = widget.item.postId;
    if (id == null) return;
    try {
      await _social.toggleLike(id, like: next);
    } catch (e) {
      if (mounted) {
        setState(() {
          _liked = !next;
          _likes += next ? -1 : 1;
        });
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    }
  }

  /// Returns true if guest (action blocked), false if authenticated.
  bool _requireLogin() {
    final auth = ref.read(authControllerProvider);
    if (auth.isAuthenticated) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Sign in to like, comment and share'),
        action: SnackBarAction(
          label: 'Sign In',
          onPressed: () => context.push('/login'),
        ),
        backgroundColor: SportSphereColors.surface,
        duration: const Duration(seconds: 3),
      ),
    );
    return true;
  }

  Future<void> _onComment() async {
    if (_requireLogin()) return;
    final id = widget.item.postId;
    if (id == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Comments available on live posts')),
      );
      return;
    }
    final added = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF071422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (_) => _CommentSheet(postId: id, social: _social),
    );
    if (added == true && mounted) {
      setState(() => _comments += 1);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        GestureDetector(
          onTap: _onLike,
          child: Row(
            children: [
              Icon(
                _liked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                color: _liked ? const Color(0xFFE31B23) : Colors.white,
                size: 22,
              ),
              if (_likes > 0) ...[
                const SizedBox(width: 6),
                Text('$_likes', style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 13)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 22),
        GestureDetector(
          onTap: _onComment,
          child: Row(
            children: [
              const Icon(Icons.chat_bubble_outline_rounded, color: Colors.white, size: 22),
              if (_comments > 0) ...[
                const SizedBox(width: 6),
                Text('$_comments', style: TextStyle(color: Colors.white.withValues(alpha: 0.78), fontSize: 13)),
              ],
            ],
          ),
        ),
        const SizedBox(width: 22),
        GestureDetector(
          onTap: _onShare,
          child: Row(
            children: [
              Icon(
                Icons.ios_share_rounded,
                color: _shared ? const Color(0xFF168CFF) : Colors.white,
                size: 22,
              ),
              if (_shares > 0) ...[
                const SizedBox(width: 6),
                Text(
                  '$_shares',
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.78),
                    fontSize: 13,
                  ),
                ),
              ],
            ],
          ),
        ),
        const Spacer(),
        const Icon(Icons.bookmark_border_rounded, color: Colors.white, size: 23),
      ],
    );
  }
}

class _CommentSheet extends StatefulWidget {
  final String postId;
  final SocialRepository social;
  const _CommentSheet({required this.postId, required this.social});

  @override
  State<_CommentSheet> createState() => _CommentSheetState();
}

class _CommentSheetState extends State<_CommentSheet> {
  final _ctrl = TextEditingController();
  List<Map<String, dynamic>> _rows = [];
  bool _loading = true;
  bool _sending = false;
  XFile? _attach;
  String? _sticker;
  String? _replyToId;
  String? _replyPreview;
  static const _stickers = ['⚽', '🔥', '👏', '😂', '😱', '💪', '🏆', '❤️', '🦁', '⭐'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  List<Map<String, dynamic>> _threadComments(List<Map<String, dynamic>> rows) {
    final roots = <Map<String, dynamic>>[];
    final kids = <String, List<Map<String, dynamic>>>{};
    for (final c in rows) {
      final pid = c['parentId']?.toString();
      if (pid == null || pid.isEmpty) {
        roots.add(c);
      } else {
        kids.putIfAbsent(pid, () => []).add(c);
      }
    }
    final out = <Map<String, dynamic>>[];
    void walk(Map<String, dynamic> node, int depth) {
      out.add({...node, '_depth': depth});
      final id = node['id']?.toString() ?? '';
      for (final k in kids[id] ?? const <Map<String, dynamic>>[]) {
        walk(k, depth + 1);
      }
    }
    for (final r in roots) {
      walk(r, 0);
    }
    // orphan replies
    final used = out.map((e) => e['id']?.toString()).toSet();
    for (final c in rows) {
      if (!used.contains(c['id']?.toString())) out.add({...c, '_depth': 1});
    }
    return out;
  }

  Future<void> _load() async {
    try {
      final rows = await widget.social.listComments(widget.postId);
      final threaded = _threadComments(rows);
      if (mounted) setState(() { _rows = threaded; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _attachFile() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: const Color(0xFF071422),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(leading: const Icon(Icons.image_outlined), title: const Text('Image'), onTap: () => Navigator.pop(ctx, 'image')),
            ListTile(leading: const Icon(Icons.gif_box_outlined), title: const Text('GIF'), onTap: () => Navigator.pop(ctx, 'gif')),
            ListTile(leading: const Icon(Icons.picture_as_pdf_outlined), title: const Text('PDF'), onTap: () => Navigator.pop(ctx, 'pdf')),
            ListTile(leading: const Icon(Icons.emoji_emotions_outlined), title: const Text('Sticker'), onTap: () => Navigator.pop(ctx, 'sticker')),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    if (choice == 'sticker') {
      final s = await showModalBottomSheet<String>(
        context: context,
        backgroundColor: const Color(0xFF071422),
        builder: (ctx) => Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final e in _stickers)
                InkWell(onTap: () => Navigator.pop(ctx, e), child: Text(e, style: const TextStyle(fontSize: 32))),
            ],
          ),
        ),
      );
      if (s != null && mounted) setState(() { _sticker = s; _attach = null; });
      return;
    }
    if (choice == 'image') {
      final f = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 88);
      if (f != null && mounted) setState(() { _attach = f; _sticker = null; });
      return;
    }
    final picked = await pickCommentAttachmentDirect(choice);
    if (picked != null && mounted) setState(() { _attach = picked; _sticker = null; });
  }

  Future<void> _send() async {
    final text = _ctrl.text.trim();
    final sticker = _sticker;
    if (text.isEmpty && _attach == null && sticker == null) return;
    if (_sending) return;
    setState(() => _sending = true);
    try {
      final urls = <String>[];
      String? mediaType;
      if (sticker != null) {
        mediaType = 'sticker';
        // sticker text embedded
      }
      if (_attach != null) {
        final name = _attach!.name.toLowerCase();
        mediaType = name.endsWith('.pdf')
            ? 'pdf'
            : name.endsWith('.gif')
                ? 'gif'
                : 'image';
        final url = await widget.social.uploadPickedFile(
          bucket: 'posts',
          folder: 'comments',
          file: _attach!,
        );
        urls.add(url);
      }
      final body = sticker != null ? (text.isEmpty ? sticker : '$text $sticker') : text;
      await widget.social.addComment(
        widget.postId,
        body,
        mediaUrls: urls,
        mediaType: mediaType ?? (sticker != null ? 'sticker' : null),
        parentId: _replyToId,
      );
      if (mounted) {
        setState(() {
          _replyToId = null;
          _replyPreview = null;
        });
      }
      _ctrl.clear();
      setState(() { _attach = null; _sticker = null; });
      await _load();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  Widget _commentBody(Map<String, dynamic> c) {
    final content = '${c['content'] ?? ''}';
    final media = c['mediaUrls'];
    final urls = media is List ? media.map((e) => e.toString()).toList() : <String>[];
    final type = c['mediaType']?.toString();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (content.isNotEmpty)
          Text(content, style: const TextStyle(fontSize: 14)),
        for (final u in urls) ...[
          const SizedBox(height: 6),
          if ((type == 'pdf') || u.toLowerCase().endsWith('.pdf'))
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.picture_as_pdf, color: Color(0xFFE31B23)),
              title: const Text('Open PDF', style: TextStyle(fontSize: 13)),
              onTap: () => openMediaUrl(context, u, title: 'Comment PDF'),
            )
          else
            GestureDetector(
              onTap: () => openMediaUrl(context, u),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: Image.network(u, height: 140, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
              ),
            ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottom + 16),
      child: SizedBox(
        height: MediaQuery.sizeOf(context).height * 0.62,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Live thread / comments', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            const SizedBox(height: 12),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty
                      ? const Center(child: Text('No comments yet', style: TextStyle(color: Colors.white54)))
                      : ListView.builder(
                          itemCount: _rows.length,
                          itemBuilder: (_, i) {
                            final c = _rows[i];
                            final depth = (c['_depth'] as int?) ?? (c['parentId'] != null ? 1 : 0);
                            final cid = c['id']?.toString() ?? '';
                            return Padding(
                              padding: EdgeInsets.only(left: depth * 16.0),
                              child: ListTile(
                                contentPadding: EdgeInsets.zero,
                                title: _commentBody(c),
                                subtitle: Row(
                                  children: [
                                    Text(
                                      '${c['userId'] ?? ''}'.toString().padRight(8).substring(0, 8),
                                      style: const TextStyle(color: Colors.white38, fontSize: 11),
                                    ),
                                    const SizedBox(width: 12),
                                    GestureDetector(
                                      onTap: () => setState(() {
                                        _replyToId = cid;
                                        _replyPreview = (c['content'] as String?) ?? 'Comment';
                                      }),
                                      child: const Text(
                                        'Reply',
                                        style: TextStyle(
                                          color: Color(0xFF168CFF),
                                          fontSize: 12,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),
            if (_replyToId != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Replying to: ${_replyPreview ?? ''}',
                        style: const TextStyle(color: Colors.white54, fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 16, color: Colors.white54),
                      onPressed: () => setState(() {
                        _replyToId = null;
                        _replyPreview = null;
                      }),
                    ),
                  ],
                ),
              ),
            if (_attach != null || _sticker != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Chip(
                  label: Text(_sticker ?? _attach!.name),
                  onDeleted: () => setState(() { _attach = null; _sticker = null; }),
                ),
              ),
            Row(
              children: [
                IconButton(
                  onPressed: _sending ? null : _attachFile,
                  icon: const Icon(Icons.attach_file, color: Color(0xFF168CFF)),
                ),
                Expanded(
                  child: TextField(
                    controller: _ctrl,
                    decoration: InputDecoration(
                      hintText: 'Write a comment…',
                      filled: true,
                      fillColor: const Color(0xFF0B1626),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  onPressed: _sending ? null : _send,
                  icon: Icon(_sending ? Icons.hourglass_top : Icons.send_rounded, color: const Color(0xFF168CFF)),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}



// ============================================================
// ACTION ROW  — role-aware button logic
// ============================================================

class _ActionRow extends StatefulWidget {
  final _SpotlightItem item;
  final bool isAdmin;
  final VoidCallback? onDeleted;
  const _ActionRow({
    required this.item,
    this.isAdmin = false,
    this.onDeleted,
  });

  @override
  State<_ActionRow> createState() => _ActionRowState();
}

class _ActionRowState extends State<_ActionRow> {
  Future<String?> _resolveTargetId() async {
    final item = widget.item;
    final sb = Supabase.instance.client;
    final handle = item.handle.replaceAll('@', '').trim();

    // Team / welcome posts: follow the TEAM account, never the admin author
    if (item.type == _SpotlightType.team) {
      try {
        Map<String, dynamic>? team;
        if (item.targetUserId != null && item.targetUserId!.isNotEmpty) {
          // may already be team id or user id
          team = await sb
              .from('Team')
              .select('id, accountUserId, name, slug')
              .eq('id', item.targetUserId!)
              .maybeSingle();
        }
        team ??= await sb
            .from('Team')
            .select('id, accountUserId, name, slug')
            .or('id.eq.$handle,slug.eq.$handle')
            .maybeSingle();
        if (team == null && handle.isNotEmpty) {
          final rows = await sb
              .from('Team')
              .select('id, accountUserId, name, slug')
              .ilike('name', '%$handle%')
              .limit(1);
          if ((rows as List).isNotEmpty) {
            team = Map<String, dynamic>.from(rows.first as Map);
          }
        }
        if (team != null) {
          final aid = team['accountUserId']?.toString();
          if (aid != null && aid.isNotEmpty) return aid;
          // Fallback: team id itself (graph may resolve)
          final tid = team['id']?.toString();
          if (tid != null && tid.isNotEmpty) return tid;
        }
      } catch (_) {}
    }

    if (item.targetUserId != null && item.targetUserId!.isNotEmpty) {
      return item.targetUserId;
    }
    if (handle.isEmpty) return null;
    try {
      final u = await sb.from('User').select('id').eq('handle', handle).maybeSingle();
      if (u?['id'] != null) return u!['id'].toString();
    } catch (_) {}
    try {
      final p = await sb.from('profiles').select('id').eq('handle', handle).maybeSingle();
      return p?['id']?.toString();
    } catch (_) {
      return null;
    }
  }

  Future<void> _toggleFollow(bool next) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to follow')),
        );
      }
      return;
    }
    final target = await _resolveTargetId();
    if (target == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find this profile')),
        );
      }
      return;
    }
    if (target == uid) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("You can't follow yourself")),
        );
      }
      return;
    }
    setState(() => _following = next);
    try {
      final graph = SocialGraph();
      await graph.follow(target, on: next);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next
                ? 'You follow ${widget.item.author}'
                : 'Unfollowed ${widget.item.author}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _following = !next);
    }
  }

  Future<void> _toggleFan(bool next) async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sign in to become a fan')),
        );
      }
      return;
    }
    final target = await _resolveTargetId();
    if (target == null) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not find this team/profile')),
        );
      }
      return;
    }
    setState(() => _isFan = next);
    try {
      final graph = SocialGraph();
      await graph.fan(target, on: next);
      // Also refresh the fan's own counts / badges source
      await graph.refreshCounts(uid);
      if (mounted) {
        final name = widget.item.author;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next
                ? 'You are now a $name fan — badge updated on your profile'
                : 'Removed $name fan status'),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isFan = !next);
    }
  }
  bool _following = false;
  bool _isFan = false;
  bool _joinedCommunity = false;
  // _stateLoaded removed — unused

  @override
  void initState() {
    super.initState();
    _loadInitialState();
  }

  Future<void> _loadInitialState() async {
    final uid = Supabase.instance.client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final target = await _resolveTargetId();
      if (target == null) return;
      final graph = SocialGraph();
      final results = await Future.wait([
        graph.isFollowing(uid, target),
        if (_fanRoles.contains(widget.item.type)) graph.isFan(uid, target),
      ]);
      if (mounted) {
        setState(() {
          _following = results[0];
          if (results.length > 1) _isFan = results[1];
        });
      }
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final type = widget.item.type;
    final accent = widget.item.accent;

    // ── Commerce: match tickets & business ──────────────────
    if (type == _SpotlightType.match) {
      return _TwoButtons(
        primary: _Btn(
          label: 'Buy Ticket',
          icon: Icons.confirmation_number_outlined,
          color: accent,
          onTap: () {},
        ),
        secondary: _Btn(
          label: 'View Match',
          icon: Icons.stadium_outlined,
          color: accent,
          outlined: true,
          onTap: () {},
        ),
      );
    }

    if (_commerceRoles.contains(type)) {
      return _TwoButtons(
        primary: _Btn(
          label: 'Buy Now',
          icon: Icons.shopping_cart_outlined,
          color: accent,
          onTap: () {},
        ),
        secondary: _Btn(
          label: 'Visit Shop',
          icon: Icons.storefront_outlined,
          color: accent,
          outlined: true,
          onTap: () {},
        ),
      );
    }

    // ── Video ────────────────────────────────────────────────
    if (type == _SpotlightType.video) {
      return _TwoButtons(
        primary: _Btn(
          label: 'Watch',
          icon: Icons.play_arrow_rounded,
          color: accent,
          onTap: () {},
        ),
        secondary: _following
            ? _Btn(
                label: 'Following',
                icon: Icons.check_rounded,
                color: accent,
                outlined: true,
                onTap: () => _toggleFollow(false),
              )
            : _Btn(
                label: 'Follow',
                icon: Icons.person_add_alt_1_rounded,
                color: accent,
                outlined: true,
                onTap: () => _toggleFollow(true),
              ),
      );
    }

    // ── Poll ─────────────────────────────────────────────────
    if (type == _SpotlightType.poll) {
      return _TwoButtons(
        primary: _Btn(
          label: 'Vote',
          icon: Icons.how_to_vote_outlined,
          color: accent,
          onTap: () {},
        ),
        secondary: _Btn(
          label: 'Discuss',
          icon: Icons.forum_outlined,
          color: accent,
          outlined: true,
          onTap: () {},
        ),
      );
    }

    // ── Prediction ───────────────────────────────────────────
    if (type == _SpotlightType.prediction) {
      return _TwoButtons(
        primary: _Btn(
          label: 'Predict',
          icon: Icons.analytics_outlined,
          color: accent,
          onTap: () {
            // Navigate to create screen pre-filled with prediction tab
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tap ＋ to create your own prediction'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
        secondary: _Btn(
          label: 'View Match',
          icon: Icons.sports_soccer_outlined,
          color: accent,
          outlined: true,
          onTap: () {
            // Navigate to scores tab
            context.go('/home');
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Check Scores tab for match details'),
                duration: Duration(seconds: 2),
              ),
            );
          },
        ),
      );
    }

    // ── Community ────────────────────────────────────────────
    if (_communityRoles.contains(type)) {
      final cid = widget.item.targetUserId ?? widget.item.handle;
      return _joinedCommunity
          ? _OneButton(
              child: _Btn(
                label: 'Joined Community',
                icon: Icons.check_rounded,
                color: accent,
                outlined: true,
                onTap: () async {
                  try {
                    await CommerceRepository().leaveCommunity(cid);
                    if (mounted) setState(() => _joinedCommunity = false);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                    }
                  }
                },
              ),
            )
          : _OneButton(
              child: _Btn(
                label: 'Join Community',
                icon: Icons.group_add_outlined,
                color: accent,
                onTap: () async {
                  try {
                    await CommerceRepository().joinCommunity(cid);
                    if (mounted) setState(() => _joinedCommunity = true);
                  } catch (e) {
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyError(e))));
                    }
                  }
                },
              ),
            );
    }

    // ── Fan roles: Follow + Become Fan ───────────────────────
    if (_fanRoles.contains(type)) {
      return _TwoButtons(
        primary: _isFan
            ? _Btn(
                label: 'Fan ✓',
                icon: Icons.favorite_rounded,
                color: accent,
                onTap: () => _toggleFan(false),
              )
            : _Btn(
                label: 'Become a fan',
                icon: Icons.favorite_border_rounded,
                color: accent,
                onTap: () => _toggleFan(true),
              ),
        secondary: _following
            ? _Btn(
                label: 'Following',
                icon: Icons.check_rounded,
                color: accent,
                outlined: true,
                onTap: () => _toggleFollow(false),
              )
            : _Btn(
                label: 'Follow',
                icon: Icons.person_add_alt_1_rounded,
                color: accent,
                outlined: true,
                onTap: () => _toggleFollow(true),
              ),
      );
    }

    // ── Follow-only roles ────────────────────────────────────
    if (_followOnlyRoles.contains(type)) {
      return _OneButton(
        child: _following
            ? _Btn(
                label: 'Following',
                icon: Icons.check_rounded,
                color: accent,
                outlined: true,
                onTap: () => _toggleFollow(false),
              )
            : _Btn(
                label: 'Follow',
                icon: Icons.person_add_alt_1_rounded,
                color: accent,
                onTap: () => _toggleFollow(true),
              ),
      );
    }

    // ── Fallback ─────────────────────────────────────────────
    return const SizedBox.shrink();
  }
}

// ── Layout helpers ─────────────────────────────────────────

class _OneButton extends StatelessWidget {
  final Widget child;
  const _OneButton({required this.child});

  @override
  Widget build(BuildContext context) => SizedBox(
        width: double.infinity,
        child: child,
      );
}

class _TwoButtons extends StatelessWidget {
  final Widget primary;
  final Widget secondary;
  const _TwoButtons({required this.primary, required this.secondary});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          // Small secondary (Follow)
          Expanded(flex: 2, child: secondary),
          const SizedBox(width: 9),
          // Big primary (Become a fan)
          Expanded(flex: 3, child: primary),
        ],
      );
}

// ── Individual button ──────────────────────────────────────

class _Btn extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool outlined;
  final VoidCallback onTap;

  const _Btn({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
    this.outlined = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        height: 46,
        decoration: BoxDecoration(
          color: outlined ? Colors.transparent : color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: outlined
                ? color.withValues(alpha: 0.75)
                : Colors.transparent,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: outlined ? color : Colors.white,
              size: 18,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: outlined ? color : Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// SMALL SHARED COMPONENTS
// ============================================================

class _ContentLabel extends StatelessWidget {
  final String text;
  const _ContentLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(7),
        border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}
