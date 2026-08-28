import '../../../core/data/vps_supabase_compat.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shop/models/shop_models.dart';
import '../shared/profile_widgets.dart';
import '../templates/role_profile_model.dart';

/// Unified DB loader for all non-fan/team/player roles.
Future<RoleProfileModel> lookupRoleProfile(String role, String handle) async {
  final sb = VpsSupabaseCompat.client;
  final key = handle.replaceAll('@', '').trim().toLowerCase();
  final roleKey =
      role.toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');
  final slugDash = key.replaceAll('_', '-');

  Map<String, dynamic>? user;
  Map<String, dynamic>? entity;

  try {
    user = await sb.from('User').select().eq('handle', key).maybeSingle();
  } catch (e) {
    debugPrint('lookupRoleProfile: User select by handle failed: $e');
  }
  try {
    user ??= await sb.from('profiles').select().eq('handle', key).maybeSingle();
  } catch (e) {
    debugPrint('lookupRoleProfile: profiles select by handle failed: $e');
  }

  entity = await _fetchEntity(sb, roleKey, key, slugDash, user?['id']?.toString());

  // Also load the role-specific Profile row (e.g. AgentProfile, AnalystProfile…)
  // and merge its fields into the entity dict so they are available downstream.
  final profileRow = await _fetchRoleProfileRow(sb, roleKey, user?['id']?.toString());
  if (profileRow != null) {
    entity = <String, dynamic>{
      if (entity != null) ...entity,
      ...profileRow,
      // Preserve entity id/slug if the entity table provided them, since
      // role-specific profile rows use `userId` as the PK.
      if (entity != null && entity['id'] != null) 'id': entity['id'],
      if (entity != null && entity['slug'] != null) 'slug': entity['slug'],
      if (entity != null && entity['name'] != null) 'name': entity['name'],
      if (entity != null && entity['accountUserId'] != null)
        'accountUserId': entity['accountUserId'],
    };
  }

  if (user == null && entity?['accountUserId'] != null) {
    try {
      user = await sb
          .from('User')
          .select()
          .eq('id', entity!['accountUserId'])
          .maybeSingle();
    } catch (e) {
      debugPrint('lookupRoleProfile: User select by accountUserId failed: $e');
    }
  }

  final effectiveRole =
      ((user?['role'] as String?) ?? roleKey).toLowerCase().replaceAll('-', '_');
  final label = _prettyRole(effectiveRole.isNotEmpty ? effectiveRole : roleKey);
  final shape = _shapeFor(roleKey);
  final accent = _accentFor(roleKey);

  final name = (entity?['name'] as String?) ??
      (entity?['academyName'] as String?) ??
      (entity?['venueName'] as String?) ??
      (entity?['companyName'] as String?) ??
      (entity?['communityName'] as String?) ??
      (entity?['leagueName'] as String?) ??
      (entity?['competitionName'] as String?) ??
      (entity?['brand'] as String?) ??
      (user?['name'] as String?) ??
      '${user?['first_name'] ?? user?['firstName'] ?? ''} '
          '${user?['last_name'] ?? user?['lastName'] ?? ''}'.trim();
  final display = name.isNotEmpty ? name : _title(key);

  final uid =
      entity?['accountUserId']?.toString() ?? user?['id']?.toString();
  // #6.4 — entityId must be populated for all org roles that have entity
  // tables. Some role-specific Profile tables (OrganizationProfile,
  // BusinessProfile, VenueProfile, …) use `userId` as the primary key with
  // no separate `id` column; in that case the entity id IS the user id.
  final entityId = entity?['id']?.toString() ??
      entity?['userId']?.toString() ??
      user?['id']?.toString();

  // #6.13 — Read counts with both camelCase (User table) and snake_case
  // (profiles table) fallbacks.
  var postCount = _readInt(user, const ['postCount', 'post_count']);
  final followerCount =
      _readInt(user, const ['followerCount', 'follower_count']);
  final followingCount =
      _readInt(user, const ['followingCount', 'following_count']);
  final fanCount = _readInt(user, const ['fanCount', 'fan_count']) +
      _readInt(entity, const ['memberCount', 'member_count']);

  final avatarUrl = (user?['avatarUrl'] as String?) ??
      (user?['avatar_url'] as String?) ??
      (entity?['logoUrl'] as String?) ??
      (entity?['logo_url'] as String?) ??
      (entity?['photoUrl'] as String?) ??
      (entity?['photo_url'] as String?) ??
      (entity?['avatarUrl'] as String?);

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
  final statsRows = await _statsRows(
    sb,
    roleKey: roleKey,
    entity: entity,
    user: user,
  );

  final headerStats = <RoleStat>[
    RoleStat('$postCount', 'Posts'),
    if (shape != RoleShape.commerce)
      RoleStat('$fanCount', shape == RoleShape.org ? 'Members' : 'Fans'),
    RoleStat('$followerCount', 'Followers'),
    RoleStat('$followingCount', 'Following'),
  ];

  ShopCatalog? shop;
  if (shape == RoleShape.commerce) {
    shop = await _loadShopCatalog(
      sb,
      sellerName: display,
      sellerHandle: (user?['handle'] as String?) ?? key,
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
        (entity?['bio'] as String?) ??
        '',
    location: (user?['country'] as String?) ??
        (user?['currentCountry'] as String?) ??
        (entity?['country'] as String?) ??
        (entity?['location'] as String?) ??
        (entity?['headquarters'] as String?) ??
        '',
    sport: (entity?['sport_slug'] as String?) ??
        (entity?['sportId'] as String?)?.replaceFirst('sport-', '') ??
        (entity?['sportsCategory'] as String?) ??
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
    avatarUrl: avatarUrl,
    isClaimable: uid == null && entity != null,
    profileType: roleKey,
    isVerified: (entity?['verified'] as bool?) == true ||
        (entity?['isVerified'] as bool?) == true ||
        (entity?['is_verified'] as bool?) == true ||
        (user?['isVerified'] as bool?) == true ||
        (user?['is_verified'] as bool?) == true,
    isOwnProfile: uid != null && uid == sb.auth.currentUser?.id,
    coverIcon: _iconFor(roleKey),
    shop: shop,
  );
}

/// Reads an int from [row] by trying each candidate [keys] in order.
int _readInt(Map<String, dynamic>? row, List<String> keys) {
  if (row == null) return 0;
  for (final k in keys) {
    final v = row[k];
    if (v is int) return v;
    if (v is num) return v.toInt();
  }
  return 0;
}

/// Look up an org/commerce entity row by role + slug/handle/id.
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
    String slugColumn = 'slug',
    String nameColumn = 'name',
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
    } catch (e) {
      debugPrint('_fetchEntity($table).byAccountUserId: $e');
    }
    try {
      row ??= await sb
          .from(table)
          .select()
          .eq(slugColumn, slugDash)
          .maybeSingle();
    } catch (e) {
      debugPrint('_fetchEntity($table).bySlug($slugDash): $e');
    }
    try {
      row ??= await sb.from(table).select().eq(slugColumn, key).maybeSingle();
    } catch (e) {
      debugPrint('_fetchEntity($table).bySlug($key): $e');
    }
    for (final p in idPrefixes) {
      try {
        row ??= await sb.from(table).select().eq('id', '$p$key').maybeSingle();
      } catch (e) {
        debugPrint('_fetchEntity($table).byId($p$key): $e');
      }
      try {
        row ??=
            await sb.from(table).select().eq('id', '$p$slugDash').maybeSingle();
      } catch (e) {
        debugPrint('_fetchEntity($table).byId($p$slugDash): $e');
      }
    }
    try {
      if (row == null) {
        final guess = key.replaceAll('_', ' ').replaceAll('-', ' ');
        final rows =
            await sb.from(table).select().ilike(nameColumn, '%$guess%').limit(1);
        if ((rows as List).isNotEmpty) {
          row = Map<String, dynamic>.from(rows.first as Map);
        }
      }
    } catch (e) {
      debugPrint('_fetchEntity($table).byNameLike: $e');
    }
    return row;
  }

  switch (roleKey) {
    case 'coach':
      return tryTable('Coach', idPrefixes: ['ch-']);
    case 'league':
      return tryTable('League', idPrefixes: ['lg-']);
    case 'competition':
      // Competition entity table uses snake_case columns.
      return await tryTable('Competition', idPrefixes: ['comp-']) ??
          await tryTable('League', idPrefixes: ['lg-']);
    case 'community':
      return tryTable('Community');
    case 'academy':
      // Academy may live as a Team with taxonomy or Community.
      return await tryTable('Team', idPrefixes: ['tm-']) ??
          await tryTable('Community');
    case 'media_broadcast':
    case 'media':
      // Media/broadcast accounts are users — their entity IS the User row.
      return tryTable('User');
    case 'venue':
      // No Venue entity table — fall back to VenueProfile then Team
      // (stadiums are stored on Team.venue).
      return await tryTable('VenueProfile') ??
          await tryTable('Team', idPrefixes: ['tm-']);
    case 'business':
      return tryTable('BusinessProfile');
    case 'sponsor':
      return tryTable('SponsorProfile');
    case 'commercial_partner':
      return await tryTable('CommercialPartner') ??
          await tryTable('CommercialPartnerProfile');
    case 'organization':
      return tryTable('OrganizationProfile');
    // Person commerce/individual roles: entity is the user row itself, but
    // role-specific profile rows are loaded by _fetchRoleProfileRow.
    case 'agent':
    case 'analyst':
    case 'commentator':
    case 'creator':
    case 'journalist':
    case 'moderator':
    case 'official':
    case 'support_staff':
    case 'scout':
    case 'player':
    case 'team':
    case 'fan':
    default:
      return null;
  }
}

