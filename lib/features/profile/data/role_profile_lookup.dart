import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shop/models/shop_models.dart';
import '../shared/profile_widgets.dart';
import '../templates/role_profile_model.dart';

/// Unified DB loader for all non-fan/team/player roles.
Future<RoleProfileModel> lookupRoleProfile(String role, String handle) async {
  final sb = Supabase.instance.client;
  final key = handle.replaceAll('@', '').trim().toLowerCase();
  final roleKey =
      role.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  final slugDash = key.replaceAll('_', '-');

  Map<String, dynamic>? user;
  Map<String, dynamic>? entity;

  try {
    user = await sb.from('User').select().eq('handle', key).maybeSingle();
  } catch (_) {}
  try {
    user ??= await sb.from('profiles').select().eq('handle', key).maybeSingle();
  } catch (_) {}

  entity = await _fetchEntity(sb, roleKey, key, slugDash, user?['id']?.toString());

  if (user == null && entity?['accountUserId'] != null) {
    try {
      user = await sb
          .from('User')
          .select()
          .eq('id', entity!['accountUserId'])
          .maybeSingle();
    } catch (_) {}
  }

  final effectiveRole =
      ((user?['role'] as String?) ?? roleKey).toLowerCase().replaceAll('-', '_');
  final label = _prettyRole(effectiveRole.isNotEmpty ? effectiveRole : roleKey);
  final shape = _shapeFor(roleKey);
  final accent = _accentFor(roleKey);

  final name = (entity?['name'] as String?) ??
      (user?['name'] as String?) ??
      '${user?['first_name'] ?? ''} ${user?['last_name'] ?? ''}'.trim();
  final display = name.isNotEmpty ? name : _title(key);

  final uid =
      entity?['accountUserId']?.toString() ?? user?['id']?.toString();
  final entityId = entity?['id']?.toString();

  var postCount = (user?['postCount'] as int?) ?? 0;
  final followerCount = (user?['followerCount'] as int?) ?? 0;
  final followingCount = (user?['followingCount'] as int?) ?? 0;
  final fanCount = (user?['fanCount'] as int?) ??
      (entity?['memberCount'] as int?) ??
      0;

  final posts = await _loadPosts(sb, uid);
  if (postCount == 0) postCount = posts.length;

  final about = await _aboutFields(
    sb,
    roleKey: roleKey,
    user: user,
    entity: entity,
    label: label,
  );
  final members = await _members(sb, roleKey: roleKey, entity: entity);
  final statsRows = await _statsRows(sb, roleKey: roleKey, entity: entity);

  final headerStats = <RoleStat>[
    RoleStat('$postCount', 'Posts'),
    if (shape != RoleShape.commerce) RoleStat('$fanCount', shape == RoleShape.org ? 'Members' : 'Fans'),
    RoleStat('$followerCount', 'Followers'),
    RoleStat('$followingCount', 'Following'),
  ];

  ShopCatalog? shop;
  if (shape == RoleShape.commerce) {
    shop = teamShopCatalog(
      name: display,
      handle: (user?['handle'] as String?) ?? key,
      accent: accent,
    );
  }

  return RoleProfileModel(
    displayName: display,
    handle: (user?['handle'] as String?) ??
        (entity?['slug'] as String?)?.replaceAll('-', '_') ??
        key,
    roleLabel: label,
    subtitle: _subtitle(roleKey, entity),
    bio: (user?['bio'] as String?) ??
        (entity?['description'] as String?) ??
        '',
    location: (user?['country'] as String?) ??
        (entity?['country'] as String?) ??
        (entity?['location'] as String?) ??
        '',
    sport: (entity?['sport_slug'] as String?) ??
        (entity?['sportId'] as String?)?.replaceFirst('sport-', '') ??
        'Football',
    accent: accent,
    shape: shape,
    headerStats: headerStats,
    aboutFields: about,
    posts: posts,
    members: members,
    membersTitle: _membersTitle(roleKey),
    statsRows: statsRows,
    entityId: entityId,
    isClaimable: uid == null && entity != null,
    profileType: roleKey,
    isVerified: (entity?['verified'] as bool?) == true ||
        (user?['isVerified'] as bool?) == true ||
        (user?['is_verified'] as bool?) == true,
    isOwnProfile: uid != null && uid == sb.auth.currentUser?.id,
    coverIcon: _iconFor(roleKey),
    shop: shop,
  );
}