/// Load the role-specific Profile row (e.g. AgentProfile, AnalystProfile…).
/// Returns null if the table doesn't exist or no row matches.
Future<Map<String, dynamic>?> _fetchRoleProfileRow(
  SupabaseClient sb,
  String roleKey,
  String? userId,
) async {
  if (userId == null || userId.isEmpty) return null;
  final table = _profileTableFor(roleKey);
  if (table == null) return null;
  try {
    return await sb
        .from(table)
        .select()
        .eq('userId', userId)
        .maybeSingle();
  } catch (e) {
    debugPrint('_fetchRoleProfileRow($table): $e');
    return null;
  }
}

String? _profileTableFor(String roleKey) {
  switch (roleKey) {
    case 'player':
      return 'PlayerProfile';
    case 'coach':
      return 'CoachProfile';
    case 'team':
      return 'TeamProfile';
    case 'scout':
      return 'ScoutProfile';
    case 'journalist':
      return 'JournalistProfile';
    case 'creator':
      return 'CreatorProfile';
    case 'analyst':
      return 'AnalystProfile';
    case 'agent':
      return 'AgentProfile';
    case 'organization':
      return 'OrganizationProfile';
    case 'competition':
      return 'CompetitionProfile';
    case 'league':
      return 'LeagueProfile';
    case 'academy':
      return 'AcademyProfile';
    case 'venue':
      return 'VenueProfile';
    case 'business':
      return 'BusinessProfile';
    case 'commercial_partner':
      return 'CommercialPartnerProfile';
    case 'community':
      return 'CommunityProfile';
    case 'commentator':
      return 'CommentatorProfile';
    case 'official':
      return 'OfficialProfile';
    case 'support_staff':
      return 'SupportStaffProfile';
    case 'moderator':
      return 'ModeratorProfile';
    case 'sponsor':
      return 'SponsorProfile';
    case 'media_broadcast':
    case 'media':
      return 'MediaBroadcastProfile';
    default:
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
  } catch (e) {
    debugPrint('_loadPosts: $e');
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
  add('Nationality', (entity?['nationality'] as String?) ??
      (user?['nationality'] as String?));
  add('City', entity?['city'] as String?);
  add('Location', (entity?['location'] as String?) ??
      (entity?['headquarters'] as String?) ??
      (user?['location'] as String?));
  add('Website', (entity?['website'] as String?) ?? (user?['website'] as String?));

  switch (roleKey) {
    case 'coach':
      add('Title', (entity?['coachingRole'] as String?)?.replaceAll('_', ' ') ??
          (entity?['role'] as String?)?.replaceAll('_', ' '));
      add('License', entity?['license'] as String?);
      add('Preferred formation', entity?['preferredFormation'] as String?);
      final teamId = entity?['teamId']?.toString() ??
          entity?['currentTeam']?.toString();
      if (teamId != null) {
        try {
          final team =
              await sb.from('Team').select('name').eq('id', teamId).maybeSingle();
          add('Club', team?['name'] as String?);
        } catch (e) {
          debugPrint('_aboutFields.coach.team lookup: $e');
        }
      }
      break;
    case 'league':
      add('Type', (entity?['type'] as String?) ?? (entity?['competitionType'] as String?));
      add('Season', (entity?['season'] as String?) ??
          (entity?['currentSeason'] as String?));
      add('Division', (entity?['division'] as String?) ??
          (entity?['competitionLevel'] as String?));
      add('Country', entity?['country'] as String?);
      break;
    case 'competition':
      add('Type', (entity?['competition_type'] as String?) ??
          (entity?['competitionType'] as String?));
      add('Format', (entity?['competition_format'] as String?) ??
          (entity?['competitionFormat'] as String?));
      add('Level', (entity?['competition_level'] as String?) ??
          (entity?['competitionLevel'] as String?));
      add('Season', (entity?['season'] as String?) ??
          (entity?['currentSeason'] as String?));
      add('Gender', (entity?['gender'] as String?) ??
          (entity?['competitionGender'] as String?));
      add('Organizer', entity?['organizer'] as String?);
      break;
    case 'community':
      add('Topic', (entity?['topic'] as String?) ??
          (entity?['communityType'] as String?));
      if (entity?['memberCount'] != null) {
        add('Members', '${entity!['memberCount']}');
      } else if (entity?['member_count'] != null) {
        add('Members', '${entity!['member_count']}');
      }
      add('Supported team', entity?['supportedTeam'] as String?);
      break;
    case 'venue':
      add('Capacity', entity?['capacity']?.toString());
      add('Venue type', entity?['venueType'] as String?);
      add('Stadium', (entity?['stadium'] as String?) ??
          (entity?['venueName'] as String?) ??
          (entity?['name'] as String?));
      break;
    case 'business':
      add('Company', (entity?['companyName'] as String?) ??
          (entity?['name'] as String?));
      add('Industry', entity?['industry'] as String?);
      add('Headquarters', entity?['headquarters'] as String?);
      break;
    case 'sponsor':
      add('Brand', (entity?['brand'] as String?) ?? (entity?['name'] as String?));
      add('Industry', entity?['industry'] as String?);
      break;
    case 'commercial_partner':
      add('Partner type', (entity?['partnerType'] as String?) ??
          (entity?['partner_type'] as String?));
      add('Brand', entity?['brand'] as String?);
      add('Sports category', entity?['sportsCategory'] as String?);
      add('Tier', entity?['tier'] as String?);
      break;
    case 'organization':
      add('Org type', (entity?['orgType'] as String?) ?? (entity?['organizationType'] as String?));
      add('Headquarters', (entity?['headquarters'] as String?) ??
          (entity?['location'] as String?));
      add('Founded', (entity?['foundedYear'] as String?) ??
          (entity?['founded_year']?.toString()));
      break;
    case 'agent':
      add('Agency', (entity?['agency'] as String?) ?? (entity?['organization'] as String?));
      add('License', entity?['license'] as String?);
      add('Federation', entity?['federation'] as String?);
      add('Type', entity?['agentType'] as String?);
      break;
    case 'analyst':
      add('Type', entity?['analystType'] as String?);
      add('Organization', entity?['organization'] as String?);
      add('Expertise', _joinListOrString(entity?['expertise']));
      break;
    case 'commentator':
      add('Type', entity?['commentatorType'] as String?);
      add('Broadcaster', entity?['broadcaster'] as String?);
      add('Languages', _joinListOrString(entity?['languages']));
      add('Sports', _joinListOrString(entity?['sports']));
      break;
    case 'creator':
      add('Type', entity?['creatorType'] as String?);
      add('Niche', entity?['niche'] as String?);
      add('Platforms', _joinListOrString(entity?['platforms']));
      add('Followers', entity?['followers'] as String?);
      break;
    case 'journalist':
      add('Publication', entity?['publication'] as String?);
      add('Beat', entity?['beat'] as String?);
      add('Years active', entity?['yearsActive']?.toString());
      break;
    case 'moderator':
      add('Scope', entity?['scope'] as String?);
      add('Communities', entity?['communities'] as String?);
      break;
    case 'official':
      add('Official type', entity?['officialType'] as String?);
      add('Federation', entity?['federation'] as String?);
      add('License', entity?['license'] as String?);
      add('Years active', entity?['yearsActive']?.toString());
      break;
    case 'support_staff':
      add('Staff role', entity?['staffRole'] as String?);
      add('Organization', entity?['organization'] as String?);
      add('Specialty', entity?['specialty'] as String?);
      break;
    case 'scout':
      add('Scout type', entity?['scoutType'] as String?);
      add('Organization', entity?['organization'] as String?);
      add('Coverage', entity?['geographicCoverage'] as String?);
      add('Sports', _joinListOrString(entity?['sportsCovered']));
      add('Years experience', entity?['yearsExperience']?.toString());
      break;
    case 'academy':
      add('Academy', (entity?['academyName'] as String?) ??
          (entity?['name'] as String?));
      add('Parent org', entity?['parentOrg'] as String?);
      add('Location', entity?['location'] as String?);
      add('Founded', (entity?['foundedYear'] as String?) ??
          (entity?['foundedYear']?.toString()));
      break;
    case 'media_broadcast':
    case 'media':
      add('Outlet', (entity?['outlet'] as String?) ??
          (user?['name'] as String?));
      add('Platform', entity?['platform'] as String?);
      add('Coverage', entity?['coverage'] as String?);
      break;
    default:
      break;
  }

  add('Email', user?['email'] as String?);
  return fields;
}

String _joinListOrString(dynamic v) {
  if (v == null) return '';
  if (v is List) return v.map((e) => e.toString()).join(', ');
  return v.toString();
}

Future<List<RoleMember>> _members(
  SupabaseClient sb, {
  required String roleKey,
  required Map<String, dynamic>? entity,
}) async {
  final id = entity?['id']?.toString();
  // For person roles the entity is the user — members doesn't apply.
  if (id == null) return [];

  try {
    switch (roleKey) {
      case 'league':
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
              route:
                  '/team/${(r['slug'] as String?)?.replaceAll('-', '_') ?? r['id']}',
            ),
        ];
      case 'competition':
        // Competition → Teams in same country (no join table exists).
        final country = entity?['country'] as String?;
        final List<dynamic> teams;
        if (country != null && country.isNotEmpty) {
          teams = await sb
              .from('Team')
              .select('id,name,slug,accountUserId')
              .eq('country', country)
              .eq('isActive', true)
              .limit(24);
        } else {
          teams = await sb
              .from('Team')
              .select('id,name,slug,accountUserId')
              .eq('isActive', true)
              .limit(24);
        }
        return [
          for (final r in teams)
            RoleMember(
              name: (r as Map)['name']?.toString() ?? 'Team',
              handle: (r['slug'] as String?)?.replaceAll('-', '_') ??
                  r['id'].toString(),
              subtitle: 'Club',
              route:
                  '/team/${(r['slug'] as String?)?.replaceAll('-', '_') ?? r['id']}',
            ),
        ];
      case 'coach':
        final teamId = entity?['teamId']?.toString();
        if (teamId == null) return [];
        final players = await sb
            .from('Player')
            .select('name,slug,position')
            .eq('teamId', teamId)
            .limit(20);
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
      case 'academy':
        // No academyId column on Player today — gracefully degrade to
        // listing players on the academy's Team row if it lives as a Team.
        final teamId = entity?['id']?.toString();
        if (teamId == null) return [];
        try {
          final players = await sb
              .from('Player')
              .select('name,slug,position')
              .eq('teamId', teamId)
              .limit(20);
          return [
            for (final r in players as List)
              RoleMember(
                name: (r as Map)['name']?.toString() ?? 'Player',
                handle:
                    (r['slug'] as String?)?.replaceAll('-', '_') ?? 'player',
                subtitle: (r['position'] as String?) ?? 'Player',
                route:
                    '/player/${(r['slug'] as String?)?.replaceAll('-', '_') ?? 'player'}',
              ),
          ];
        } catch (e) {
          debugPrint('_members.academy: $e');
          return [];
        }
      case 'community':
        // CommunityMember join exists.
        try {
          final rows = await sb
              .from('CommunityMember')
              .select('userId,User(handle,name)')
              .eq('communityId', id)
              .limit(40);
          final out = <RoleMember>[];
          for (final raw in rows as List) {
            final m = raw as Map;
            final u = m['User'] as Map?;
            final h = (u?['handle'] as String?)?.replaceAll('-', '_') ??
                m['userId'].toString();
            out.add(RoleMember(
              name: (u?['name'] as String?) ?? 'Member',
              handle: h,
              subtitle: 'Member',
              route: u?['handle'] != null ? '/profile/${u!['handle']}' : null,
            ));
          }
          return out;
        } catch (e) {
          debugPrint('_members.community: $e');
          return [];
        }
      case 'organization':
        // No organizationId column on User today — gracefully degrade.
        try {
          final rows = await sb
              .from('User')
              .select('id,handle,name,role')
              .eq('role', 'organization')
              .limit(40);
          return [
            for (final r in rows as List)
              RoleMember(
                name: (r as Map)['name']?.toString() ?? 'User',
                handle: (r['handle'] as String?) ?? r['id'].toString(),
                subtitle: 'Staff',
                route: r['handle'] != null
                    ? '/profile/${r['handle']}'
                    : null,
              ),
          ];
        } catch (e) {
          debugPrint('_members.organization: $e');
          return [];
        }
      case 'media_broadcast':
      case 'media':
        // No outletId column today — gracefully degrade.
        try {
          final rows = await sb
              .from('User')
              .select('id,handle,name')
              .eq('role', 'media_broadcast')
              .limit(40);
          return [
            for (final r in rows as List)
              RoleMember(
                name: (r as Map)['name']?.toString() ?? 'User',
                handle: (r['handle'] as String?) ?? r['id'].toString(),
                subtitle: 'Broadcaster',
                route: r['handle'] != null
                    ? '/profile/${r['handle']}'
                    : null,
              ),
          ];
        } catch (e) {
          debugPrint('_members.media_broadcast: $e');
          return [];
        }
    }
  } catch (e) {
    debugPrint('_members($roleKey): $e');
  }
  return [];
}

Future<List<AboutField>> _statsRows(
  SupabaseClient sb, {
  required String roleKey,
  required Map<String, dynamic>? entity,
  required Map<String, dynamic>? user,
}) async {
  try {
    switch (roleKey) {
      case 'league':
      case 'competition':
        final name = (entity?['name'] as String?) ?? '';
        final rows = await sb.from('Match').select('id,status').limit(500);
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
      case 'team':
        // Compute season record by scanning Match rows that mention the team.
        final teamName = (entity?['name'] as String?) ??
            (user?['name'] as String?) ??
            '';
        if (teamName.isEmpty) return [];
        final rows = await sb.from('Match').select(
            'homeTeam,awayTeam,homeScore,awayScore,status');
        var played = 0, w = 0, d = 0, l = 0, gf = 0, ga = 0;
        for (final raw in rows as List) {
          final r = Map<String, dynamic>.from(raw as Map);
          final status = ((r['status'] as String?) ?? '').toLowerCase();
          if (!(status == 'finished' ||
              status == 'ft' ||
              status == 'completed' ||
              status == 'full_time')) {
            continue;
          }
          final hs = r['homeScore'];
          final as_ = r['awayScore'];
          if (hs == null || as_ == null) continue;
          final home = (r['homeTeam'] as String?) ?? '';
          final away = (r['awayTeam'] as String?) ?? '';
          final isHome = _sameName(home, teamName);
          final isAway = _sameName(away, teamName);
          if (!isHome && !isAway) continue;
          final h = (hs as num).toInt();
          final a = (as_ as num).toInt();
          played++;
          if (isHome) {
            gf += h;
            ga += a;
            if (h > a) {
              w++;
            } else if (h < a) {
              l++;
            } else {
              d++;
            }
          } else {
            gf += a;
            ga += h;
            if (a > h) {
              w++;
            } else if (a < h) {
              l++;
            } else {
              d++;
            }
          }
        }
        return [
          AboutField('Matches played', '$played'),
          AboutField('Wins', '$w'),
          AboutField('Draws', '$d'),
          AboutField('Losses', '$l'),
          AboutField('Goals for', '$gf'),
          AboutField('Goals against', '$ga'),
        ];
      case 'player':
        // Pull aggregated stats from PlayerMatchStat if present.
        final pid = entity?['id']?.toString();
        var apps = _readInt(entity, const ['appearances']);
        var goals = _readInt(entity, const ['goals']);
        var assists = _readInt(entity, const ['assists']);
        if (pid != null) {
          try {
            final rows = await sb
                .from('PlayerMatchStat')
                .select('played,goals,assists')
                .eq('playerId', pid);
            var played = 0, g = 0, ast = 0;
            for (final raw in rows as List) {
              final m = Map<String, dynamic>.from(raw as Map);
              if (m['played'] == true) played++;
              g += (m['goals'] as int?) ?? 0;
              ast += (m['assists'] as int?) ?? 0;
            }
            if (played > 0) apps = played;
            if (g > 0) goals = g;
            if (ast > 0) assists = ast;
          } catch (e) {
            debugPrint('_statsRows.player.PlayerMatchStat: $e');
          }
        }
        return [
          AboutField('Appearances', '$apps'),
          AboutField('Goals', '$goals'),
          AboutField('Assists', '$assists'),
        ];
      case 'coach':
        final managed = _readInt(entity, const ['matchesManaged', 'matches_managed']);
        final wins = _readInt(entity, const ['wins']);
        final yr = _readInt(entity, const ['yearsCoaching', 'years_coaching']);
        final winRate = managed > 0 ? ((wins / managed) * 100).round() : 0;
        return [
          AboutField('Matches managed', '$managed'),
          AboutField('Wins', '$wins'),
          AboutField('Win rate', '$winRate%'),
          if (yr > 0) AboutField('Years coaching', '$yr'),
        ];
    }
  } catch (e) {
    debugPrint('_statsRows($roleKey): $e');
  }
  return [];
}