Future<Map<String, dynamic>?> _fetchEntity(
  SupabaseClient sb,
  String roleKey,
  String key,
  String slugDash,
  String? userId,
) async {
  Future<Map<String, dynamic>?> tryTable(
    String table, {
    List<String> idPrefixes = const [],
  }) async {
    Map<String, dynamic>? row;
    try {
      if (userId != null) {
        row = await sb
            .from(table)
            .select()
            .eq('accountUserId', userId)
            .maybeSingle();
      }
    } catch (_) {}
    try {
      row ??= await sb.from(table).select().eq('slug', slugDash).maybeSingle();
    } catch (_) {}
    try {
      row ??= await sb.from(table).select().eq('slug', key).maybeSingle();
    } catch (_) {}
    for (final p in idPrefixes) {
      try {
        row ??= await sb.from(table).select().eq('id', '$p$key').maybeSingle();
      } catch (_) {}
      try {
        row ??=
            await sb.from(table).select().eq('id', '$p$slugDash').maybeSingle();
      } catch (_) {}
    }
    try {
      if (row == null) {
        final guess = key.replaceAll('_', ' ').replaceAll('-', ' ');
        final rows =
            await sb.from(table).select().ilike('name', '%$guess%').limit(1);
        if ((rows as List).isNotEmpty) {
          row = Map<String, dynamic>.from(rows.first as Map);
        }
      }
    } catch (_) {}
    return row;
  }

  switch (roleKey) {
    case 'coach':
      return tryTable('Coach', idPrefixes: ['ch-']);
    case 'league':
      return tryTable('League', idPrefixes: ['lg-']);
    case 'competition':
      return tryTable('Competition', idPrefixes: ['comp-']);
    case 'community':
      return tryTable('Community');
    case 'academy':
      // may live as Team with taxonomy or Community
      return await tryTable('Team', idPrefixes: ['tm-']) ??
          await tryTable('Community');
    case 'media_broadcast':
    case 'media':
      return tryTable('User'); // media accounts are users
    default:
      // person commerce roles: entity is the user row itself
      return null;
  }
}

Future<List<ProfilePost>> _loadPosts(SupabaseClient sb, String? uid) async {
  if (uid == null || uid.isEmpty) return [];
  try {
    final rows = await sb
        .from('Post')
        .select(
            'id,content,likeCount,commentCount,shareCount,createdAt,mediaUrls,hashtags')
        .eq('userId', uid)
        .order('createdAt', ascending: false)
        .limit(30);
    final posts = <ProfilePost>[];
    for (final r in rows as List) {
      final m = Map<String, dynamic>.from(r as Map);
      final media = m['mediaUrls'];
      final hasMedia = media is List && media.isNotEmpty;
      final tags = m['hashtags'];
      posts.add(ProfilePost(
        text: (m['content'] as String?) ?? '',
        hashtags: tags is List
            ? [for (final x in tags) x.toString()]
            : const [],
        timeAgo: _age(m['createdAt']?.toString()),
        likes: (m['likeCount'] as int?) ?? 0,
        comments: (m['commentCount'] as int?) ?? 0,
        shares: (m['shareCount'] as int?) ?? 0,
        hasImage: hasMedia,
        imageUrl: hasMedia ? media.first.toString() : null,
      ));
    }
    return posts;
  } catch (_) {
    return [];
  }
}