bool _sameName(String a, String b) {
  final x = a.trim().toLowerCase();
  final y = b.trim().toLowerCase();
  if (x.isEmpty || y.isEmpty) return false;
  if (x == y) return true;
  if (x.contains(y) || y.contains(x)) return true;
  final xs = x.replaceAll(RegExp(r'\s+(sc|fc)$'), '');
  final ys = y.replaceAll(RegExp(r'\s+(sc|fc)$'), '');
  return xs == ys;
}

/// Loads shop catalog from a ShopItem table if it exists; gracefully
/// degrades to an empty catalog (which renders a friendly empty state).
Future<ShopCatalog> _loadShopCatalog(
  SupabaseClient sb, {
  required String sellerName,
  required String sellerHandle,
  required Color accent,
}) async {
  final merch = <ShopItem>[];
  try {
    // Select * so the query is resilient if the ShopItem schema adds columns
    // later. The table may not exist yet — failures are caught below.
    final rows = await sb
        .from('ShopItem')
        .select()
        .eq('sellerHandle', sellerHandle)
        .eq('isActive', true)
        .order('createdAt', ascending: false)
        .limit(40);
    for (final r in rows as List) {
      final m = Map<String, dynamic>.from(r as Map);
      final kindStr = (m['kind'] as String?) ?? 'merch';
      final kind = switch (kindStr) {
        'ticket' => ShopItemKind.ticket,
        'membership' => ShopItemKind.membership,
        'donation' => ShopItemKind.donation,
        _ => ShopItemKind.merch,
      };
      merch.add(ShopItem(
        id: m['id']?.toString() ?? '',
        name: (m['name'] as String?) ?? 'Item',
        subtitle: (m['subtitle'] as String?) ?? '',
        priceTzs: (m['priceTzs'] as int?) ?? 0,
        kind: kind,
        badge: m['badge'] as String?,
      ));
    }
  } catch (e) {
    // ShopItem table may not exist yet — gracefully degrade.
    debugPrint('_loadShopCatalog: ShopItem query failed (expected if table '
        'does not exist): $e');
  }
  return ShopCatalog(
    sellerName: sellerName,
    sellerHandle: sellerHandle,
    accent: accent,
    merch: merch,
  );
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
    case 'academy':
      return Colors.green.shade700;
    case 'agent':
      return Colors.indigo;
    case 'analyst':
      return Colors.teal;
    case 'business':
      return Colors.orange;
    case 'coach':
      return const Color(0xFF00C853);
    case 'commercial_partner':
      return Colors.purple;
    case 'commentator':
      return Colors.red.shade700;
    case 'community':
      return const Color(0xFF00BCD4);
    case 'competition':
    case 'league':
      return const Color(0xFFFFD600);
    case 'creator':
      return Colors.pink;
    case 'journalist':
      return Colors.blue.shade800;
    case 'moderator':
      return Colors.amber.shade800;
    case 'official':
      return Colors.yellow.shade800;
    case 'organization':
      return Colors.blueGrey;
    case 'scout':
      return const Color(0xFFFF6D00);
    case 'sponsor':
      return Colors.deepPurple;
    case 'support_staff':
      return Colors.lightBlue;
    case 'venue':
      return Colors.brown;
    case 'media_broadcast':
    case 'media':
      return const Color(0xFF7C4DFF);
    default:
      return const Color(0xFF009DFF);
  }
}

IconData _iconFor(String role) {
  switch (role) {
    case 'academy':
      return Icons.school_rounded;
    case 'agent':
      return Icons.business_center_rounded;
    case 'analyst':
      return Icons.analytics_rounded;
    case 'business':
      return Icons.store_rounded;
    case 'coach':
      return Icons.sports_rounded;
    case 'commercial_partner':
      return Icons.handshake_rounded;
    case 'commentator':
      return Icons.mic_rounded;
    case 'community':
      return Icons.groups_rounded;
    case 'competition':
    case 'league':
      return Icons.emoji_events_rounded;
    case 'creator':
      return Icons.movie_rounded;
    case 'journalist':
      return Icons.article_rounded;
    case 'moderator':
      return Icons.shield_rounded;
    case 'official':
      return Icons.sports_rounded;
    case 'organization':
      return Icons.account_balance_rounded;
    case 'scout':
      return Icons.travel_explore_rounded;
    case 'sponsor':
      return Icons.diamond_rounded;
    case 'support_staff':
      return Icons.medical_services_rounded;
    case 'venue':
      return Icons.stadium_rounded;
    case 'media_broadcast':
    case 'media':
      return Icons.live_tv_rounded;
    default:
      return Icons.person_rounded;
  }
}

String _subtitle(String role, Map<String, dynamic>? entity) {
  if (role == 'coach' &&
      (entity?['role'] != null || entity?['coachingRole'] != null)) {
    return ((entity!['coachingRole'] as String?) ?? entity['role'] as String)
        .replaceAll('_', ' ');
  }
  if (role == 'league' && entity?['type'] != null) {
    return entity!['type'].toString();
  }
  if (role == 'community' && entity?['topic'] != null) {
    return entity!['topic'].toString();
  }
  if (role == 'venue' && entity?['venueType'] != null) {
    return entity!['venueType'].toString();
  }
  if (role == 'business' && entity?['industry'] != null) {
    return entity!['industry'].toString();
  }
  if (role == 'sponsor' && entity?['industry'] != null) {
    return entity!['industry'].toString();
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
    case 'organization':
      return 'Staff';
    case 'media_broadcast':
    case 'media':
      return 'Team';
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