Future<List<AboutField>> _aboutFields(
  SupabaseClient sb, {
  required String roleKey,
  required Map<String, dynamic>? user,
  required Map<String, dynamic>? entity,
  required String label,
}) async {
  final fields = <AboutField>[AboutField('Role', label)];

  void add(String k, String? v) {
    if (v != null && v.trim().isNotEmpty) fields.add(AboutField(k, v.trim()));
  }

  add('Country', (entity?['country'] as String?) ?? (user?['country'] as String?));
  add('Nationality', entity?['nationality'] as String?);
  add('City', entity?['city'] as String?);
  add('Location', entity?['location'] as String?);

  switch (roleKey) {
    case 'coach':
      add('Title', (entity?['role'] as String?)?.replaceAll('_', ' '));
      final teamId = entity?['teamId']?.toString();
      if (teamId != null) {
        try {
          final team =
              await sb.from('Team').select('name').eq('id', teamId).maybeSingle();
          add('Club', team?['name'] as String?);
        } catch (_) {}
      }
      break;
    case 'league':
      add('Type', entity?['type'] as String?);
      add('Season', entity?['season'] as String?);
      add('Division', entity?['division'] as String?);
      break;
    case 'competition':
      add('Type', entity?['competition_type'] as String?);
      add('Format', entity?['competition_format'] as String?);
      add('Level', entity?['competition_level'] as String?);
      add('Season', entity?['season'] as String?);
      add('Gender', entity?['gender'] as String?);
      break;
    case 'community':
      add('Topic', entity?['topic'] as String?);
      if (entity?['memberCount'] != null) {
        add('Members', '${entity!['memberCount']}');
      }
      break;
    case 'venue':
      add('Capacity', entity?['capacity']?.toString());
      add('Stadium', entity?['name'] as String?);
      break;
    default:
      break;
  }

  add('Email', user?['email'] as String?);
  return fields;
}

Future<List<RoleMember>> _members(
  SupabaseClient sb, {
  required String roleKey,
  required Map<String, dynamic>? entity,
}) async {
  final id = entity?['id']?.toString();
  if (id == null) return [];

  try {
    if (roleKey == 'league') {
      // Teams in same country / active — best effort
      final teams = await sb
          .from('Team')
          .select('id,name,slug,accountUserId')
          .eq('isActive', true)
          .limit(24);
      return [
        for (final r in teams as List)
          RoleMember(
            name: (r as Map)['name']?.toString() ?? 'Team',
            handle: (r['slug'] as String?)?.replaceAll('-', '_') ??
                r['id'].toString(),
            subtitle: 'Club',
            route: '/team/${(r['slug'] as String?)?.replaceAll('-', '_') ?? r['id']}',
          ),
      ];
    }
    if (roleKey == 'coach') {
      final teamId = entity?['teamId']?.toString();
      if (teamId == null) return [];
      final players =
          await sb.from('Player').select('name,slug,position').eq('teamId', teamId).limit(20);
      return [
        for (final r in players as List)
          RoleMember(
            name: (r as Map)['name']?.toString() ?? 'Player',
            handle: (r['slug'] as String?)?.replaceAll('-', '_') ?? 'player',
            subtitle: (r['position'] as String?) ?? 'Player',
            route:
                '/player/${(r['slug'] as String?)?.replaceAll('-', '_') ?? 'player'}',
          ),
      ];
    }
  } catch (_) {}
  return [];
}

Future<List<AboutField>> _statsRows(
  SupabaseClient sb, {
  required String roleKey,
  required Map<String, dynamic>? entity,
}) async {
  if (roleKey == 'league' || roleKey == 'competition') {
    try {
      final name = entity?['name'] as String? ?? '';
      final q = sb.from('Match').select('id,status');
      // count fixtures loosely
      final rows = await q.limit(500);
      var total = 0, finished = 0;
      for (final r in rows as List) {
        total++;
        final st = ((r as Map)['status'] as String?)?.toLowerCase() ?? '';
        if (st == 'finished' || st == 'ft' || st == 'completed') finished++;
      }
      return [
        AboutField('Fixtures loaded', '$total'),
        AboutField('Finished', '$finished'),
        if (name.isNotEmpty) AboutField('Competition', name),
      ];
    } catch (_) {}
  }
  return [];
}

String _prettyRole(String role) {
  const map = {
    'support_staff': 'Support Staff',
    'commercial_partner': 'Commercial Partner',
    'media_broadcast': 'Media / Broadcast',
    'media': 'Media / Broadcast',
  };
  if (map.containsKey(role)) return map[role]!;
  if (role.isEmpty) return 'User';
  return role
      .split('_')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

RoleShape _shapeFor(String role) {
  const org = {
    'academy',
    'league',
    'competition',
    'organization',
    'community',
    'media_broadcast',
    'media',
  };
  const commerce = {
    'business',
    'sponsor',
    'commercial_partner',
    'venue',
  };
  if (org.contains(role)) return RoleShape.org;
  if (commerce.contains(role)) return RoleShape.commerce;
  return RoleShape.person;
}

Color _accentFor(String role) {
  switch (role) {
    case 'coach':
      return const Color(0xFF00C853);
    case 'scout':
      return const Color(0xFFFF6D00);
    case 'agent':
      return const Color(0xFF7C4DFF);
    case 'journalist':
      return const Color(0xFF2979FF);
    case 'league':
    case 'competition':
      return const Color(0xFFFFD600);
    case 'sponsor':
      return const Color(0xFFFFD700);
    case 'venue':
      return const Color(0xFFE31B23);
    case 'creator':
      return const Color(0xFFE91E63);
    case 'community':
      return const Color(0xFF00BCD4);
    default:
      return const Color(0xFF009DFF);
  }
}

IconData _iconFor(String role) {
  switch (role) {
    case 'coach':
      return Icons.sports_rounded;
    case 'league':
    case 'competition':
      return Icons.emoji_events_rounded;
    case 'community':
      return Icons.groups_rounded;
    case 'venue':
      return Icons.stadium_rounded;
    case 'journalist':
      return Icons.newspaper_rounded;
    case 'creator':
      return Icons.videocam_rounded;
    case 'scout':
      return Icons.travel_explore_rounded;
    case 'agent':
      return Icons.handshake_rounded;
    default:
      return Icons.person_rounded;
  }
}

String _subtitle(String role, Map<String, dynamic>? entity) {
  if (role == 'coach' && entity?['role'] != null) {
    return (entity!['role'] as String).replaceAll('_', ' ');
  }
  if (role == 'league' && entity?['type'] != null) {
    return entity!['type'].toString();
  }
  if (role == 'community' && entity?['topic'] != null) {
    return entity!['topic'].toString();
  }
  return _prettyRole(role);
}

String _membersTitle(String role) {
  switch (role) {
    case 'league':
    case 'competition':
      return 'Clubs';
    case 'coach':
      return 'Squad';
    case 'community':
    case 'academy':
      return 'Members';
    default:
      return 'Members';
  }
}

String _title(String handle) {
  if (handle.isEmpty) return 'Profile';
  return handle
      .replaceAll('_', ' ')
      .replaceAll('-', ' ')
      .split(' ')
      .map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}')
      .join(' ');
}

String _age(String? iso) {
  if (iso == null || iso.isEmpty) return '';
  final dt = DateTime.tryParse(iso);
  if (dt == null) return '';
  final d = DateTime.now().difference(dt.toLocal());
  if (d.inMinutes < 60) return '${d.inMinutes}m';
  if (d.inHours < 24) return '${d.inHours}h';
  if (d.inDays < 7) return '${d.inDays}d';
  return '${dt.day}/${dt.month}/${dt.year}';
}
